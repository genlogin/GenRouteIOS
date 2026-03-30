import Foundation

/// Giá trị điều hướng: điểm xuất phát có thể là GPS hiện tại (mock/user) hoặc 1 place trong DB; điểm đến là 1 place trong DB.
struct DirectionsRouteNavigationValue: Hashable, Sendable, Codable {
    let endPlaceId: UUID
    /// Nếu có, start lấy từ place trong DB.
    let startPlaceId: UUID?
    /// Nếu có, start lấy từ GPS hiện tại (mock/user).
    let startLatitude: Double?
    let startLongitude: Double?

    static func userLocationToSaved(endPlaceId: UUID, userLatitude: Double, userLongitude: Double) -> Self {
        Self(endPlaceId: endPlaceId, startPlaceId: nil, startLatitude: userLatitude, startLongitude: userLongitude)
    }

    static func savedToSaved(startPlaceId: UUID, endPlaceId: UUID) -> Self {
        Self(endPlaceId: endPlaceId, startPlaceId: startPlaceId, startLatitude: nil, startLongitude: nil)
    }
}
