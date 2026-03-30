import Foundation

/// Đích điều hướng trong tab Ride (stack: chỉ đường → kết quả).
enum RideNavigationDestination: Hashable, Sendable, Codable {
    case directions(DirectionsRouteNavigationValue)
    case tripResult(TripResultSummary)
}
