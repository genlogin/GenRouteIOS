import CoreLocation
import Foundation

/// Nội suy tuyến tính giữa 2 keyframe để UI/Bluetooth mượt, không “đoán route” mới.
final class NavigationKeyframeSmoother: @unchecked Sendable {
    private var previous: NavigationKeyframe?
    private var next: NavigationKeyframe?

    func reset() {
        previous = nil
        next = nil
    }

    /// Push keyframe mới (thường ~1s/lần với GPS/simulator keyframe).
    func push(_ keyframe: NavigationKeyframe) {
        if previous == nil {
            previous = keyframe
            next = nil
            return
        }
        if next == nil {
            next = keyframe
            return
        }
        previous = next
        next = keyframe
    }

    /// Lấy mẫu trạng thái mượt tại `timestamp` (epoch seconds).
    func sample(at timestamp: TimeInterval) -> NavigationKeyframe? {
        guard let a = previous else { return nil }
        guard let b = next else { return a }
        let dt = b.timestamp - a.timestamp
        if dt <= 0.0001 {
            return b
        }
        let t = max(0, min(1, (timestamp - a.timestamp) / dt))
        return NavigationKeyframe(
            coordinate: Self.mixCoordinate(a.coordinate, b.coordinate, t: t),
            headingDegrees: Self.mixHeadingDegrees(a.headingDegrees, b.headingDegrees, t: t),
            traveledMeters: a.traveledMeters + (b.traveledMeters - a.traveledMeters) * t,
            timestamp: timestamp
        )
    }

    private static func mixCoordinate(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D, t: Double) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: a.latitude + (b.latitude - a.latitude) * t,
            longitude: a.longitude + (b.longitude - a.longitude) * t
        )
    }

    /// Interp góc theo đường ngắn nhất (wrap 360).
    private static func mixHeadingDegrees(_ a: CLLocationDirection?, _ b: CLLocationDirection?, t: Double) -> CLLocationDirection? {
        guard let a, a.isFinite, a >= 0 else { return b }
        guard let b, b.isFinite, b >= 0 else { return a }
        let aa = a.truncatingRemainder(dividingBy: 360)
        let bb = b.truncatingRemainder(dividingBy: 360)
        var delta = bb - aa
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        var out = aa + delta * t
        if out < 0 { out += 360 }
        if out >= 360 { out -= 360 }
        return out
    }
}

