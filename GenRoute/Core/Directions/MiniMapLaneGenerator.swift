import CoreLocation
import MapKit

/// Tổng hợp các "spoke" lane phụ tại các điểm rẽ (maneuver) dọc tuyến.
///
/// iOS MapKit không cung cấp `intersection.bearings` như Android routing API,
/// nên ta tính bearing từ hình học polyline: hướng tiếp cận + hướng rời +
/// đường vuông góc (mô phỏng ngã tư / ngã ba).
///
/// Mỗi spoke là mảng 2 toạ độ `[hub, endpoint]` — hub là điểm rẽ,
/// endpoint ở khoảng cách `spokeLength` mét theo hướng bearing.
enum MiniMapLaneGenerator {
    /// Mặc định chiều dài spoke bằng bán kính mini map để lấp đầy viền tròn.
    static let defaultSpokeLength: CLLocationDistance = 100

    /// Khoảng cách tối thiểu giữa 2 hub (mét) — tránh chồng spoke.
    private static let minHubSeparation: CLLocationDistance = 18

    /// Góc tối thiểu giữa 2 bearing tại cùng hub (độ) — tránh trùng.
    private static let minBearingSeparation: Double = 15

    /// Số hub tối đa hiển thị gần user.
    private static let maxNearbyHubs: Int = 12

    // MARK: - Public

    /// Sinh tất cả spoke lane từ route steps.
    /// - Returns: mảng các spoke, mỗi spoke là `[hub, endpoint]`.
    static func generateLanes(from route: MKRoute, spokeLength: CLLocationDistance = defaultSpokeLength) -> [LaneSpoke] {
        let steps = route.steps
        guard steps.count >= 2 else { return [] }

        var hubs: [LaneHub] = []

        for i in 0..<steps.count {
            let stepCoords = steps[i].polyline.routeCoordinates
            guard let hub = stepCoords.first, stepCoords.count >= 2 else { continue }

            // Tránh hub quá gần hub trước đó
            if let lastHub = hubs.last {
                let dist = GeodesicDistance.meters(from: lastHub.coordinate, to: hub)
                if dist < minHubSeparation { continue }
            }

            var bearings: [Double] = []

            // Bearing tiếp cận (từ step trước đến hub)
            if i > 0 {
                let prevCoords = steps[i - 1].polyline.routeCoordinates
                if let prevEnd = prevCoords.last {
                    let approachBearing = Self.bearing(from: prevEnd, to: hub)
                    // Đường phía sau (kéo dài hướng tiếp cận ngược lại)
                    bearings.append(Self.normalizeBearing(approachBearing + 180))
                    // Đường vuông góc trái/phải
                    bearings.append(Self.normalizeBearing(approachBearing + 90))
                    bearings.append(Self.normalizeBearing(approachBearing - 90))
                }
            }

            // Bearing rời (từ hub đi tiếp trên step hiện tại)
            if stepCoords.count >= 2 {
                let departureBearing = Self.bearing(from: hub, to: stepCoords[1])
                // Đường kéo dài hướng rời
                bearings.append(Self.normalizeBearing(departureBearing + 180))
                // Nếu chưa có approach (step đầu tiên), thêm vuông góc
                if i == 0 {
                    bearings.append(Self.normalizeBearing(departureBearing + 90))
                    bearings.append(Self.normalizeBearing(departureBearing - 90))
                }
            }

            // Lọc bearing trùng (trong khoảng minBearingSeparation)
            let filtered = Self.deduplicateBearings(bearings)

            hubs.append(LaneHub(coordinate: hub, bearings: filtered))
        }

        // Sinh spoke từ hub + bearing
        var spokes: [LaneSpoke] = []
        for hub in hubs {
            for brng in hub.bearings {
                let endpoint = Self.destinationPoint(from: hub.coordinate, bearingDegrees: brng, distanceMeters: spokeLength)
                spokes.append(LaneSpoke(hub: hub.coordinate, endpoint: endpoint))
            }
        }

        return spokes
    }

    /// Lọc spoke chỉ giữ lại các hub gần user (tối đa `maxNearbyHubs`).
    static func filterNearUser(
        spokes: [LaneSpoke],
        userCoordinate: CLLocationCoordinate2D,
        radiusMeters: CLLocationDistance = 250
    ) -> [LaneSpoke] {
        // Nhóm theo hub
        var hubMap: [String: (coord: CLLocationCoordinate2D, spokes: [LaneSpoke], dist: CLLocationDistance)] = [:]
        for spoke in spokes {
            let key = "\(spoke.hub.latitude),\(spoke.hub.longitude)"
            let dist = GeodesicDistance.meters(from: userCoordinate, to: spoke.hub)
            if var entry = hubMap[key] {
                entry.spokes.append(spoke)
                hubMap[key] = entry
            } else {
                hubMap[key] = (spoke.hub, [spoke], dist)
            }
        }

        // Sắp xếp theo khoảng cách, lấy gần nhất
        let sorted = hubMap.values
            .filter { $0.dist <= radiusMeters }
            .sorted { $0.dist < $1.dist }
            .prefix(maxNearbyHubs)

        return sorted.flatMap { $0.spokes }
    }

    // MARK: - Private

    /// Bearing (độ, theo chiều kim đồng hồ từ Bắc) giữa 2 toạ độ.
    private static func bearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lon1 = a.longitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let lon2 = b.longitude * .pi / 180
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        var deg = atan2(y, x) * 180 / .pi
        if deg < 0 { deg += 360 }
        return deg
    }

    /// Điểm đích cách `origin` đúng `distanceMeters` theo hướng `bearingDegrees`.
    /// Port từ Android `buildLane()` — Vincenty direct (great-circle destination).
    private static func destinationPoint(
        from origin: CLLocationCoordinate2D,
        bearingDegrees: Double,
        distanceMeters: Double
    ) -> CLLocationCoordinate2D {
        let R = 6_371_000.0
        let brng = bearingDegrees * .pi / 180
        let lat1 = origin.latitude * .pi / 180
        let lon1 = origin.longitude * .pi / 180

        let lat2 = asin(
            sin(lat1) * cos(distanceMeters / R) +
            cos(lat1) * sin(distanceMeters / R) * cos(brng)
        )

        let lon2 = lon1 + atan2(
            sin(brng) * sin(distanceMeters / R) * cos(lat1),
            cos(distanceMeters / R) - sin(lat1) * sin(lat2)
        )

        return CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: lon2 * 180 / .pi
        )
    }

    /// Chuẩn hoá bearing về khoảng [0, 360).
    private static func normalizeBearing(_ degrees: Double) -> Double {
        var d = degrees.truncatingRemainder(dividingBy: 360)
        if d < 0 { d += 360 }
        return d
    }

    /// Loại bearing trùng trong khoảng `minBearingSeparation` độ.
    private static func deduplicateBearings(_ bearings: [Double]) -> [Double] {
        var result: [Double] = []
        for b in bearings {
            let isDuplicate = result.contains { existing in
                Self.angularDistance(existing, b) < minBearingSeparation
            }
            if !isDuplicate {
                result.append(b)
            }
        }
        return result
    }

    /// Khoảng cách góc ngắn nhất giữa 2 bearing (0-180).
    private static func angularDistance(_ a: Double, _ b: Double) -> Double {
        var diff = abs(a - b).truncatingRemainder(dividingBy: 360)
        if diff > 180 { diff = 360 - diff }
        return diff
    }
}

// MARK: - Models

/// Một spoke lane: đoạn thẳng từ hub (điểm rẽ) đến endpoint.
struct LaneSpoke {
    let hub: CLLocationCoordinate2D
    let endpoint: CLLocationCoordinate2D

    var coordinates: [CLLocationCoordinate2D] {
        [hub, endpoint]
    }
}

/// Hub (điểm rẽ) với các bearing đã tính.
private struct LaneHub {
    let coordinate: CLLocationCoordinate2D
    let bearings: [Double]
}
