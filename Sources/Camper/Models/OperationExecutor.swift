import Combine
import Foundation

public enum OperationState: Equatable, Sendable {
    case idle
    case inProgress
    case success
    case failed(Error)

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

    private nonisolated(unsafe) let eventsSubject: PassthroughSubject<(OperationID, OperationState), Never>
    private let stream: AsyncStream<(OperationID, OperationState)>
    private let taskQueue = TaskQueue()

    public init() {
        let passthroughSubject = PassthroughSubject<(OperationID, OperationState), Never>()

        self.eventsSubject = passthroughSubject
        self.stream = AsyncStream<(OperationID, OperationState)> { continuation in
            nonisolated(unsafe) let cancellable = passthroughSubject.sink { value in
                continuation.yield(value)
            }
            continuation.onTermination = { _ in
                cancellable.cancel()
            }
        }
    }

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
        stream.filter { $0.0 == id }.map { $0.1 }
    }

    @available(iOS 18.0, *)
    public func wait(id: OperationID) async throws {
        for await state in stream.filter({ $0.0 == id }).map({ $0.1 }) {
            switch state {
            case .success: return
            case .failed(let error): throw error
            default: break
            }
        }
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
                    await setOperationState(id: id, state: .failed(error))
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
