import Foundation

/// `print` có prefix khi `DirectionsEnvironment.isDev` (Xcode console).
enum DirectionsDevLog {
    static func log(_ message: String) {
        guard DirectionsEnvironment.isDev else { return }
        print("[GenRouteDev] \(message)")
    }
}
