import Foundation

/// Lý do kết thúc phiên điều hướng (dùng cho bản sao chuyến và nội dung dialog).
enum TripCompletionReason: String, Hashable, Sendable, Codable {
    case arrivedAtDestination
    case stoppedByUser
}
