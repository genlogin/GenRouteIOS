import Combine
import CoreLocation
import Foundation
import SwiftUI

/// ViewModel quản lý dữ liệu hiển thị cho mini map preview tròn.
/// Nhận route static + vị trí user, tính toán screen points cho View.
@MainActor
final class MiniMapViewModel: BaseViewModel {
    private let projection: NavigationPreviewProjecting
    private var routeStatic: NavigationRouteStatic?

    /// Điểm màn hình phần tuyến còn lại (xanh).
    @Published private(set) var remainingScreenPoints: [CGPoint] = []
    /// Điểm màn hình phần tuyến đã đi (trắng).
    @Published private(set) var traveledScreenPoints: [CGPoint] = []
    /// Đã có dữ liệu để vẽ.
    @Published private(set) var isReady: Bool = false

    init(projection: NavigationPreviewProjecting = EquirectangularProjection()) {
        self.projection = projection
        super.init()
    }

    /// Gọi một lần khi route được tính xong.
    func configure(routeStatic: NavigationRouteStatic) {
        self.routeStatic = routeStatic
    }

    /// Gọi mỗi tick (~20fps) từ DirectionsScreen khi navigation active.
    func update(
        center: CLLocationCoordinate2D,
        bearingDegrees: Double,
        progressMeters: Double,
        radiusMeters: Double = 100,
        diameter: CGFloat = 200
    ) {
        guard let routeStatic else {
            isReady = false
            return
        }

        let userXY = routeStatic.projectUserToXY(center)
        let bearingRad = -bearingDegrees * .pi / 180.0
        let windowM = radiusMeters * 2.2

        let remainingLocal = routeStatic.buildRemainingWindow(
            progressM: progressMeters,
            windowM: windowM,
            userX: userXY.x,
            userY: userXY.y,
            bearingRad: bearingRad
        )

        let traveledLocal = routeStatic.buildTraveledWindow(
            progressM: progressMeters,
            windowM: windowM,
            userX: userXY.x,
            userY: userXY.y,
            bearingRad: bearingRad
        )

        remainingScreenPoints = projection.normalizeToScreen(
            points: remainingLocal,
            radiusMeters: radiusMeters,
            sizePx: diameter
        )

        traveledScreenPoints = projection.normalizeToScreen(
            points: traveledLocal,
            radiusMeters: radiusMeters,
            sizePx: diameter
        )

        isReady = remainingScreenPoints.count >= 2 || traveledScreenPoints.count >= 2
    }

    /// Reset khi navigation kết thúc.
    func reset() {
        routeStatic = nil
        remainingScreenPoints = []
        traveledScreenPoints = []
        isReady = false
    }
}
