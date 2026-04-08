import Foundation
import MapKit

enum DirectionsRoutingError: Error {
    case noRouteFound
}

/// Fallback MapKit khi Valhalla lỗi; tùy chọn vẫn là `DirectionsRouteOptions`.
protocol DirectionsRoutingServiceProtocol: Sendable {
    func calculateRoute(
        from start: RouteEndpoint,
        to end: RouteEndpoint,
        options: DirectionsRouteOptions
    ) async throws -> MKRoute
}
