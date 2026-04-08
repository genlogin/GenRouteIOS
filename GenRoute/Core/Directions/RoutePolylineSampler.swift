import CoreLocation
import MapKit

/// Nội suy điểm trên polyline theo quãng đường tích luỹ (mét).
struct RoutePolylineSampler {
    private let points: [CLLocationCoordinate2D]
    private let segmentLengths: [CLLocationDistance]
    let totalLength: CLLocationDistance

    init(polyline: MKPolyline) {
        let coords = polyline.routeCoordinates
        points = coords
        guard coords.count >= 2 else {
            segmentLengths = []
            totalLength = 0
            return
        }
        var lengths: [CLLocationDistance] = []
        var total: CLLocationDistance = 0
        for i in 0..<(coords.count - 1) {
            let a = CLLocation(latitude: coords[i].latitude, longitude: coords[i].longitude)
            let b = CLLocation(latitude: coords[i + 1].latitude, longitude: coords[i + 1].longitude)
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

    /// Góc (0° = Bắc, theo chiều kim đồng hồ) tiếp tuyến tuyến đường tại khoảng `along` mét — dùng cho mini-map heading-up khi chưa có `course` GPS.
    func courseDegreesClockwiseFromNorth(atDistance along: CLLocationDistance) -> CLLocationDirection {
        guard points.count >= 2, totalLength > 0 else { return 0 }
        let clamped = min(max(0, along), totalLength)
        let eps: CLLocationDistance = min(6, max(2, totalLength * 0.004))
        let behind = max(0, clamped - eps)
        let ahead = min(totalLength, clamped + eps)
        let from = coordinate(atDistance: behind)
        let to = coordinate(atDistance: ahead)
        return Self.bearingClockwiseFromNorth(from: from, to: to)
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
