import Foundation

/// Appends log lines to files in one folder. A file is started by the first line written to it and
/// closed once it has reached `maxFileSize`, so the next line starts another; only the newest
/// `maxFiles` files stay in the folder. All of it happens on one serial queue, in the order the
/// lines were handed over.
final class LogFileWriter: @unchecked Sendable {
    private let folder: URL
    private let maxFileSize: Int
    private let maxFiles: Int
    private let queue = DispatchQueue(label: "com.camper.log-file-writer", qos: .utility)

    // Everything below belongs to `queue`.
    private var descriptor: Int32 = -1
    private var written = 0
    private var reportedFailure = false
    private let timestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSxxx"
        return formatter
    }()

    private let fileName: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH-mm-ss"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    init(folder: URL, maxFileSize: Int = 5 * 1024 * 1024, maxFiles: Int = 5) {
        self.folder = folder
        self.maxFileSize = maxFileSize
        self.maxFiles = maxFiles
    }

    deinit {
        if descriptor >= 0 { Darwin.close(descriptor) }
    }

    func append(level: String, _ message: String) {
        let date = Date()
        queue.async { [self] in
            guard openIfNeeded() else { return }

            let line = Data("\(timestamp.string(from: date)) \(level) \(message)\n".utf8)
            // One `write` per line: with O_APPEND the line lands whole even if another process
            // appends to the same file or the archive is gathered meanwhile.
            let count = line.withUnsafeBytes { write(descriptor, $0.baseAddress, $0.count) }
            guard count == line.count else {
                reportFailure("could not write to the log file")
                closeFile()
                return
            }

            written += count
            if written >= maxFileSize { closeFile() }
        }
    }

    /// Returns once every line handed over before the call is in the file.
    func flush() {
        queue.sync {}
    }

    /// Flushes and lets go of the file. The writer opens a new one if it is used again.
    func close() {
        queue.sync { closeFile() }
    }

    // MARK: - Queue-confined

    private func closeFile() {
        if descriptor >= 0 { Darwin.close(descriptor) }
        descriptor = -1
        written = 0
    }

    private func openIfNeeded() -> Bool {
        if descriptor >= 0 { return true }

        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            reportFailure("could not create the logs folder: \(error.localizedDescription)")
            return false
        }

        let unique = String(UUID().uuidString.prefix(8))
        let url = folder.appendingPathComponent("\(fileName.string(from: Date()))-\(unique).log")

        // Created with no data protection: a log written in the background while the device is
        // locked would otherwise be lost.
        #if os(iOS) || os(watchOS)
        let attributes: [FileAttributeKey: Any] = [.protectionKey: FileProtectionType.none]
        #else
        let attributes: [FileAttributeKey: Any]? = nil
        #endif
        guard FileManager.default.createFile(atPath: url.path, contents: nil, attributes: attributes) else {
            reportFailure("could not create \(url.path)")
            return false
        }

        descriptor = open(url.path, O_WRONLY | O_APPEND)
        guard descriptor >= 0 else {
            reportFailure("could not open \(url.path)")
            return false
        }

        prune()
        return true
    }

    /// Keeps the newest `maxFiles` log files, the one just opened included.
    private func prune() {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        guard let files = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys) else { return }

        let logs = files
            .filter { $0.pathExtension == "log" }
            .map { ($0, (try? $0.resourceValues(forKeys: Set(keys)).contentModificationDate) ?? .distantPast) }
            .sorted { $0.1 > $1.1 }

        for (url, _) in logs.dropFirst(maxFiles) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func reportFailure(_ reason: String) {
        guard !reportedFailure else { return }
        reportedFailure = true
        debugPrint("Camper: \(reason)")
    }
}
