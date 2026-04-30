import Foundation
import XCTest

@testable import Camper

// MARK: - OperationID

final class OperationIDTests: XCTestCase {
    func testEqualityByValue() {
        let a = OperationID(value: "x")
        let b = OperationID(value: "x")
        XCTAssertEqual(a, b)
    }

    func testInequalityByValue() {
        XCTAssertNotEqual(OperationID(value: "x"), OperationID(value: "y"))
    }

    func testStringLiteralExpressible() {
        let id: OperationID = "literal"
        XCTAssertEqual(id, OperationID(value: "literal"))
    }

    func testInitFromUUID() {
        let uuid = UUID()
        let a = OperationID(value: uuid)
        let b = OperationID(value: uuid.uuidString)
        XCTAssertEqual(a, b)
    }

    func testHashableUseInSet() {
        var set: Set<OperationID> = []
        set.insert("one")
        set.insert("one")
        set.insert("two")
        XCTAssertEqual(set.count, 2)
    }
}

// MARK: - OperationState

final class OperationStateTests: XCTestCase {
    func testEqualityIgnoresFailedPayload() {
        struct A: Error {}
        struct B: Error {}
        XCTAssertEqual(OperationState.failed(OperationError(A())), OperationState.failed(OperationError(B())))
    }

    func testCaseDistinctness() {
        XCTAssertNotEqual(OperationState.idle, .inProgress)
        XCTAssertNotEqual(OperationState.inProgress, .success)
        XCTAssertNotEqual(OperationState.success, .failed(OperationError(NSError(domain: "x", code: 0))))
    }

    func testIsFinished() {
        XCTAssertFalse(OperationState.idle.isFinished)
        XCTAssertFalse(OperationState.inProgress.isFinished)
        XCTAssertTrue(OperationState.success.isFinished)
        XCTAssertTrue(OperationState.failed(OperationError(NSError(domain: "x", code: 0))).isFinished)
    }

    func testOperationErrorPreservesDescription() {
        struct MyError: Error, CustomStringConvertible {
            var description: String { "my-detail" }
        }
        let wrapped = OperationError(MyError())
        XCTAssertEqual(wrapped.description, "my-detail")
        XCTAssertTrue(wrapped.underlyingTypeName.contains("MyError"))
    }
}

// MARK: - OperationExecutor

@MainActor
final class OperationExecutorTests: XCTestCase {
    func testInitialWatcherStateIsIdle() {
        let executor = OperationExecutor()
        let watcher = executor.watcher(id: "fresh")
        XCTAssertEqual(watcher.state, .idle)
    }

    func testWatcherIsCachedPerID() {
        let executor = OperationExecutor()
        let a = executor.watcher(id: "cached")
        let b = executor.watcher(id: "cached")
        XCTAssertTrue(a === b, "watcher(id:) must return the same instance for the same id")

        let c = executor.watcher(id: "different")
        XCTAssertFalse(a === c)
    }

    func testPerformSuccessTransitionsToSuccess() async {
        let executor = OperationExecutor()
        let id: OperationID = "ok"
        let watcher = executor.watcher(id: id)

        executor.perform(id: id) {
            try? await Task.sleep(nanoseconds: 5_000_000)
        }

        await waitForState(watcher) { $0 == .success }
    }

    func testPerformThrowingTransitionsToFailed() async {
        struct Boom: Error {}
        let executor = OperationExecutor()
        let id: OperationID = "boom"
        let watcher = executor.watcher(id: id)

        executor.perform(id: id) {
            throw Boom()
        }

        await waitForState(watcher) {
            if case .failed = $0 { return true } else { return false }
        }
    }

    func testPerformVisitsInProgressBeforeFinishing() async {
        let executor = OperationExecutor()
        let id: OperationID = "transitions"
        let watcher = executor.watcher(id: id)

        let observer = StateObserver(watcher: watcher)

        executor.perform(id: id) {
            try? await Task.sleep(nanoseconds: 30_000_000)
        }

        await waitForState(watcher) { $0 == .success }
        observer.stop()

        let log = observer.log
        XCTAssertTrue(log.contains(.idle), "log must include initial idle state, got \(log)")
        XCTAssertTrue(log.contains(.inProgress), "log must include inProgress state, got \(log)")
        XCTAssertEqual(log.last, .success)
    }

    func testWatcherCreatedAfterCompletionReflectsCurrentState() async {
        let executor = OperationExecutor()
        let id: OperationID = "post.hoc"

        executor.perform(id: id) {}

        // Wait briefly for the op to complete.
        try? await Task.sleep(nanoseconds: 50_000_000)

        let watcher = executor.watcher(id: id)
        XCTAssertEqual(watcher.state, .success, "new watcher for already-finished id must reflect the latest state")
    }

    func testTwoIndependentOperationsBothComplete() async {
        let executor = OperationExecutor()
        let watcherA = executor.watcher(id: "a")
        let watcherB = executor.watcher(id: "b")

        executor.perform(id: "a") {}
        executor.perform(id: "b") {}

        await waitForState(watcherA) { $0 == .success }
        await waitForState(watcherB) { $0 == .success }
    }

    // MARK: - Bug fixes

    @available(macOS 15.0, *)
    func testStreamMulticastAllSubscribersReceiveAllEvents() async throws {
        let executor = OperationExecutor()
        let id: OperationID = "multicast"

        // Subscribe two independent consumers BEFORE the op runs.
        let stream1 = await executor.stream(id: id)
        let stream2 = await executor.stream(id: id)

        let task1 = Task<[OperationState], Never> {
            var states: [OperationState] = []
            for await state in stream1 {
                states.append(state)
                if state.isFinished { break }
            }
            return states
        }
        let task2 = Task<[OperationState], Never> {
            var states: [OperationState] = []
            for await state in stream2 {
                states.append(state)
                if state.isFinished { break }
            }
            return states
        }

        // Give the AsyncStream sinks a moment to subscribe.
        try await Task.sleep(nanoseconds: 50_000_000)

        executor.perform(id: id) {
            try? await Task.sleep(nanoseconds: 20_000_000)
        }

        let s1 = await task1.value
        let s2 = await task2.value

        // Both subscribers must observe the full transition (.inProgress, .success).
        XCTAssertEqual(s1, [.inProgress, .success], "subscriber 1 missed events: \(s1)")
        XCTAssertEqual(s2, [.inProgress, .success], "subscriber 2 missed events: \(s2)")
    }

    @available(iOS 18.0, *)
    func testWaitReturnsImmediatelyForAlreadyFinishedOperation() async throws {
        let executor = OperationExecutor()
        let id: OperationID = "wait.finished"

        executor.perform(id: id) {}
        // Let the op complete BEFORE we call wait, so wait must rely on the
        // current-state snapshot rather than on receiving a stream event.
        try await Task.sleep(nanoseconds: 200_000_000)

        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await executor.wait(id: id)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 1_000_000_000)
                throw NSError(domain: "TestTimeout", code: 0, userInfo: [NSLocalizedDescriptionKey: "wait hung — race-condition regression"])
            }
            try await group.next()
            group.cancelAll()
        }
    }

    @available(iOS 18.0, *)
    func testWaitThrowsWhenOperationFails() async {
        struct Boom: Error, CustomStringConvertible {
            var description: String { "boom-detail" }
        }
        let executor = OperationExecutor()
        let id: OperationID = "wait.fail"

        executor.perform(id: id) { throw Boom() }

        do {
            try await executor.wait(id: id)
            XCTFail("expected throw")
        } catch let error as OperationError {
            XCTAssertEqual(error.description, "boom-detail")
            XCTAssertTrue(error.underlyingTypeName.contains("Boom"))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    @available(iOS 18.0, *)
    func testWaitReturnsForRunningOperation() async throws {
        let executor = OperationExecutor()
        let id: OperationID = "wait.live"

        executor.perform(id: id) {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        // Subscribe while the op is still running — wait must observe completion.
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await executor.wait(id: id)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                throw NSError(domain: "TestTimeout", code: 0, userInfo: [NSLocalizedDescriptionKey: "wait did not return"])
            }
            try await group.next()
            group.cancelAll()
        }
    }

    func testIgnoreActiveAllowsRepeatPerform() async {
        let executor = OperationExecutor()
        let id: OperationID = "repeated"
        let watcher = executor.watcher(id: id)

        let counter = SyncCounter()
        executor.perform(id: id) {
            counter.increment()
        }
        await waitForState(watcher) { $0 == .success }

        // Without ignoreActive: previous run is .success, not .inProgress, so this still runs.
        executor.perform(id: id, ignoreActive: true) {
            counter.increment()
        }
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(counter.value, 2)
    }

    // MARK: - Helpers

    private func waitForState(
        _ watcher: OperationWatcher,
        timeout: TimeInterval = 2.0,
        until predicate: @MainActor (OperationState) -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while !predicate(watcher.state) {
            if Date() > deadline {
                XCTFail("timeout waiting for state; last = \(watcher.state)", file: file, line: line)
                return
            }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}

// MARK: - Helpers

@MainActor
private final class StateObserver {
    private(set) var log: [OperationState] = []
    private var task: Task<Void, Never>?
    private let watcher: OperationWatcher

    init(watcher: OperationWatcher) {
        self.watcher = watcher
        self.log.append(watcher.state)
        startPolling()
    }

    private func startPolling() {
        task = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let current = self.watcher.state
                if self.log.last != current {
                    self.log.append(current)
                }
                try? await Task.sleep(nanoseconds: 1_000_000)
            }
        }
    }

    func stop() {
        task?.cancel()
        let final = watcher.state
        if log.last != final { log.append(final) }
    }
}

private final class SyncCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var _value = 0
    var value: Int {
        lock.lock(); defer { lock.unlock() }
        return _value
    }
    func increment() {
        lock.lock(); defer { lock.unlock() }
        _value += 1
    }
}
