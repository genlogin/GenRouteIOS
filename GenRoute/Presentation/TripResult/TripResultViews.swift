import MapKit
import SwiftUI

// MARK: - Map (tách khỏi `TripResultScreen` — View thuần, không logic nghiệp vụ)

struct TripResultMapLayer: View {
    @Binding var cameraPosition: MapCameraPosition
    let summary: TripResultSummary

    var body: some View {
        let start = TripResultMapGeometry.startCoordinate(from: summary)
        let end = TripResultMapGeometry.endCoordinate(from: summary)

        Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
            MapPolyline(coordinates: [start, end])
                .stroke(Color.accentColor.opacity(0.9), lineWidth: 5)

            Annotation(summary.startPlaceName.isEmpty ? String(localized: "trip_result_map_start") : summary.startPlaceName, coordinate: start) {
                Image(systemName: "flag.checkered")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(8)
                    .background {
                        Circle().fill(Color.green)
                    }
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
            }

            Annotation(summary.endPlaceName.isEmpty ? String(localized: "trip_result_map_end") : summary.endPlaceName, coordinate: end) {
                Image(systemName: "flag.checkered")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.primary)
                    .padding(6)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .mapStyle(mapStyleForCurrentOS)
        .ignoresSafeArea(edges: [.top, .horizontal, .bottom])
    }

    private var mapStyleForCurrentOS: MapStyle {
        if #available(iOS 18, *) {
            return .standard(elevation: .realistic)
        }
        return .standard
    }
}

// MARK: - Bottom chrome (glass iOS 26+ / material cũ hơn)

struct TripResultBottomChrome: View {
    @ObservedObject var viewModel: TripResultViewModel
    @Binding var selectedRatingIndex: Int?

    private let ratingEmojis = ["😠", "😕", "😐", "🙂", "😄"]
    let bottomSafeInset: CGFloat

    var body: some View {
        Group {
            if #available(iOS 26, *) {
                bottomLiquidGlassChrome
            } else {
                bottomMaterialChrome
            }
        }
    }

    @available(iOS 26, *)
    private var bottomLiquidGlassChrome: some View {
        GlassEffectContainer(spacing: 14) {
            VStack(spacing: 10) {
                rateRouteContent
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                statsPanelContent
                    .glassEffect(
                        .regular,
                        in: UnevenRoundedRectangle(
                            cornerRadii: RectangleCornerRadii(
                                topLeading: 24,
                                bottomLeading: 24,
                                bottomTrailing: 24,
                                topTrailing: 24
                            )
                        )
                    )
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .padding(.horizontal, 12)
    }

    private var bottomMaterialChrome: some View {
        VStack(spacing: 10) {
            rateRouteContent
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
                }

            statsPanelContent
                .background {
                    UnevenRoundedRectangle(
                        cornerRadii: RectangleCornerRadii(
                            topLeading: 24,
                            bottomLeading: 24,
                            bottomTrailing: 24,
                            topTrailing: 24
                        )
                    )
                    .fill(.thickMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 16, y: -4)
                }
                .ignoresSafeArea(edges: .bottom)
        }
        .padding(.horizontal, 12)
    }

    private var rateRouteContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(AppString.tripResultRateRoutePrompt)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Image(systemName: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .symbolRenderingMode(.hierarchical)
            }

            HStack(spacing: 6) {
                ForEach(Array(ratingEmojis.enumerated()), id: \.offset) { index, emoji in
                    Button {
                        selectedRatingIndex = index
                    } label: {
                        Text(emoji)
                            .font(.system(size: 22))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(selectedRatingIndex == index ? Color.accentColor.opacity(0.18) : Color.clear)
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(
                                        selectedRatingIndex == index ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.08),
                                        lineWidth: selectedRatingIndex == index ? 1.5 : 0.5
                                    )
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var statsPanelContent: some View {
        let bottomPad = max(bottomSafeInset + 4, 8)
        return VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(.secondary.opacity(0.35))
                .frame(width: 32, height: 3)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.summary.recordName)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)

                    Text(viewModel.completedAtSubtitleFormatted)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                TripResultStatsGrid(viewModel: viewModel)
            }
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, bottomPad)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Stats (chỉ hiển thị dữ liệu từ ViewModel)

struct TripResultStatsGrid: View {
    @ObservedObject var viewModel: TripResultViewModel

    var body: some View {
        VStack(spacing: 8) {
            statCellCentered(
                icon: "arrow.left.and.right",
                value: viewModel.distanceTraveledDisplay,
                label: AppString.tripResultDistance
            )

            HStack(alignment: .top, spacing: 8) {
                statCellHalf(
                    icon: "gauge.with.dots.needle.67percent",
                    value: viewModel.averageSpeedDisplay,
                    label: AppString.tripResultAvgSpeed
                )
                statCellHalf(
                    icon: "gauge.with.dots.needle.67percent",
                    value: viewModel.maxSpeedDisplay,
                    label: AppString.tripResultMaxSpeed
                )
            }

            HStack(alignment: .top, spacing: 8) {
                statCellHalf(
                    icon: "clock.fill",
                    value: viewModel.movingClockMMSS,
                    label: AppString.tripResultMovingTime
                )
                statCellHalf(
                    icon: "clock.fill",
                    value: viewModel.elapsedClockMMSS,
                    label: AppString.tripResultElapsedTime
                )
            }
        }
        .padding(.top, 4)
    }

    private func statCellCentered(icon: String, value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3.weight(.medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.8)
                .lineLimit(1)

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }

    private func statCellHalf(icon: String, value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.body.weight(.medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.75)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }
}
