import Foundation

enum CamperLogger: String, Logger {
    var subsystem: String { "Camper" }

    case fileMonitor
    case operationExecutor
}
