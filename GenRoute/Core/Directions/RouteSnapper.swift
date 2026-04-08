import CoreLocation
import Foundation

/// Snap một điểm vào polyline gần nhất (xấp xỉ equirectangular theo lat/lon) để preview UI khớp tuyến.
enum RouteSnapper {
    static func snapToPolyline(
        point: CLLocationCoordinate2D,
        polyline: [CLLocationCoordinate2D]
    ) -> CLLocationCoordinate2D? {
        guard polyline.count >= 2 else { return polyline.first }

        var best: (coord: CLLocationCoordinate2D, d2: Double)? = nil
        for i in 0..<(polyline.count - 1) {
            let a = polyline[i]
            let b = polyline[i + 1]
            let p = project(point, ontoSegmentFrom: a, to: b, refLat: point.latitude)
            let d2 = squaredDistance(point, p, refLat: point.latitude)
            if best == nil || d2 < best!.d2 {
                best = (p, d2)
            }
        }
        return best?.coord
    }

    private static func project(
        _ p: CLLocationCoordinate2D,
        ontoSegmentFrom a: CLLocationCoordinate2D,
        to b: CLLocationCoordinate2D,
        refLat: CLLocationDegrees
    ) -> CLLocationCoordinate2D {
        // local meters-ish in degrees space with lon scale
        let k = cos(refLat * .pi / 180)
        let ax = a.longitude * k
        let ay = a.latitude
        let bx = b.longitude * k
        let by = b.latitude
        let px = p.longitude * k
        let py = p.latitude

        let vx = bx - ax
        let vy = by - ay
        let wx = px - ax
        let wy = py - ay
        let c2 = vx * vx + vy * vy
        let t = c2 > 1e-18 ? max(0, min(1, (vx * wx + vy * wy) / c2)) : 0
        let projX = ax + t * vx
        let projY = ay + t * vy
        return CLLocationCoordinate2D(latitude: projY, longitude: projX / k)
    }

    private static func squaredDistance(
        _ a: CLLocationCoordinate2D,
        _ b: CLLocationCoordinate2D,
        refLat: CLLocationDegrees
    ) -> Double {
        let k = cos(refLat * .pi / 180)
        let dx = (a.longitude - b.longitude) * k
        let dy = (a.latitude - b.latitude)
        return dx * dx + dy * dy
    }
}

