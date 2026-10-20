import Foundation
import os
import OSLog

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
}

private enum InternalLogLevel {
    case debug
    case info
    case notice
    case warning
    case error
    case critical
    case fault

    /// The `LogLevel.rawValue` this level answers to when it is held against the minimum.
    var rank: Int {
        switch self {
        case .debug: return LogLevel.debug.rawValue
        case .info, .notice: return LogLevel.info.rawValue
        case .warning: return LogLevel.warning.rawValue
        case .error: return LogLevel.error.rawValue
        case .critical: return LogLevel.critical.rawValue
        case .fault: return LogLevel.fault.rawValue
        }
    }

    var name: String {
        switch self {
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .notice: return "NOTICE"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        case .fault: return "FAULT"
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
        let config = LoggerConfigurator.snapshot
        let envOK = !config.useEnvironmentVariables || ProcessInfo.processInfo.environment["\(category)_LOGS"] != nil
        guard envOK, config.minimumLogLevel.rawValue <= level.rank else { return }

        let location = "\((file as NSString).lastPathComponent):\(line) -- \(function)"
        config.writer?.append(level: level.name, "[\(category)][\(location)]: \(message)")
        os.Logger(subsystem: subsystem, category: category).log(level: level.osLogType, "[\(location)]: \(message)")

        if level.rank >= LogLevel.error.rawValue {
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
        var writer: LogFileWriter?
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
        let writer = writeLogFile ? LogFileWriter(folder: logsFolder) : nil
        let previous = stateLock.withLock { state in
            let previous = state.writer
            state.useEnvironmentVariables = useEnvironmentVariables
            state.writeLogFile = writeLogFile
            state.minimumLogLevel = minimumLogLevel
            state.onError = onError
            state.writer = writer
            return previous
        }
        previous?.close()

        if writeLogFile {
            debugPrint("Logs output: \(logsFolder.path)")
        }
    }

    public static func clearLogs() throws {
        flush()

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: logsFolder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return
        }

        // The writer lets go of its file first and starts a new one with the next line.
        snapshot.writer?.close()
        try FileManager.default.removeItem(atPath: logsFolder.path)
    }

    public static func logsToSend() throws -> URL {
        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(atPath: logsFolder.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
            try FileManager.default.createDirectory(at: logsFolder, withIntermediateDirectories: true)
        }

        flush()

        let resultUrl = logsFolder.appendingPathExtension("zip")
        let staging = logsFolder
            .deletingLastPathComponent()
            .appendingPathComponent("logs-\(UUID().uuidString.prefix(8)).zip")

        var kept: Error?
        var refused: NSError?
        NSFileCoordinator().coordinate(readingItemAt: logsFolder, options: [.forUploading], error: &refused) { zipped in
            do {
                try FileManager.default.copyItem(at: zipped, to: staging)
            } catch {
                kept = error
            }
        }
        if let refused { throw refused }
        if let kept { throw kept }

        // Put in place in one step: rename(2) replaces an archive that is there and makes one that
        // is not, so a caller arriving meanwhile never sees it missing or half-replaced. Asking
        // first and then moving or replacing raced — the answer was stale by the time it was used.
        guard rename(staging.path, resultUrl.path) == 0 else {
            let code = errno
            try? FileManager.default.removeItem(at: staging) // a leftover staging copy is only clutter
            throw NSError(domain: NSPOSIXErrorDomain, code: Int(code), userInfo: [NSFilePathErrorKey: resultUrl.path])
        }
        return resultUrl
    }

    @available(*, deprecated, renamed: "logsToSend()")
    public static func zipLogs() throws -> URL {
        try logsToSend()
    }

    public static func flush() {
        snapshot.writer?.flush()
    }
}
