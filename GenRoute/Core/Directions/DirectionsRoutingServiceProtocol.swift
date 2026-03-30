import Foundation
import MapKit

enum DirectionsRoutingError: Error {
    case noRouteFound
}

/// Chỉ chịu trách nhiệm gọi MapKit với `DirectionsRouteOptions` (SRP, DIP).
protocol DirectionsRoutingServiceProtocol: Sendable {
    func calculateRoute(
        from start: RouteEndpoint,
        to end: RouteEndpoint,
        options: DirectionsRouteOptions
    ) async throws -> MKRoute
}
