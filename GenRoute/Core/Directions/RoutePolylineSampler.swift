import CoreLocation
import MapKit

/// Nội suy điểm trên polyline theo quãng đường tích luỹ (mét).
struct RoutePolylineSampler {
    private let points: [CLLocationCoordinate2D]
    private let segmentLengths: [CLLocationDistance]
    let totalLength: CLLocationDistance

    init(polyline: MKPolyline) {
        self.init(coordinates: polyline.routeCoordinates)
    }

    init(coordinates: [CLLocationCoordinate2D]) {
        points = coordinates
        guard coordinates.count >= 2 else {
            segmentLengths = []
            totalLength = 0
            return
        }
        var lengths: [CLLocationDistance] = []
        var total: CLLocationDistance = 0
        for i in 0..<(coordinates.count - 1) {
            let a = CLLocation(latitude: coordinates[i].latitude, longitude: coordinates[i].longitude)
            let b = CLLocation(latitude: coordinates[i + 1].latitude, longitude: coordinates[i + 1].longitude)
            let d = a.distance(from: b)
            lengths.append(d)
            total += d
        }
        segmentLengths = lengths
        totalLength = total
    }

    func coordinate(atDistance target: CLLocationDistance) -> CLLocationCoordinate2D {
        guard points.count >= 2, totalLength > 0 else {
            return points.first ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
        }
        let clamped = min(max(0, target), totalLength)
        var acc: CLLocationDistance = 0
        for i in 0..<segmentLengths.count {
            let len = segmentLengths[i]
            if acc + len >= clamped {
                let t = len > 0 ? (clamped - acc) / len : 0
                return Self.mix(points[i], points[i + 1], t: t)
            }
            acc += len
        }
        return points.last!
    }

    private static func mix(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D, t: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: a.latitude + (b.latitude - a.latitude) * t,
            longitude: a.longitude + (b.longitude - a.longitude) * t
        )
    }

    /// Quãng đường dọc tuyến từ đầu polyline đến điểm chiếu vuông góc gần `coordinate` nhất (GPS thật).
    func distanceAlongRoute(closestTo coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        guard points.count >= 2, !segmentLengths.isEmpty else { return 0 }
        var cumulative: CLLocationDistance = 0
        var bestAlong: CLLocationDistance = 0
        var bestPerp = CLLocationDistance.greatestFiniteMagnitude

        for i in 0..<segmentLengths.count {
            let len = segmentLengths[i]
            let a = points[i]
            let b = points[i + 1]
            let (alongSeg, perp) = Self.closestPointOnSegment(p: coordinate, a: a, b: b, segmentMeters: len)
            if perp < bestPerp {
                bestPerp = perp
                bestAlong = cumulative + alongSeg
            }
            cumulative += len
        }
        return min(max(0, bestAlong), totalLength)
    }

    private static func closestPointOnSegment(
        p: CLLocationCoordinate2D,
        a: CLLocationCoordinate2D,
        b: CLLocationCoordinate2D,
        segmentMeters: CLLocationDistance
    ) -> (along: CLLocationDistance, perpendicular: CLLocationDistance) {
        let cp = CLLocation(latitude: p.latitude, longitude: p.longitude)
        let da = a.latitude, db = b.latitude
        let la = a.longitude, lb = b.longitude
        let abLat = p.latitude - da
        let abLon = p.longitude - la
        let segLat = db - da
        let segLon = lb - la
        let segLenSq = segLat * segLat + segLon * segLon
        let t = segLenSq > 1e-14 ? max(0, min(1, (abLat * segLat + abLon * segLon) / segLenSq)) : 0
        let projLat = da + t * segLat
        let projLon = la + t * segLon
        let proj = CLLocation(latitude: projLat, longitude: projLon)
        return (t * segmentMeters, cp.distance(from: proj))
    }
}
