import Combine
import Foundation

public enum OperationState: Equatable, Sendable {
    case idle
    case inProgress
    case success
    case failed(OperationError)

    public static func == (lhs: OperationState, rhs: OperationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.inProgress, .inProgress): return true
        case (.success, .success): return true
        case (.failed, .failed): return true
        default: return false
        }
    }

    public var isFinished: Bool {
        switch self {
        case .idle, .inProgress: return false
        case .success, .failed: return true
        }
    }
}

/// Sendable wrapper around any error captured by `OperationExecutor`.
///
/// Stores a `String` description of the original error so the failure
/// can be propagated through `Sendable` boundaries (e.g. via
/// `OperationState.failed` and `AsyncStream`) without requiring the
/// underlying error type to be `Sendable`. The underlying type name is
/// preserved as metadata for diagnostics.
public struct OperationError: Error, Sendable, CustomStringConvertible, Equatable {
    public let description: String
    public let underlyingTypeName: String

    public init(_ error: any Error) {
        self.description = String(describing: error)
        self.underlyingTypeName = String(reflecting: type(of: error))
    }

    public init(_ description: String) {
        self.description = description
        self.underlyingTypeName = "String"
    }
}

public struct OperationID: Hashable, Equatable, Sendable, ExpressibleByStringLiteral {
    fileprivate let value: String
    public init(value: String = UUID().uuidString) {
        self.value = value
    }

    public init(value: UUID) {
        self.value = value.uuidString
    }

    public init(stringLiteral: StringLiteralType) {
        self.value = stringLiteral
    }
}

@Observable
@MainActor
public final class OperationWatcher {
    public let id: OperationID
    public fileprivate(set) var state: OperationState

    init(id: OperationID, state: OperationState) {
        self.id = id
        self.state = state
    }
}

public actor OperationExecutor {
    public static let shared = OperationExecutor()

    @MainActor private var activeOperations: [OperationID: OperationState] = [:]
    @MainActor private var watchers = NSMapTable<NSString, OperationWatcher>(keyOptions: .strongMemory, valueOptions: .weakMemory)

    private nonisolated(unsafe) let eventsSubject = PassthroughSubject<(OperationID, OperationState), Never>()
    private let taskQueue = TaskQueue()

    public init() {}

    @MainActor
    public func watcher(id: OperationID) -> OperationWatcher {
        if let watcher = watchers.object(forKey: id.value as NSString) {
            return watcher
        } else {
            let state = activeOperations[id]
            let watcher = OperationWatcher(id: id, state: state ?? .idle)
            watchers.setObject(watcher, forKey: id.value as NSString)
            return watcher
        }
    }

    @available(macOS 15.0, *)
    @available(iOS 18.0, *)
    public func stream(id: OperationID) -> sending any AsyncSequence<OperationState, Never> {
        makeStream(id: id)
    }

    @available(iOS 18.0, *)
    public func wait(id: OperationID) async throws {
        // Subscribe before snapshotting state so a completion event between
        // the snapshot and iteration cannot be missed.
        let stream = makeStream(id: id)

        if let current = await currentState(id: id) {
            switch current {
            case .success: return
            case .failed(let error): throw error
            case .idle, .inProgress: break
            }
        }

        for await state in stream {
            switch state {
            case .success: return
            case .failed(let error): throw error
            case .idle, .inProgress: continue
            }
        }
    }

    private nonisolated func makeStream(id: OperationID) -> AsyncStream<OperationState> {
        AsyncStream<OperationState> { continuation in
            nonisolated(unsafe) let cancellable = eventsSubject
                .filter { $0.0 == id }
                .map { $0.1 }
                .sink { state in
                    continuation.yield(state)
                }
            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }

    @MainActor
    private func currentState(id: OperationID) -> OperationState? {
        activeOperations[id]
    }

    public nonisolated func perform(id: OperationID, ignoreActive: Bool = false, operation: @escaping @Sendable () async throws -> Void) {
        Task.detached { [self] in
            await taskQueue.enqueue {
                if !ignoreActive, await activeOperations[id] == .inProgress {
                    CamperLogger.operationExecutor.debug("Operation \(id) is already in progress.")
                    return
                }

                CamperLogger.operationExecutor.debug("Starting operation \(id).")
                do {
                    await setOperationState(id: id, state: .inProgress)
                    try await operation()
                    await setOperationState(id: id, state: .success)
                } catch {
                    CamperLogger.operationExecutor.error("Operation \(id) failed with error \(error)")
                    await setOperationState(id: id, state: .failed(OperationError(error)))
                }

                CamperLogger.operationExecutor.debug("Finished operation \(id).")
            }
        }
    }

    @MainActor
    private func setOperationState(id: OperationID, state: OperationState) async {
        activeOperations[id] = state
        eventsSubject.send((id, state))
        if let watcher = watchers.object(forKey: id.value as NSString) {
            watcher.state = state
        }
    }
}
