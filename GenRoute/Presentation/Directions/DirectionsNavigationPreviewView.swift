import CoreLocation
import SwiftUI

/// Mini-map preview cho dev: vẽ route + lane context lấy từ Valhalla(OSRM format).
/// Vẽ bằng `Path` để tránh xung đột Metal với `Map`.
struct DirectionsNavigationPreviewView: View {
    var routeCoordinates: [CLLocationCoordinate2D]
    var centerCoordinate: CLLocationCoordinate2D
    /// Heading-up: hướng đi trùng **+Y** trong hệ chiếu (độ, 0=Bắc, kim đồng hồ).
    var bearingDegrees: Double
    var lanePolylines: [[CLLocationCoordinate2D]]
    var debugText: String = ""

    var radiusMeters: Double = 45
    var diameter: CGFloat = 250

    private let projection: NavigationPreviewProjecting = EquirectangularProjection()

    var body: some View {
        // UI trục Y tăng xuống dưới; `normalizeToScreen` đã đảo dấu y để +Y local là “đi lên”.
        // Nếu muốn “hướng đi lên trên” theo cảm nhận UI nhưng không đảo trái/phải (mirror),
        // ta quay thêm 180° thay vì lật trục.
        let base = bearingDegrees.isFinite && bearingDegrees >= 0 ? bearingDegrees : 0.0
        let bearing = (base + 180).truncatingRemainder(dividingBy: 360)

        VStack(alignment: .leading, spacing: 8) {
            Text("Dev Navigation Preview (Valhalla context)")
                .font(.caption.weight(.heavy))
                .foregroundStyle(.secondary)
            if !debugText.isEmpty {
                Text(debugText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ZStack {
                Circle().fill(Color.black.opacity(0.92))

                GeometryReader { geo in
                    let rect = geo.frame(in: .local)
                    let size = min(rect.width, rect.height)
                    let center = CGPoint(x: rect.midX, y: rect.midY)

                    // Lane context (xám) — giống Android NavigationPreview.kt
                    let laneGray = Color(red: 0.62, green: 0.62, blue: 0.62)
                    ForEach(Array(lanePolylines.enumerated()), id: \.offset) { _, lane in
                        let local = lane.map { projection.projectToLocal(point: $0, center: centerCoordinate, bearingDegrees: bearing) }
                        let pts = projection.normalizeToScreen(points: local, radiusMeters: radiusMeters, sizePx: size)
                        if pts.count >= 2 {
                            pathFromScreenPoints(pts, in: rect)
                                .stroke(Color.black.opacity(0.45), style: StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
                            pathFromScreenPoints(pts, in: rect)
                                .stroke(laneGray, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        }
                    }

                    // Main route (xanh)
                    let mainLocal = routeCoordinates.map { projection.projectToLocal(point: $0, center: centerCoordinate, bearingDegrees: bearing) }
                    let mainPts = projection.normalizeToScreen(points: mainLocal, radiusMeters: radiusMeters, sizePx: size)
                    if mainPts.count >= 2 {
                        pathFromScreenPoints(mainPts, in: rect)
                            .stroke(Color.black.opacity(0.9), style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                        pathFromScreenPoints(mainPts, in: rect)
                            .stroke(Color(red: 0.16, green: 0.71, blue: 0.96), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    }

                    // User dot
                    ZStack {
                        Circle().fill(Color.black.opacity(0.85)).frame(width: 16, height: 16)
                        Circle().fill(Color.red).frame(width: 10, height: 10)
                    }
                    .position(center)
                }
                .clipShape(Circle())

                Circle().strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
            }
            .frame(width: diameter, height: diameter)
        }
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

