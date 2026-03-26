import Foundation
import OSLog
import SwiftyBeaver
import ZIPFoundation

public protocol Logger {
    var subsystem: String { get }
    var category: String { get }

    func verbose(_ message: String, file: String, function: String, line: Int)
    func debug(_ message: String, file: String, function: String, line: Int)
    func info(_ message: String, file: String, function: String, line: Int)
    func warning(_ message: String, file: String, function: String, line: Int)
    func error(_ message: String, file: String, function: String, line: Int)
}

private extension SwiftyBeaver.Level {
    var osLogType: OSLogType {
        switch self {
        case .verbose: return .default
        case .debug: return .debug
        case .info: return .info
        case .warning: return .error
        case .error: return .fault
        case .critical: return .fault
        case .fault: return .fault
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

    private func log(level: SwiftyBeaver.Level, _ message: String, file: String, function: String, line: Int) {
        guard needWriteLog, LoggerConfigurator.minimumLogLevel.rawValue <= level.rawValue else { return }

        let log = "[\(category)][\((file as NSString).lastPathComponent):\(line) -- \(function)]: \(message)"
        LoggerConfigurator.logger.custom(level: level, message: log)

        os.Logger(subsystem: subsystem, category: category).log(level: level.osLogType, "[\((file as NSString).lastPathComponent):\(line) -- \(function)]: \(message)")

        if level.rawValue >= SwiftyBeaver.Level.error.rawValue {
            LoggerConfigurator.onError?(message)
        }
    }

    func verbose(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .verbose, message, file: file, function: function, line: line)
    }

    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .debug, message, file: file, function: function, line: line)
    }

    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .verbose, message, file: file, function: function, line: line)
    }

    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .warning, message, file: file, function: function, line: line)
    }

    func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        log(level: .error, message, file: file, function: function, line: line)
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
