import Foundation
import XCTest

@testable import Camper

final class LoggerConfiguratorTests: XCTestCase {
    override func tearDown() {
        // Reset to defaults so subsequent tests start with clean configuration.
        LoggerConfigurator.configure()
        super.tearDown()
    }

    func testOnErrorClosureFiresOnErrorLevel() {
        let received = SyncList<String>()
        LoggerConfigurator.configure(onError: { received.append($0) })

        TestLogger.test.error("boom")
        XCTAssertEqual(received.values.count, 1)
        XCTAssertTrue(received.values.first?.contains("boom") == true)
    }

    func testOnErrorClosureDoesNotFireBelowErrorLevel() {
        let received = SyncList<String>()
        LoggerConfigurator.configure(onError: { received.append($0) })

        TestLogger.test.info("hello")
        TestLogger.test.warning("warn")
        XCTAssertEqual(received.values, [])
    }

    func testMinimumLogLevelFiltersBelow() {
        let received = SyncList<String>()
        LoggerConfigurator.configure(minimumLogLevel: .error, onError: { received.append($0) })

        TestLogger.test.warning("warn")
        TestLogger.test.error("err")
        XCTAssertEqual(received.values.count, 1, "only .error and above should be delivered")
        XCTAssertTrue(received.values.first?.contains("err") == true)
    }

    func testEnvironmentVariableGatingSuppressesLogsWhenAbsent() {
        let received = SyncList<String>()
        LoggerConfigurator.configure(useEnvironmentVariables: true, onError: { received.append($0) })

        // No `TEST_LOGS` env var is set in xctest, so logs must be suppressed.
        TestLogger.test.error("ignored")
        XCTAssertEqual(received.values, [])
    }

    func testReconfigureReplacesOnErrorClosure() {
        let firstReceiver = SyncList<String>()
        let secondReceiver = SyncList<String>()

        LoggerConfigurator.configure(onError: { firstReceiver.append($0) })
        LoggerConfigurator.configure(onError: { secondReceiver.append($0) })

        TestLogger.test.error("once")
        XCTAssertEqual(firstReceiver.values, [], "previous closure must not be called after reconfigure")
        XCTAssertEqual(secondReceiver.values.count, 1)
    }

    func testConcurrentConfigureAndLogDoesNotCrash() {
        let received = SyncList<String>()
        LoggerConfigurator.configure(onError: { received.append($0) })

        let queue = DispatchQueue(label: "logger.config.stress", attributes: .concurrent)
        let group = DispatchGroup()

        for i in 0 ..< 100 {
            group.enter()
            queue.async {
                LoggerConfigurator.configure(
                    minimumLogLevel: i % 2 == 0 ? .debug : .error,
                    onError: { received.append($0) }
                )
                group.leave()
            }
        }

        for i in 0 ..< 200 {
            group.enter()
            queue.async {
                TestLogger.test.error("stress-\(i)")
                group.leave()
            }
        }

        group.wait()
        // Reaching this point under TSan / unfair-lock without a crash is the assertion.
        XCTAssertGreaterThanOrEqual(received.values.count, 0)
    }
}

// MARK: - Helpers

private enum TestLogger: String, Camper.Logger {
    case test

    var subsystem: String { "CamperTests" }
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
