import CoreLocation
import SwiftUI

/// Mini-map tròn ~250pt: port logic Android `NavigationPreview.kt` (RouteStatic + cửa sổ traveled/remaining).
/// Vẽ bằng `Path` (không dùng `Canvas`) để tránh xung đột Metal với `Map`.
struct DirectionsNavigationPreviewView: View {
    var routeCoordinates: [CLLocationCoordinate2D]
    var centerCoordinate: CLLocationCoordinate2D
    /// Cùng quy ước MapKit (0° = Bắc, kim đồng hồ). Luôn dùng course / tiếp tuyến tuyến để hướng tiến **lên trục +Y** (lên màn hình) sau `normalizeToScreen`.
    var bearingDegrees: CLLocationDirection
    var progressMeters: Double
    var radiusMeters: Double = 45
    /// Lane phụ: mỗi phần tử thường là đoạn 2 điểm (hub → đích theo bearing), giống Android MapLibre + `NavigationPreview` lanes.
    var lanePolylines: [[CLLocationCoordinate2D]] = []
    var diameter: CGFloat = 250

    var body: some View {
        let routeStatic = NavigationRouteStatic(coordinates: routeCoordinates)
        let bearingRad: Double? = bearingDegrees.isFinite && bearingDegrees >= 0
            ? (-bearingDegrees) * .pi / 180
            : nil

        VStack(alignment: .leading, spacing: 8) {
            Text("Dev Navigation Preview")
                .font(.caption.weight(.heavy))
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.92))

                GeometryReader { geo in
                    let rect = geo.frame(in: .local)
                    let size = min(rect.width, rect.height)
                    let center = CGPoint(x: rect.midX, y: rect.midY)

                    if let rs = routeStatic {
                        let userXY = rs.projectUserToXY(latitude: centerCoordinate.latitude, longitude: centerCoordinate.longitude)
                        let windowM = radiusMeters * 2.2
                        let p = min(max(0, progressMeters), rs.cumMeters.last ?? 0)

                        let traveledLocal = rs.buildTraveledLocalWindow(
                            progressM: p,
                            windowM: windowM,
                            userX: userXY.x,
                            userY: userXY.y,
                            bearingRad: bearingRad
                        )
                        let remainingLocal = rs.buildRemainingLocalWindow(
                            progressM: p,
                            windowM: windowM,
                            userX: userXY.x,
                            userY: userXY.y,
                            bearingRad: bearingRad
                        )

                        let traveledPts = NavigationPreviewProjection.normalizeToScreen(
                            points: traveledLocal,
                            radiusMeters: radiusMeters,
                            size: size
                        )
                        let mainPts = NavigationPreviewProjection.normalizeToScreen(
                            points: remainingLocal,
                            radiusMeters: radiusMeters,
                            size: size
                        )

                        // Lane phụ (context) — vẽ trước, palette `NavigationPreview.kt` (`laneContextGray` + viền đen mờ).
                        let laneContextGray = Color(red: 0.62, green: 0.62, blue: 0.62)
                        ForEach(Array(lanePolylines.enumerated()), id: \.offset) { _, lane in
                            let locals = lane.map {
                                NavigationPreviewProjection.projectToLocal(
                                    point: $0,
                                    center: centerCoordinate,
                                    bearingDegrees: bearingDegrees
                                )
                            }
                            let lanePts = NavigationPreviewProjection.normalizeToScreen(
                                points: locals,
                                radiusMeters: radiusMeters,
                                size: size
                            )
                            if lanePts.count >= 2 {
                                pathFromScreenPoints(lanePts, in: rect)
                                    .stroke(Color.black.opacity(0.45), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                                pathFromScreenPoints(lanePts, in: rect)
                                    .stroke(laneContextGray, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                            }
                        }

                        if mainPts.count >= 2 {
                            pathFromScreenPoints(mainPts, in: rect)
                                .stroke(Color.black.opacity(0.9), style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                            pathFromScreenPoints(mainPts, in: rect)
                                .stroke(Color(red: 0.16, green: 0.71, blue: 0.96), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        }

                        if traveledPts.count >= 2 {
                            pathFromScreenPoints(traveledPts, in: rect)
                                .stroke(Color.black.opacity(0.9), style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                            pathFromScreenPoints(traveledPts, in: rect)
                                .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        }
                    }

                    // User dot (đỏ) — tâm
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.85))
                            .frame(width: 16, height: 16)
                        Circle()
                            .fill(Color.red)
                            .frame(width: 10, height: 10)
                    }
                    .position(center)
                }
                .clipShape(Circle())

                Circle()
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
            }
            .frame(width: diameter, height: diameter)
        }
        .animation(.easeOut(duration: 0.22), value: progressMeters)
        .animation(.easeOut(duration: 0.22), value: bearingDegrees)
    }

    private func pathFromScreenPoints(_ pts: [CGPoint], in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let baseX = rect.midX - side / 2
        let baseY = rect.midY - side / 2
        return Path { p in
            guard let first = pts.first else { return }
            p.move(to: CGPoint(x: baseX + first.x, y: baseY + first.y))
            for pt in pts.dropFirst() {
                p.addLine(to: CGPoint(x: baseX + pt.x, y: baseY + pt.y))
            }
        }
    }
}
