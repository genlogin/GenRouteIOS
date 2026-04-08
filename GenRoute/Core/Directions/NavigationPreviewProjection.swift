import CoreLocation
import Foundation

/// Phép chiếu toạ độ địa lý sang toạ độ màn hình cho mini map preview.
protocol NavigationPreviewProjecting {
    /// Chuyển một điểm địa lý sang hệ toạ độ cục bộ (mét) so với tâm, có xoay theo heading nếu cần.
    func projectToLocal(
        point: CLLocationCoordinate2D,
        center: CLLocationCoordinate2D,
        bearingDegrees: Double?
    ) -> (x: Double, y: Double)

    /// Chuyển mảng toạ độ cục bộ (mét) sang điểm màn hình (pixel).
    func normalizeToScreen(
        points: [(x: Double, y: Double)],
        radiusMeters: Double,
        sizePx: CGFloat
    ) -> [CGPoint]
}

/// Phép chiếu Equirectangular dùng bán kính Trái Đất 6,371,000 m.
struct EquirectangularProjection: NavigationPreviewProjecting {
    private static let earthRadius: Double = 6_371_000.0

    func projectToLocal(
        point: CLLocationCoordinate2D,
        center: CLLocationCoordinate2D,
        bearingDegrees: Double?
    ) -> (x: Double, y: Double) {
        let r = Self.earthRadius
        let dLat = (point.latitude - center.latitude) * .pi / 180.0
        let dLon = (point.longitude - center.longitude) * .pi / 180.0
        let centerLatRad = center.latitude * .pi / 180.0

        let x = dLon * cos(centerLatRad) * r
        let y = dLat * r

        guard let bearing = bearingDegrees else {
            return (x, y)
        }

        let theta = -bearing * .pi / 180.0
        let cosT = cos(theta)
        let sinT = sin(theta)
        let rx = x * cosT + y * sinT
        let ry = -x * sinT + y * cosT
        return (rx, ry)
    }

    func normalizeToScreen(
        points: [(x: Double, y: Double)],
        radiusMeters: Double,
        sizePx: CGFloat
    ) -> [CGPoint] {
        let size = Double(sizePx)
        let scale = size / (radiusMeters * 2)
        return points.map { (x, y) in
            CGPoint(
                x: x * scale + size / 2,
                y: size / 2 - y * scale
            )
        }
    }
}
