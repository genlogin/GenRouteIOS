import CoreLocation
import Foundation

/// Ảnh chụp thống kê một lần hoàn thành / dừng chuyến, truyền sang màn kết quả.
/// `Hashable` + `Codable`: `NavigationStack(path:)` cần encode/decode ổn định; `Double` chuẩn hóa tránh NaN làm `==`/`hash` không nhất quán.
struct TripResultSummary: Sendable, Codable {
    var recordName: String
    var completedAt: Date
    /// Khoảng cách xuất phát → đích: theo `MKRoute` nếu có, không thì geodesic (m).
    var startToDestinationMeters: CLLocationDistance
    /// Quãng đường đã đi theo thực tế / mô phỏng trên tuyến, mét.
    var distanceTraveledMeters: CLLocationDistance
    /// Thời gian từ bắt đầu điều hướng đến kết thúc (giây).
    var movingDurationSeconds: TimeInterval
    /// Thời gian trôi qua (hiện = `movingDurationSeconds`; sau này có thể tách nếu có tạm dừng).
    var elapsedDurationSeconds: TimeInterval
    /// Trung bình (km/h), từ `distanceTraveledMeters` / `movingDurationSeconds`.
    var averageSpeedKmh: Double
    /// Cao nhất quan sát được (km/h).
    var maxSpeedKmh: Double
    var completionReason: TripCompletionReason

    /// Tọa độ để vẽ bản đồ nền (điểm đầu / đích).
    var mapStartLatitude: Double
    var mapStartLongitude: Double
    var mapEndLatitude: Double
    var mapEndLongitude: Double
    var startPlaceName: String
    var endPlaceName: String
}

extension TripResultSummary: Hashable {
    static func == (lhs: TripResultSummary, rhs: TripResultSummary) -> Bool {
        lhs.recordName == rhs.recordName
            && lhs.completedAt == rhs.completedAt
            && Self.eq(lhs.startToDestinationMeters, rhs.startToDestinationMeters)
            && Self.eq(lhs.distanceTraveledMeters, rhs.distanceTraveledMeters)
            && Self.eq(lhs.movingDurationSeconds, rhs.movingDurationSeconds)
            && Self.eq(lhs.elapsedDurationSeconds, rhs.elapsedDurationSeconds)
            && Self.eq(lhs.averageSpeedKmh, rhs.averageSpeedKmh)
            && Self.eq(lhs.maxSpeedKmh, rhs.maxSpeedKmh)
            && lhs.completionReason == rhs.completionReason
            && Self.eq(lhs.mapStartLatitude, rhs.mapStartLatitude)
            && Self.eq(lhs.mapStartLongitude, rhs.mapStartLongitude)
            && Self.eq(lhs.mapEndLatitude, rhs.mapEndLatitude)
            && Self.eq(lhs.mapEndLongitude, rhs.mapEndLongitude)
            && lhs.startPlaceName == rhs.startPlaceName
            && lhs.endPlaceName == rhs.endPlaceName
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(recordName)
        hasher.combine(completedAt)
        hasher.combine(Self.norm(startToDestinationMeters))
        hasher.combine(Self.norm(distanceTraveledMeters))
        hasher.combine(Self.norm(movingDurationSeconds))
        hasher.combine(Self.norm(elapsedDurationSeconds))
        hasher.combine(Self.norm(averageSpeedKmh))
        hasher.combine(Self.norm(maxSpeedKmh))
        hasher.combine(completionReason)
        hasher.combine(Self.norm(mapStartLatitude))
        hasher.combine(Self.norm(mapStartLongitude))
        hasher.combine(Self.norm(mapEndLatitude))
        hasher.combine(Self.norm(mapEndLongitude))
        hasher.combine(startPlaceName)
        hasher.combine(endPlaceName)
    }

    private static func norm(_ d: Double) -> Double {
        if d.isNaN || d.isInfinite { return 0 }
        return d
    }

    private static func eq(_ a: Double, _ b: Double) -> Bool {
        norm(a) == norm(b)
    }
}
