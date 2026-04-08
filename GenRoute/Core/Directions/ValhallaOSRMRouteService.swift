import CoreLocation
import Foundation

/// Valhalla `POST /route` + `format=osrm` — tuyến chính, geometry, intersections, bước chỉ dẫn.
enum ValhallaOSRMRouteService {
    struct Intersection: Sendable {
        let coordinate: CLLocationCoordinate2D
        let bearings: [Int]
    }

    struct ValhallaNavigationRoute: Sendable {
        let routeCoordinates: [CLLocationCoordinate2D]
        let intersections: [Intersection]
        let distanceMeters: CLLocationDistance
        let durationSeconds: TimeInterval
        let turnSteps: [NavigationTurnStep]
    }

    static func fetchNavigationRoute(
        baseURL: URL,
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D,
        options: DirectionsRouteOptions
    ) async throws -> ValhallaNavigationRoute {
        let costing = valhallaCosting(for: options.vehicle)
        let body = buildRequestJSONObject(
            start: start,
            end: end,
            costing: costing,
            language: "vi",
            options: options
        )
        let url = baseURL.appendingPathComponent("route")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, resp) = try await URLSession.shared.data(for: request)
        if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let snippet = String(data: data, encoding: .utf8).map { String($0.prefix(500)) } ?? ""
            await MainActor.run {
                DirectionsDevLog.log("Valhalla HTTP \(http.statusCode) body.prefix=\(snippet)")
            }
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(ValhallaResponseDTO.self, from: data)
        if let code = decoded.code, code != "Ok" {
            throw URLError(.badServerResponse)
        }
        guard let first = decoded.routes.first else {
            throw URLError(.badServerResponse)
        }

        let routeCoords = Polyline6.decode(first.geometry)
        guard routeCoords.count >= 2 else {
            throw URLError(.badServerResponse)
        }

        var intersections: [Intersection] = []
        intersections.reserveCapacity(256)
        var turnSteps: [NavigationTurnStep] = []
        turnSteps.reserveCapacity(64)

        for leg in first.legs {
            for step in leg.steps {
                let dist = max(0, step.distance)
                let ins = normalizedInstruction(instruction: step.maneuver?.instruction, streetName: step.name)
                turnSteps.append(NavigationTurnStep(distance: dist, instructions: ins))

                for inter in step.intersections {
                    guard inter.location.count == 2 else { continue }
                    let lon = inter.location[0]
                    let lat = inter.location[1]
                    let bearings = inter.bearings ?? []
                    if bearings.isEmpty { continue }
                    intersections.append(
                        Intersection(
                            coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                            bearings: bearings
                        )
                    )
                }
            }
        }

        let distanceMeters: CLLocationDistance = {
            if let d = first.distance, d > 0 { return d }
            return turnSteps.reduce(0) { $0 + $1.distance }
        }()

        let durationSeconds: TimeInterval = {
            if let t = first.duration, t > 0 { return t }
            return 0
        }()

        return ValhallaNavigationRoute(
            routeCoordinates: routeCoords,
            intersections: intersections,
            distanceMeters: distanceMeters,
            durationSeconds: durationSeconds,
            turnSteps: turnSteps
        )
    }

    /// `motorcycle` dùng `auto` để khớp server Valhalla công khai / cấu hình Android thường gặp.
    private static func valhallaCosting(for vehicle: DirectionsVehicleType) -> String {
        switch vehicle {
        case .bicycle: return "bicycle"
        case .motorcycle: return "auto"
        }
    }

    private static func buildRequestJSONObject(
        start: CLLocationCoordinate2D,
        end: CLLocationCoordinate2D,
        costing: String,
        language: String,
        options: DirectionsRouteOptions
    ) -> [String: Any] {
        let useHigh = options.avoidHighways ? 0.0 : 1.0
        let useTolls = options.avoidTolls ? 0.0 : 1.0
        let useFerry = options.avoidFerries ? 0.0 : 1.0
        let useUnpaved = options.avoidPoorRoads ? 0.0 : 1.0

        let roadish: [String: Any] = [
            "top_speed": 130,
            "use_highways": useHigh,
            "use_tolls": useTolls,
            "use_ferry": useFerry,
            "use_unpaved": useUnpaved,
        ]

        let costingOptions: [String: Any]
        switch costing {
        case "bicycle":
            costingOptions = ["bicycle": ["use_roads": 1.0]]
        default:
            costingOptions = ["auto": roadish]
        }

        return [
            "format": "osrm",
            "costing": costing,
            "language": language,
            "banner_instructions": true,
            "voice_instructions": true,
            "directions_options": ["units": "kilometers"],
            "costing_options": costingOptions,
            "locations": [
                ["lon": start.longitude, "lat": start.latitude, "type": "break"],
                ["lon": end.longitude, "lat": end.latitude, "type": "break"],
            ],
        ]
    }

    private static func normalizedInstruction(instruction: String?, streetName: String?) -> String {
        if let t = instruction?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty {
            return t
        }
        if let n = streetName?.trimmingCharacters(in: .whitespacesAndNewlines), !n.isEmpty {
            return n
        }
        return ""
    }
}

// MARK: - DTOs

private struct ValhallaResponseDTO: Decodable {
    let routes: [RouteDTO]
    let code: String?

    struct RouteDTO: Decodable {
        let geometry: String
        let legs: [LegDTO]
        let distance: Double?
        let duration: Double?
    }

    struct LegDTO: Decodable {
        let steps: [StepDTO]
    }

    struct StepDTO: Decodable {
        let distance: Double
        let name: String?
        let maneuver: ManeuverDTO?
        let intersections: [IntersectionDTO]

        struct ManeuverDTO: Decodable {
            let instruction: String?
            let type: String?
        }
    }

    struct IntersectionDTO: Decodable {
        let location: [Double]
        let bearings: [Int]?
    }
}
