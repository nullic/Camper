import Foundation
import XCTest

@testable import Camper

final class LoggerConfiguratorTests: XCTestCase {
    /// The logs folder is one real place, and `swift test --parallel` runs these tests in several
    /// processes at once: one deleted the folder or the archive another was gathering. Each test
    /// holds this lock, across processes, for as long as it runs.
    private static let lockPath = LoggerConfigurator.logsFolder.deletingLastPathComponent().appendingPathComponent("camper-logs-tests.lock").path
    private var lock: Int32 = -1

    override func setUpWithError() throws {
        try super.setUpWithError()
        try FileManager.default.createDirectory(atPath: (Self.lockPath as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        lock = open(Self.lockPath, O_CREAT | O_RDWR, 0o644)
        guard lock >= 0, flock(lock, LOCK_EX) == 0 else {
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno), userInfo: [NSFilePathErrorKey: Self.lockPath])
        }
    }

    override func tearDown() {
        // Reset to defaults so subsequent tests start with clean configuration.
        LoggerConfigurator.configure()
        if lock >= 0 {
            flock(lock, LOCK_UN)
            close(lock)
        }
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

    func testLogsAreGatheredEvenWhereNothingHasBeenWrittenYet() throws {
        LoggerConfigurator.configure(writeLogFile: false)
        try? FileManager.default.removeItem(at: LoggerConfigurator.logsFolder)
        try? FileManager.default.removeItem(at: LoggerConfigurator.logsFolder.appendingPathExtension("zip"))

        let url = try LoggerConfigurator.logsToSend()
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "a machine that has logged nothing yet still has something to hand over")
    }

    func testGatheringOverAnArchiveThatIsAlreadyThereReplacesIt() throws {
        LoggerConfigurator.configure(writeLogFile: true)
        TestLogger.test.error("first")
        let once = try LoggerConfigurator.logsToSend()
        TestLogger.test.error("second")
        let twice = try LoggerConfigurator.logsToSend()
        defer { try? FileManager.default.removeItem(at: twice) }

        XCTAssertEqual(once, twice)
        XCTAssertTrue(FileManager.default.fileExists(atPath: twice.path))
        XCTAssertEqual(try FileHandle(forReadingFrom: twice).read(upToCount: 2), Data("PK".utf8))
    }

    func testZippedLogsAreOneArchiveFile() throws {
        LoggerConfigurator.configure(writeLogFile: true)
        TestLogger.test.error("a line worth keeping")
        LoggerConfigurator.flush()

        let url = try LoggerConfigurator.logsToSend()
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        XCTAssertEqual(url.pathExtension, "zip")

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        XCTAssertEqual(try handle.read(upToCount: 2), Data("PK".utf8), "what comes back is a real archive, not a folder")
    }

    @available(*, deprecated)
    func testTheOldNameStillAnswers() throws {
        LoggerConfigurator.configure(writeLogFile: true)
        TestLogger.test.error("through the old door")

        let url = try LoggerConfigurator.zipLogs()
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(url, try LoggerConfigurator.logsToSend())
    }

    func testZippingTwiceReplacesWhatWasThere() throws {
        LoggerConfigurator.configure(writeLogFile: true)
        TestLogger.test.error("first")
        let once = try LoggerConfigurator.logsToSend()
        TestLogger.test.error("second")
        let twice = try LoggerConfigurator.logsToSend()
        defer { try? FileManager.default.removeItem(at: twice) }

        XCTAssertEqual(once, twice)
        XCTAssertTrue(FileManager.default.fileExists(atPath: twice.path))
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
