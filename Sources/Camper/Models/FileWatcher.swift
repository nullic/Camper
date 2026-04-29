import Foundation
import Observation

@Observable
public final class FileWatcher: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.file_watcher.queue")
    private var folderMonitorSource: DispatchSourceFileSystemObject?
    @MainActor public private(set) var isExist: Bool = false
    @MainActor public private(set) var hashValue: Int = 0

    private var isStopped: Bool = true
    private let folder: String

    public let url: URL

    @MainActor
    public init(url: URL) {
        precondition(url.isFileURL)

        self.url = url
        self.folder = url.deletingLastPathComponent().path(percentEncoded: false)
        checkExist()
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

        let path = folder
        CamperLogger.fileMonitor.debug("start monitoring path: \(path)")

        let fileDescriptor = open(path, O_EVTONLY)
        folderMonitorSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor, eventMask: .all, queue: queue)
        folderMonitorSource?.setEventHandler { [weak self] in
            CamperLogger.fileMonitor.debug("did change at path: \(path)")
            guard let self else { return }
            Task { @MainActor in
                self.checkExist()
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
            checkExist()
        }
    }

    private func _stopMonitoring() {
        guard let folderMonitorSource else { return }
        folderMonitorSource.cancel()
        self.folderMonitorSource = nil
        CamperLogger.fileMonitor.debug("stop monitoring path: \(url.path)")
    }

    @MainActor
    private func checkExist() {
        var isDirectory: ObjCBool = false
        let newValue = FileManager.default.fileExists(atPath: url.path(percentEncoded: false), isDirectory: &isDirectory)
        if isExist != newValue {
            isExist = newValue && !isDirectory.boolValue
        }

        if isExist {
            let attrs: [FileAttributeKey: Any] = (try? FileManager.default.attributesOfItem(atPath: url.path)) ?? [:]
            let modificationDate = attrs[FileAttributeKey.modificationDate] as? Date
            let createDate = modificationDate ?? attrs[FileAttributeKey.creationDate] as? Date ?? Date(timeIntervalSince1970: 0)

            let newValue = createDate.hashValue
            if hashValue != newValue {
                hashValue = newValue
            }
        } else {
            if hashValue != 0 {
                hashValue = 0
            }
        }
    }
}
