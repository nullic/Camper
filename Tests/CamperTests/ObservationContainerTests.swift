import Foundation
import XCTest

@testable import Camper

final class ObservationContainerTests: XCTestCase {
    // MARK: - ObservationToken

    func testTokenInvokesOnChangeWhenNotified() {
        let cancelExpectation = expectation(description: "onCancel")
        let received = SyncList<Int>()

        do {
            let token = ObservationToken<Int>(
                onChange: { received.append($0) },
                onCancel: { _ in cancelExpectation.fulfill() }
            )
            token.notify(value: 1)
            token.notify(value: 2)
            token.notify(value: 3)
        }

        wait(for: [cancelExpectation], timeout: 1.0)
        XCTAssertEqual(received.values, [1, 2, 3])
    }

    func testTokenOnCancelFiresOnDeinit() {
        let cancelExpectation = expectation(description: "onCancel")
        let captured = SyncBox<UUID?>(nil)

        do {
            let token = ObservationToken<Void>(
                onChange: { _ in },
                onCancel: { uuid in
                    captured.set(uuid)
                    cancelExpectation.fulfill()
                }
            )
            XCTAssertNotNil(token.uuid)
        }

        wait(for: [cancelExpectation], timeout: 1.0)
        XCTAssertNotNil(captured.value)
    }

    func testTokenEqualityIsByUUID() {
        let a = ObservationToken<Int>(onChange: { _ in }, onCancel: { _ in })
        let b = ObservationToken<Int>(onChange: { _ in }, onCancel: { _ in })

        XCTAssertEqual(a, a)
        XCTAssertNotEqual(a, b)
    }

    // MARK: - ObservationContainer

    func testNotifyReachesObserver() async throws {
        let container = ObservationContainer<Int>()
        let received = Recorder()

        let token = container.addObserver { value in
            Task { await received.append(value) }
        }

        // Allow the addObserver task to commit before notifying.
        try await Task.sleep(nanoseconds: 50_000_000)
        await container.notifyObservers(value: 42)
        try await Task.sleep(nanoseconds: 50_000_000)

        let log = await received.values
        XCTAssertEqual(log, [42])
        _ = token
    }

    func testMultipleObserversAllReceive() async throws {
        let container = ObservationContainer<Int>()
        let recorderA = Recorder()
        let recorderB = Recorder()

        let tokenA = container.addObserver { value in
            Task { await recorderA.append(value) }
        }
        let tokenB = container.addObserver { value in
            Task { await recorderB.append(value) }
        }

        try await Task.sleep(nanoseconds: 50_000_000)
        await container.notifyObservers(value: 7)
        try await Task.sleep(nanoseconds: 50_000_000)

        let a = await recorderA.values
        let b = await recorderB.values
        XCTAssertEqual(a, [7])
        XCTAssertEqual(b, [7])
        _ = (tokenA, tokenB)
    }

    func testReleasingTokenStopsDelivery() async throws {
        let container = ObservationContainer<Int>()
        let received = Recorder()

        var token: ObservationToken<Int>? = container.addObserver { value in
            Task { await received.append(value) }
        }

        try await Task.sleep(nanoseconds: 50_000_000)
        await container.notifyObservers(value: 1)
        try await Task.sleep(nanoseconds: 50_000_000)

        token = nil

        // Wait for the cancel hop and a generous grace period for any in-flight notify.
        try await Task.sleep(nanoseconds: 100_000_000)
        await container.notifyObservers(value: 2)
        try await Task.sleep(nanoseconds: 100_000_000)

        let log = await received.values
        XCTAssertEqual(log, [1], "released observer must not receive new values")
        _ = token
    }
}

// MARK: - Helpers

private actor Recorder {
    private(set) var values: [Int] = []
    func append(_ value: Int) { values.append(value) }
}

private final class SyncList<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _values: [T] = []
    var values: [T] {
        lock.lock(); defer { lock.unlock() }
        return _values
    }
    func append(_ value: T) {
        lock.lock(); defer { lock.unlock() }
        _values.append(value)
    }
}

private final class SyncBox<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var _value: T
    init(_ value: T) { self._value = value }
    var value: T {
        lock.lock(); defer { lock.unlock() }
        return _value
    }
    func set(_ value: T) {
        lock.lock(); defer { lock.unlock() }
        self._value = value
    }
}
