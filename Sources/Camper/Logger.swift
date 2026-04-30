import Foundation
import os
import OSLog
@preconcurrency import SwiftyBeaver
import ZIPFoundation

public protocol Logger {
    var subsystem: String { get }
    var category: String { get }

    func debug(_ message: String, file: String, function: String, line: Int)
    func info(_ message: String, file: String, function: String, line: Int)
    func notice(_ message: String, file: String, function: String, line: Int)
    func warning(_ message: String, file: String, function: String, line: Int)
    func error(_ message: String, file: String, function: String, line: Int)
    func critical(_ message: String, file: String, function: String, line: Int)
    func fault(_ message: String, file: String, function: String, line: Int)
}

public enum LogLevel: Int, Sendable, Comparable {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    case critical = 5
    case fault = 6

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    fileprivate var swiftyBeaver: SwiftyBeaver.Level {
        switch self {
        case .verbose: return .verbose
        case .debug: return .debug
        case .info: return .info
        case .warning: return .warning
        case .error: return .error
        case .critical: return .critical
        case .fault: return .fault
        }
    }
}

private enum InternalLogLevel {
    case debug
    case info
    case notice
    case warning
    case error
    case critical
    case fault

    var swiftyBeaver: SwiftyBeaver.Level {
        switch self {
        case .debug: return .debug
        case .info, .notice: return .info
        case .warning: return .warning
        case .error: return .error
        case .critical: return .critical
        case .fault: return .fault
        }
    }

    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info: return .info
        case .notice: return .default
        case .warning, .error: return .error
        case .critical, .fault: return .fault
        }
    }
}

public extension Logger where Self: RawRepresentable {
    var category: String { "\(rawValue)".uppercased() }
}

public extension Logger {
    private func log(_ level: InternalLogLevel, _ message: String, file: String, function: String, line: Int) {
        let sbLevel = level.swiftyBeaver
        let config = LoggerConfigurator.snapshot
        let envOK = !config.useEnvironmentVariables || ProcessInfo.processInfo.environment["\(category)_LOGS"] != nil
        guard envOK, config.minimumLogLevel.rawValue <= sbLevel.rawValue else { return }

        let location = "\((file as NSString).lastPathComponent):\(line) -- \(function)"
        SwiftyBeaver.custom(level: sbLevel, message: "[\(category)][\(location)]: \(message)")
        os.Logger(subsystem: subsystem, category: category).log(level: level.osLogType, "[\(location)]: \(message)")

        if sbLevel.rawValue >= SwiftyBeaver.Level.error.rawValue {
            config.onError?(message)
        }
    }

    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message, file: file, function: function, line: line)
    }

    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message, file: file, function: function, line: line)
    }

    func notice(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.notice, message, file: file, function: function, line: line)
    }

    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message, file: file, function: function, line: line)
    }

    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message, file: file, function: function, line: line)
    }

    func critical(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.critical, message, file: file, function: function, line: line)
    }

    func fault(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(.fault, message, file: file, function: function, line: line)
    }
}

// MARK: -

public enum LoggerConfigurator {
    fileprivate struct State: Sendable {
        var useEnvironmentVariables: Bool = false
        var writeLogFile: Bool = false
        var minimumLogLevel: LogLevel = .debug
        var onError: (@Sendable (String) -> Void)?
    }

    private static let stateLock = OSAllocatedUnfairLock<State>(initialState: State())

    fileprivate static var snapshot: State { stateLock.withLock { $0 } }

    public static let logsFolder: URL = {
        let folder = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!
        return URL(fileURLWithPath: folder).appendingPathComponent("logs")
    }()

    public static func configure(
        useEnvironmentVariables: Bool = false,
        writeLogFile: Bool = false,
        minimumLogLevel: LogLevel = .debug,
        onError: (@Sendable (String) -> Void)? = nil
    ) {
        stateLock.withLock {
            $0.useEnvironmentVariables = useEnvironmentVariables
            $0.writeLogFile = writeLogFile
            $0.minimumLogLevel = minimumLogLevel
            $0.onError = onError
        }

        SwiftyBeaver.removeAllDestinations()
        if writeLogFile {
            addFileDestination()
        }
    }

    private static func addFileDestination() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let date = formatter.string(from: Date())
        let unique = String(UUID().uuidString.prefix(8))

        let url = logsFolder.appendingPathComponent("\(date)-\(unique).log")
        let destination = FileDestination(logFileURL: url)
        destination.logFileMaxSize = 15 * 1024 * 1024
        SwiftyBeaver.addDestination(destination)

        debugPrint("Logs output: \(url.path)")
    }

    public static func clearLogs() throws {
        flush()

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: logsFolder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return
        }

        SwiftyBeaver.removeAllDestinations()
        try FileManager.default.removeItem(atPath: logsFolder.path)

        if snapshot.writeLogFile {
            addFileDestination()
        }
    }

    public static func zipLogs() throws -> URL {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: logsFolder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw NSError(domain: "LoggerDomain", code: -1, userInfo: nil)
        }

        let resultUrl = logsFolder.appendingPathExtension("zip")
        if FileManager.default.fileExists(atPath: resultUrl.path) {
            try FileManager.default.removeItem(atPath: resultUrl.path)
        }

        flush()
        try FileManager.default.zipItem(at: logsFolder, to: resultUrl)
        return URL(fileURLWithPath: resultUrl.path)
    }

    public static func flush() {
        _ = SwiftyBeaver.flush(secondTimeout: 10)
    }
}
