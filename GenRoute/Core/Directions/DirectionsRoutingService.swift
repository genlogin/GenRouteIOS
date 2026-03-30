import Foundation
import MapKit

struct DirectionsRoutingService: DirectionsRoutingServiceProtocol {
    func calculateRoute(
        from start: RouteEndpoint,
        to end: RouteEndpoint,
        options: DirectionsRouteOptions
    ) async throws -> MKRoute {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: end.coordinate))

        switch options.vehicle {
        case .bicycle:
            request.transportType = .cycling
        case .motorcycle:
            request.transportType = .automobile
        }

        request.highwayPreference = options.avoidHighways ? .avoid : .any
        request.tollPreference = options.avoidTolls ? .avoid : .any

        let needsAlternates = options.avoidFerries || options.avoidPoorRoads
            || options.avoidHighways
            || options.avoidTolls
        request.requestsAlternateRoutes = needsAlternates

        let response = try await MKDirections(request: request).calculate()
        var routes = response.routes
        guard !routes.isEmpty else {
            throw DirectionsRoutingError.noRouteFound
        }

        if options.avoidFerries {
            let withoutFerry = routes.filter { !$0.likelyContainsFerryManeuver }
            if !withoutFerry.isEmpty {
                routes = withoutFerry
            }
        }

        if options.avoidPoorRoads {
            if let longest = routes.max(by: { $0.distance < $1.distance }) {
                return longest
            }
        }

        return routes[0]
    }
}
