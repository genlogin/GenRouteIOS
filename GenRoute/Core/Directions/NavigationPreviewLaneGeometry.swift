import CoreLocation
import Foundation
import MapKit

/// Port logic Android `MapLibreNavigationActivity.buildLanePolylinesNearUser`:
/// tại mỗi “hub” (ở đây: đầu `MKRoute.Step`), lấy các bearing vào/ra rồi vẽ đoạn thẳng `laneLengthMeters`
/// từ điểm hub (giống `intersections[].location` + `bearings[]` trên MapLibre).
enum NavigationPreviewLaneGeometry {

    static func buildSpokeLanePolylines(
        route: MKRoute,
        userCoordinate: CLLocationCoordinate2D,
        maxIntersections: Int = 10,
        maxBearingsPerIntersection: Int = 3,
        laneLengthMeters: Double = 25
    ) -> [[CLLocationCoordinate2D]] {
        let steps = route.steps
        guard !steps.isEmpty else { return [] }

        var hubs: [(coord: CLLocationCoordinate2D, bearings: [CLLocationDirection])] = []
        hubs.reserveCapacity(steps.count)

        for i in steps.indices {
            let coords = steps[i].polyline.routeCoordinates
            guard coords.count >= 2 else { continue }
            let c = coords[0]
            var bearings: [CLLocationDirection] = []
            bearings.append(bearingClockwiseFromNorth(from: c, to: coords[1]))

            if i > 0 {
                let prevCoords = steps[i - 1].polyline.routeCoordinates
                guard let lastPrev = prevCoords.last else { continue }
                let d = CLLocation(latitude: lastPrev.latitude, longitude: lastPrev.longitude)
                    .distance(from: CLLocation(latitude: c.latitude, longitude: c.longitude))
                if d > 0.5 {
                    bearings.append(bearingClockwiseFromNorth(from: lastPrev, to: c))
                }
            }

            let merged = mergeDistinctBearings(
                bearings,
                minSeparationDegrees: 12,
                maxCount: maxBearingsPerIntersection
            )
            guard !merged.isEmpty else { continue }
            hubs.append((c, merged))
        }

        let sorted = hubs.sorted { a, b in
            squaredDistance(from: userCoordinate, to: a.coord) < squaredDistance(from: userCoordinate, to: b.coord)
        }

        var picked: [(coord: CLLocationCoordinate2D, bearings: [CLLocationDirection])] = []
        picked.reserveCapacity(maxIntersections)
        let minHubSeparationMeters: CLLocationDistance = 18
        for h in sorted {
            guard picked.count < maxIntersections else { break }
            let locH = CLLocation(latitude: h.coord.latitude, longitude: h.coord.longitude)
            let tooClose = picked.contains { p in
                locH.distance(from: CLLocation(latitude: p.coord.latitude, longitude: p.coord.longitude)) < minHubSeparationMeters
            }
            if tooClose { continue }
            picked.append((h.coord, h.bearings))
        }

        var lines: [[CLLocationCoordinate2D]] = []
        lines.reserveCapacity(picked.count * maxBearingsPerIntersection)
        for h in picked {
            for b in h.bearings {
                let end = destinationPoint(start: h.coord, bearingDegrees: b, distanceMeters: laneLengthMeters)
                lines.append([h.coord, end])
            }
        }
        return lines
    }

    // MARK: - Private

    private static func squaredDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let dx = from.latitude - to.latitude
        let dy = from.longitude - to.longitude
        return dx * dx + dy * dy
    }

    /// Giống `destinationPoint` Kotlin (định vị đích theo bearing + khoảng cách lớn).
    private static func destinationPoint(
        start: CLLocationCoordinate2D,
        bearingDegrees: Double,
        distanceMeters: Double
    ) -> CLLocationCoordinate2D {
        let r = 6_371_000.0
        let brng = bearingDegrees * (.pi / 180)
        let lat1 = start.latitude * (.pi / 180)
        let lon1 = start.longitude * (.pi / 180)
        let lat2 = asin(sin(lat1) * cos(distanceMeters / r) + cos(lat1) * sin(distanceMeters / r) * cos(brng))
        let lon2 = lon1 + atan2(
            sin(brng) * sin(distanceMeters / r) * cos(lat1),
            cos(distanceMeters / r) - sin(lat1) * sin(lat2)
        )
        return CLLocationCoordinate2D(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
    }

    private static func bearingClockwiseFromNorth(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDirection {
        let lat1 = from.latitude * (.pi / 180)
        let lon1 = from.longitude * (.pi / 180)
        let lat2 = to.latitude * (.pi / 180)
        let lon2 = to.longitude * (.pi / 180)
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        var deg = atan2(y, x) * 180 / .pi
        if deg < 0 { deg += 360 }
        return deg
    }

    private static func mergeDistinctBearings(
        _ raw: [CLLocationDirection],
        minSeparationDegrees: Double,
        maxCount: Int
    ) -> [CLLocationDirection] {
        var out: [CLLocationDirection] = []
        for b in raw where b.isFinite {
            let n = normalize360(b)
            if !out.contains(where: { angularDistanceDegrees($0, n) < minSeparationDegrees }) {
                out.append(n)
            }
        }
        return Array(out.prefix(maxCount))
    }

    private static func normalize360(_ d: Double) -> Double {
        var x = d.truncatingRemainder(dividingBy: 360)
        if x < 0 { x += 360 }
        return x
    }

    private static func angularDistanceDegrees(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b)
        return min(d, 360 - d)
    }
}
