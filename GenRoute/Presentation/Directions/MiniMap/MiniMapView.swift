import SwiftUI

/// Mini map tròn hiển thị preview tuyến đường khi đang chỉ đường.
/// Dùng Path thay vì Canvas để tránh xung đột Metal với Map view.
struct MiniMapView: View {
    @ObservedObject var viewModel: MiniMapViewModel
    var diameter: CGFloat = 200

    /// Màu xanh nước biển cho tuyến chính — Android 0xFF29B6F6.
    private let routeBlue = Color(red: 0.16, green: 0.71, blue: 0.96)
    /// Màu xám cho lane phụ — Android 0xFF9E9E9E.
    private let laneGray = Color(white: 0.62)

    var body: some View {
        ZStack {
            // Nền đen
            Circle()
                .fill(Color.black)

            if viewModel.isReady {
                // Lane phụ (xám) — vẽ trước, nằm dưới cùng
                ForEach(viewModel.laneScreenSegments.indices, id: \.self) { idx in
                    routePath(
                        points: viewModel.laneScreenSegments[idx],
                        strokeColor: laneGray,
                        outlineWidth: 7,
                        strokeWidth: 2
                    )
                }

                // Tuyến còn lại (xanh) — vẽ outline đen rồi đè stroke xanh
                routePath(points: viewModel.remainingScreenPoints, strokeColor: routeBlue, outlineWidth: 12, strokeWidth: 4)

                // Tuyến đã đi (trắng) — vẽ đè lên trên
                routePath(points: viewModel.traveledScreenPoints, strokeColor: .white, outlineWidth: 12, strokeWidth: 4)
            }

            // User dot — luôn ở tâm
            userDot()

            // Viền mờ
            Circle()
                .strokeBorder(Color.white.opacity(0.25), lineWidth: 1.5)
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 4)
        .accessibilityLabel(Text(AppString.directionsMinimapA11y))
        .accessibilityAddTraits(.isImage)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func routePath(points: [CGPoint], strokeColor: Color, outlineWidth: CGFloat, strokeWidth: CGFloat) -> some View {
        if points.count >= 2 {
            let path = buildPath(from: points)

            // Outline đen
            path
                .stroke(
                    Color.black.opacity(0.9),
                    style: StrokeStyle(lineWidth: outlineWidth, lineCap: .round, lineJoin: .round)
                )

            // Stroke chính
            path
                .stroke(
                    strokeColor,
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
                )
        }
    }

    private func userDot() -> some View {
        let center = diameter / 2
        return ZStack {
            Circle()
                .fill(Color.black.opacity(0.85))
                .frame(width: 16, height: 16)
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
        }
        .position(x: center, y: center)
    }

    private func buildPath(from points: [CGPoint]) -> Path {
        Path { path in
            for (i, point) in points.enumerated() {
                if i == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
        }
    }
}
