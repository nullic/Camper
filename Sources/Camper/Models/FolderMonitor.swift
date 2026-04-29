import Foundation
import Observation

public struct FilePathInfo: Sendable {
    public let isFolder: Bool
    public let name: String
    public let url: URL
    public let size: Int64
    public let date: Date

    public init(url: URL) {
        let attrs: [FileAttributeKey: Any] = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
        let type = attrs[FileAttributeKey.type] as? String ?? ""
        let modificationDate = attrs[FileAttributeKey.modificationDate] as? Date

        self.url = url
        self.name = url.lastPathComponent
        self.isFolder = FileAttributeType(rawValue: type) == .typeDirectory
        self.size = (attrs[FileAttributeKey.size] as? NSNumber)?.int64Value ?? 0
        self.date = modificationDate ?? attrs[FileAttributeKey.creationDate] as? Date ?? Date(timeIntervalSince1970: 0)
    }
}

@Observable
public final class FolderMonitor: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.folder_monitor.queue")
    private var folderMonitorSource: DispatchSourceFileSystemObject?
    @MainActor public private(set) var folderContent: [FilePathInfo] = []

    private var isStopped: Bool = true
    public let url: URL
    public init(url: URL) {
        precondition(url.isFileURL)
        self.url = url
    }

    deinit {
        _stopMonitoring()
    }

    public func startMonitoring() {
        queue.asyncUnsafe {
            self._startMonitoring()
        }
    }

    public func stopMonitoring() {
        queue.asyncUnsafe {
            self._stopMonitoring()
        }
    }

    private func _startMonitoring() {
        guard folderMonitorSource == nil else { return }
        guard isStopped else { return }

        let path = url.path
        CamperLogger.fileMonitor.debug("start monitoring path: \(path)")

        let fileDescriptor = open(path, O_EVTONLY)
        folderMonitorSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .all, queue: queue)
        folderMonitorSource?.setEventHandler { [weak self] in
            CamperLogger.fileMonitor.debug("did change at path: \(path)")
            guard let self else { return }
            Task { @MainActor in
                self.readFolderContent()
            }
        }

        folderMonitorSource?.setCancelHandler { [weak self] in
            CamperLogger.fileMonitor.debug("did cancel at path: \(path)")
            close(fileDescriptor)
            self?.folderMonitorSource = nil
            self?.isStopped = true
        }

        isStopped = false
        folderMonitorSource?.resume()
        Task { @MainActor in
            readFolderContent()
        }
    }

    private func _stopMonitoring() {
        guard let folderMonitorSource else { return }
        folderMonitorSource.cancel()
        self.folderMonitorSource = nil
        CamperLogger.fileMonitor.debug("stop monitoring path: \(url.path)")
    }

    @MainActor
    private func readFolderContent() {
        var content: [FilePathInfo] = []

        let contentsOfDirectory = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        for file in contentsOfDirectory {
            let url = url.appendingPathComponent(file)
            content.append(FilePathInfo(url: url))
        }

        folderContent = content
    }
}
