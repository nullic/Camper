import Foundation
import OSLog
import SwiftyBeaver
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

private enum LogLevel {
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
    private var needWriteLog: Bool {
        LoggerConfigurator.useEnvironmentVariables == false || ProcessInfo.processInfo.environment["\(category)_LOGS"] != nil
    }

    private func log(_ level: LogLevel, _ message: String, file: String, function: String, line: Int) {
        let sbLevel = level.swiftyBeaver
        guard needWriteLog, LoggerConfigurator.minimumLogLevel.rawValue <= sbLevel.rawValue else { return }

        let location = "\((file as NSString).lastPathComponent):\(line) -- \(function)"
        LoggerConfigurator.logger.custom(level: sbLevel, message: "[\(category)][\(location)]: \(message)")
        os.Logger(subsystem: subsystem, category: category).log(level: level.osLogType, "[\(location)]: \(message)")

        if sbLevel.rawValue >= SwiftyBeaver.Level.error.rawValue {
            LoggerConfigurator.onError?(message)
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

public actor LoggerConfigurator {
    fileprivate static let logger = SwiftyBeaver.self
    fileprivate nonisolated(unsafe) static var useEnvironmentVariables: Bool = false
    fileprivate nonisolated(unsafe) static var writeLogFile: Bool = false
    fileprivate nonisolated(unsafe) static var minimumLogLevel: SwiftyBeaver.Level = .debug
    fileprivate nonisolated(unsafe) static var onError: (@Sendable (String) -> Void)?

    public static let logsFolder: URL = {
        let folder = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true).first!
        return URL(fileURLWithPath: folder).appendingPathComponent("logs")
    }()

    public static func configure(useEnvironmentVariables: Bool = false, writeLogFile: Bool = false, minimumLogLevel: SwiftyBeaver.Level = .debug, onError: (@Sendable (String) -> Void)? = nil) {
        LoggerConfigurator.useEnvironmentVariables = useEnvironmentVariables
        LoggerConfigurator.writeLogFile = writeLogFile
        LoggerConfigurator.minimumLogLevel = minimumLogLevel
        LoggerConfigurator.onError = onError

        logger.removeAllDestinations()

        if writeLogFile {
            addFileDestination()
        }
    }

    private static func addFileDestination() {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let date = formatter.string(from: Date())

        let url = LoggerConfigurator.logsFolder.appendingPathComponent("\(date).log")

        let destination = FileDestination(logFileURL: url)
        destination.logFileMaxSize = (15 * 1024 * 1024)
        logger.addDestination(destination)

        debugPrint("Logs output: \(url.path)")
    }

    public static func clearLogs() throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: logsFolder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return
        }

        logger.removeAllDestinations()
        try FileManager.default.removeItem(atPath: logsFolder.path)

        if LoggerConfigurator.writeLogFile {
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
        _ = logger.flush(secondTimeout: 10)
    }
}
