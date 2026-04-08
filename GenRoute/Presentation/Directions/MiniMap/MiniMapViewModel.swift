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
    private var allLaneSpokes: [LaneSpoke] = []

    /// Khoảng cách tối thiểu user phải di chuyển để tính lại lane (throttle).
    private let laneRefreshThresholdMeters: CLLocationDistance = 10
    private var lastLaneRefreshCoordinate: CLLocationCoordinate2D?

    /// Điểm màn hình phần tuyến còn lại (xanh).
    @Published private(set) var remainingScreenPoints: [CGPoint] = []
    /// Điểm màn hình phần tuyến đã đi (trắng).
    @Published private(set) var traveledScreenPoints: [CGPoint] = []
    /// Các spoke lane phụ (mỗi phần tử là mảng 2 CGPoint: [hub, endpoint]).
    @Published private(set) var laneScreenSegments: [[CGPoint]] = []
    /// Đã có dữ liệu để vẽ.
    @Published private(set) var isReady: Bool = false

    init(projection: NavigationPreviewProjecting = EquirectangularProjection()) {
        self.projection = projection
        super.init()
    }

    /// Gọi một lần khi route được tính xong.
    func configure(routeStatic: NavigationRouteStatic, laneSpokes: [LaneSpoke]) {
        self.routeStatic = routeStatic
        self.allLaneSpokes = laneSpokes
        self.lastLaneRefreshCoordinate = nil
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

        // Lane spokes — throttle theo khoảng cách di chuyển
        let needsLaneRefresh: Bool
        if let last = lastLaneRefreshCoordinate {
            needsLaneRefresh = GeodesicDistance.meters(from: last, to: center) >= laneRefreshThresholdMeters
        } else {
            needsLaneRefresh = true
        }

        if needsLaneRefresh {
            lastLaneRefreshCoordinate = center
            let nearbySpokes = MiniMapLaneGenerator.filterNearUser(
                spokes: allLaneSpokes,
                userCoordinate: center,
                radiusMeters: radiusMeters * 2.5
            )
            laneScreenSegments = nearbySpokes.map { spoke in
                let localPoints = spoke.coordinates.map { coord in
                    projection.projectToLocal(point: coord, center: center, bearingDegrees: bearingDegrees)
                }
                return projection.normalizeToScreen(
                    points: localPoints,
                    radiusMeters: radiusMeters,
                    sizePx: diameter
                )
            }
        }

        isReady = remainingScreenPoints.count >= 2 || traveledScreenPoints.count >= 2
    }

    /// Reset khi navigation kết thúc.
    func reset() {
        routeStatic = nil
        allLaneSpokes = []
        lastLaneRefreshCoordinate = nil
        remainingScreenPoints = []
        traveledScreenPoints = []
        laneScreenSegments = []
        isReady = false
    }
}
