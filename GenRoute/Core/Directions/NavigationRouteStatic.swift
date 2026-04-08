import CoreLocation
import Foundation

/// Dữ liệu tuyến đường đã chuyển sang hệ toạ độ phẳng (mét) — tính toán một lần khi nhận route.
/// Port từ Android `RouteStatic` + `buildRouteStatic`.
struct NavigationRouteStatic {
    let originLat: Double
    let originLng: Double
    private let originLatRad: Double
    /// Mảng phẳng [x0, y0, x1, y1, ...] (mét) so với gốc route.
    private let xyMeters: [Double]
    /// Khoảng cách tích luỹ (mét) tại mỗi đỉnh; `cumMeters[0] = 0`.
    private let cumMeters: [Double]
    /// Số đỉnh.
    let pointCount: Int

    private static let earthRadius: Double = 6_371_000.0

    // MARK: - Init

    /// Trả về `nil` nếu tuyến ít hơn 2 điểm.
    init?(coordinates: [CLLocationCoordinate2D]) {
        guard coordinates.count >= 2 else { return nil }
        let origin = coordinates[0]
        self.originLat = origin.latitude
        self.originLng = origin.longitude
        self.originLatRad = origin.latitude * .pi / 180.0
        self.pointCount = coordinates.count

        let r = Self.earthRadius
        var xy = [Double](repeating: 0, count: coordinates.count * 2)
        for i in coordinates.indices {
            let p = coordinates[i]
            let dLat = (p.latitude - originLat) * .pi / 180.0
            let dLon = (p.longitude - originLng) * .pi / 180.0
            xy[i * 2] = dLon * cos(originLatRad) * r
            xy[i * 2 + 1] = dLat * r
        }

        var cum = [Double](repeating: 0, count: coordinates.count)
        var acc: Double = 0
        for i in 1..<coordinates.count {
            let ax = xy[(i - 1) * 2]
            let ay = xy[(i - 1) * 2 + 1]
            let bx = xy[i * 2]
            let by = xy[i * 2 + 1]
            acc += hypot(bx - ax, by - ay)
            cum[i] = acc
        }

        self.xyMeters = xy
        self.cumMeters = cum
    }

    /// Tổng chiều dài tuyến (mét).
    var totalLength: Double {
        cumMeters.last ?? 0
    }

    // MARK: - Project user

    /// Chuyển vị trí user (geo) sang XY (mét) so với gốc route.
    func projectUserToXY(_ coordinate: CLLocationCoordinate2D) -> (x: Double, y: Double) {
        let r = Self.earthRadius
        let dLat = (coordinate.latitude - originLat) * .pi / 180.0
        let dLon = (coordinate.longitude - originLng) * .pi / 180.0
        let x = dLon * cos(originLatRad) * r
        let y = dLat * r
        return (x, y)
    }

    // MARK: - Windowed segments

    /// Phần tuyến user đã đi (từ `max(0, progress - window)` đến `progress`), đã transform về user-relative.
    func buildTraveledWindow(
        progressM: Double,
        windowM: Double,
        userX: Double,
        userY: Double,
        bearingRad: Double?
    ) -> [(x: Double, y: Double)] {
        let p = progressM.clamped(to: 0...totalLength)
        let startM = max(0, p - windowM)
        return buildWindow(startM: startM, endM: p, userX: userX, userY: userY, bearingRad: bearingRad)
    }

    /// Phần tuyến còn lại (từ `progress` đến `min(total, progress + window)`), đã transform về user-relative.
    func buildRemainingWindow(
        progressM: Double,
        windowM: Double,
        userX: Double,
        userY: Double,
        bearingRad: Double?
    ) -> [(x: Double, y: Double)] {
        let p = progressM.clamped(to: 0...totalLength)
        let endM = min(totalLength, p + windowM)
        return buildWindow(startM: p, endM: endM, userX: userX, userY: userY, bearingRad: bearingRad)
    }

    // MARK: - Private

    private func buildWindow(
        startM: Double,
        endM: Double,
        userX: Double,
        userY: Double,
        bearingRad: Double?
    ) -> [(x: Double, y: Double)] {
        guard pointCount >= 2, endM > startM else { return [] }

        let i0 = findIndexForDistance(startM).clamped(to: 0...(pointCount - 2))
        let i1 = findIndexForDistance(endM).clamped(to: 0...(pointCount - 2))

        var out = [(x: Double, y: Double)]()
        out.reserveCapacity(max(2, i1 - i0 + 3))

        out.append(transformXY(interpPointAt(distM: startM, idx: i0), userX: userX, userY: userY, bearingRad: bearingRad))

        for i in (i0 + 1)...i1 {
            let x = xyMeters[i * 2]
            let y = xyMeters[i * 2 + 1]
            out.append(transformXY((x, y), userX: userX, userY: userY, bearingRad: bearingRad))
        }

        out.append(transformXY(interpPointAt(distM: endM, idx: i1), userX: userX, userY: userY, bearingRad: bearingRad))

        return out
    }

    private func interpPointAt(distM: Double, idx: Int) -> (Double, Double) {
        let i = idx.clamped(to: 0...(pointCount - 2))
        let aLen = cumMeters[i]
        let bLen = cumMeters[i + 1]
        let seg = max(bLen - aLen, 1e-9)
        let t = ((distM - aLen) / seg).clamped(to: 0...1)
        let ax = xyMeters[i * 2]
        let ay = xyMeters[i * 2 + 1]
        let bx = xyMeters[(i + 1) * 2]
        let by = xyMeters[(i + 1) * 2 + 1]
        return (ax + (bx - ax) * t, ay + (by - ay) * t)
    }

    private func transformXY(
        _ p: (Double, Double),
        userX: Double,
        userY: Double,
        bearingRad: Double?
    ) -> (x: Double, y: Double) {
        let dx = p.0 - userX
        let dy = p.1 - userY
        guard let br = bearingRad else {
            return (dx, dy)
        }
        let cosT = cos(br)
        let sinT = sin(br)
        let rx = dx * cosT + dy * sinT
        let ry = -dx * sinT + dy * cosT
        return (rx, ry)
    }

    /// Binary search: tìm index sao cho `cumMeters[i] <= d <= cumMeters[i+1]`.
    private func findIndexForDistance(_ d: Double) -> Int {
        var lo = 0
        var hi = pointCount - 1
        while lo + 1 < hi {
            let mid = (lo + hi) / 2
            if cumMeters[mid] <= d {
                lo = mid
            } else {
                hi = mid
            }
        }
        return lo
    }
}

// MARK: - Comparable clamped

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}