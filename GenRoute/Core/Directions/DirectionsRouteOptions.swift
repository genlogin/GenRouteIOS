import Foundation

/// Loại phương tiện người dùng chọn cho chỉ đường (ánh xạ sang `MKDirectionsTransportType`).
enum DirectionsVehicleType: String, Codable, CaseIterable, Sendable {
    case bicycle
    case motorcycle
}

/// Tùy chọn tuyến do người dùng cấu hình; có thể lưu qua `DirectionsRoutePreferencesStoring`.
struct DirectionsRouteOptions: Equatable, Codable, Sendable {
    var vehicle: DirectionsVehicleType
    var avoidHighways: Bool
    var avoidTolls: Bool
    /// MapKit không có cờ riêng; xử lý qua tuyến thay thế + lọc bước có từ khóa phà.
    var avoidFerries: Bool
    /// Heuristic: chọn tuyến dài hơn trong các phương án thay thế (thường tránh shortcut địa hình xấu).
    var avoidPoorRoads: Bool

    static let `default` = DirectionsRouteOptions(
        vehicle: .motorcycle,
        avoidHighways: false,
        avoidTolls: false,
        avoidFerries: false,
        avoidPoorRoads: false
    )
}
