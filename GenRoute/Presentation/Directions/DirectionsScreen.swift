import SwiftUI
import MapKit
import CoreLocation

struct DirectionsScreen: View {
    @StateObject var viewModel: DirectionsScreenViewModel
    @State private var showRouteSettings = false
    @State private var showStopNavigationConfirm = false
    @State private var showBackDuringNavigationConfirm = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $viewModel.cameraPosition) {
                if let route = viewModel.route {
                    MapPolyline(route.polyline)
                        .stroke(.blue, lineWidth: 6)
                }

                if let puck = viewModel.navigationPuckCoordinate {
                    Annotation("", coordinate: puck) {
                        navigationPuckMarker()
                    }
                }

                if let start = viewModel.startEndpoint {
                    Annotation(start.name, coordinate: start.coordinate) {
                        routeMarker(systemImage: "flag.checkered", color: .green)
                    }
                }

                if let end = viewModel.endEndpoint {
                    Annotation(end.name, coordinate: end.coordinate) {
                        routeMarker(systemImage: "mappin.circle.fill", color: .red)
                    }
                }
            }
            .onMapCameraChange(frequency: .continuous) { context in
                viewModel.syncMapCameraFromMap(context.camera)
            }
            .ignoresSafeArea(edges: .bottom)

            if let start = viewModel.startEndpoint, let end = viewModel.endEndpoint {
                Group {
                    if viewModel.isNavigating {
                        VStack(spacing: 12) {
                            if DirectionsEnvironment.isDev {
                                directionsDevControlPanel()
                            }
                            navigatingNextStepCard(endName: end.name)
                            directionsStopButton()
                        }
                    } else {
                        VStack(spacing: 12) {
                            if DirectionsEnvironment.isDev {
                                directionsDevControlPanel()
                            }
                            compactRouteSummaryCard(start: start, end: end)
                            directionsStartButton()
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }

            if viewModel.isCalculating {
                ProgressView()
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            if !viewModel.isNavigating {
                VStack(spacing: 14) {
                    Button {
                        showRouteSettings = true
                    } label: {
                        directionFloatingButtonLabel(systemName: "gearshape.fill", tint: .primary)
                    }
                    .accessibilityLabel(Text(AppString.directionsSettingsTitle))

                    Button {
                        viewModel.focusCameraOnStart()
                    } label: {
                        directionFloatingButtonLabel(systemName: "flag.checkered", tint: Color.green)
                    }
                    .disabled(viewModel.startEndpoint == nil)
                    .accessibilityLabel(Text(AppString.directionsFocusStartHint))

                    Button {
                        viewModel.resetMapHeadingToNorth()
                    } label: {
                        customCompassButton()
                    }
                    .accessibilityLabel(Text(AppString.directionsCompassNorthHint))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 10)
                .padding(.trailing, 14)
            }
        }
        .navigationTitle(AppString.directionsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(viewModel.isNavigating)
        .toolbar {
            if viewModel.isNavigating {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showBackDuringNavigationConfirm = true
                    } label: {
                        if #available(iOS 26.0, *) {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                        } else {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.body.weight(.semibold))
                                Text(AppString.rideCancel)
                                    .font(.body.weight(.semibold))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(AppString.directionsStopConfirmTitle))
                }
            }
        }
        .sheet(isPresented: $showRouteSettings) {
            DirectionsRouteSettingsSheet(initial: viewModel.routeOptions) { options in
                Task { await viewModel.applyRouteOptions(options) }
            }
        }
        .task {
            await viewModel.loadRouteFromSavedPlaces()
        }
        .onDisappear {
            viewModel.stopNavigation()
        }
        .alert(
            AppString.directionsRouteErrorTitle,
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button(AppString.rideOk) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .alert(
            AppString.directionsArrivalTitle,
            isPresented: $viewModel.showTripCompletionDialog,
            actions: {
                Button(AppString.directionsViewTripResults) {
                    viewModel.confirmTripCompletionAndNavigate()
                }
            },
            message: {
                Text(AppString.directionsArrivalMessage)
            }
        )
        .alert(
            AppString.directionsStopConfirmTitle,
            isPresented: $showStopNavigationConfirm,
            actions: {
                Button(AppString.rideCancel, role: .cancel) { }
                Button(AppString.directionsStopConfirmAction, role: .destructive) {
                    viewModel.finishTripAfterUserStopped()
                }
            },
            message: {
                Text(AppString.directionsStopConfirmMessage)
            }
        )
        .alert(
            AppString.directionsStopConfirmTitle,
            isPresented: $showBackDuringNavigationConfirm,
            actions: {
                Button(AppString.rideCancel, role: .cancel) { }
                Button(AppString.directionsStopConfirmAction, role: .destructive) {
                    viewModel.finishTripAfterUserStopped()
                    viewModel.confirmTripCompletionAndNavigate()
                }
            },
            message: {
                Text(AppString.directionsStopConfirmMessage)
            }
        )
    }

    private func navigatingNextStepCard(endName: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "arrow.turn.up.right")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.9), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(AppString.directionsNextManeuverTitle)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Text(viewModel.currentManeuverInstruction)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Text(AppString.directionsToNextManeuver)
                            .foregroundStyle(.secondary)
                        Text(RouteSummaryFormatting.distance(meters: viewModel.distanceToNextManeuverMeters))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.orange)
                    }
                    .font(.subheadline)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 6) {
                Image(systemName: "flag.checkered")
                    .foregroundStyle(.green)
                Text(endName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.thickMaterial)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.45), Color.cyan.opacity(0.22)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        }
        .shadow(color: Color.black.opacity(0.3), radius: 16, x: 0, y: 6)
        .accessibilityElement(children: .combine)
    }

    private func directionsStopButton() -> some View {
        Button {
            showStopNavigationConfirm = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "stop.fill")
                    .font(.subheadline.weight(.bold))
                Text(AppString.directionsStopButton)
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.75, green: 0.12, blue: 0.18),
                                Color(red: 0.55, green: 0.08, blue: 0.12)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .shadow(color: Color.red.opacity(0.35), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(AppString.directionsStopA11y))
    }

    private func directionFloatingButtonLabel(systemName: String, tint: Color) -> some View {
        Image(systemName: systemName)
            .font(.title3)
            .foregroundStyle(tint)
            .frame(width: 44, height: 44)
            .background(.ultraThinMaterial, in: Circle())
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
    }

    /// La bàn tùy chỉnh: mũi tên Bắc xoay theo heading map; chạm để north-up.
    private func customCompassButton() -> some View {
        Image(systemName: "location.north.fill")
            .font(.title3)
            .foregroundStyle(.primary)
            .rotationEffect(.degrees(-viewModel.mapHeadingDegrees))
            .animation(NativeMotion.directionsCompassRotation, value: viewModel.mapHeadingDegrees)
            .frame(width: 44, height: 44)
            .background(.ultraThinMaterial, in: Circle())
            .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
    }

    private func navigationPuckMarker() -> some View {
        ZStack {
            Circle()
                .fill(Color.blue.gradient)
                .frame(width: 18, height: 18)
            Circle()
                .strokeBorder(Color.white, lineWidth: 3)
                .frame(width: 20, height: 20)
        }
        .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
        .accessibilityLabel(Text(AppString.directionsNavPuckA11y))
    }

    private func directionsDevControlPanel() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(AppString.directionsDevPanelTitle)
                .font(.caption.weight(.heavy))
                .foregroundStyle(.orange)
            HStack {
                Text(AppString.directionsDevSpeedLabel)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(RouteSummaryFormatting.speedKmh(viewModel.devSpeedKmh))
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Slider(value: $viewModel.devSpeedKmh, in: 5...120, step: 1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.orange.opacity(0.35), lineWidth: 1)
                )
        }
    }

    private func routeMarker(systemImage: String, color: Color) -> some View {
        Image(systemName: systemImage)
            .font(.title2)
            .foregroundStyle(color)
            .padding(4)
            .background(Circle().fill(.white))
            .shadow(radius: 2)
    }

    private func compactRouteSummaryCard(start: RouteEndpoint, end: RouteEndpoint) -> some View {
        let vehicle = viewModel.routeOptions.vehicle
        return HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: vehicle.routeSummarySystemImage)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.blue)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                if let route = viewModel.route {
                    HStack(spacing: 6) {
                        Text(RouteSummaryFormatting.distance(meters: route.distance))
                            .foregroundStyle(Color.blue)
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(RouteSummaryFormatting.duration(seconds: route.expectedTravelTime))
                            .foregroundStyle(Color.orange)
                        Text("·")
                            .foregroundStyle(.secondary)
                        Text(AppString.directionsSummaryEstLabel)
                            .foregroundStyle(.secondary)
                    }
                    .font(.subheadline.weight(.bold))
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "flag.checkered")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.green)
                    Text(start.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Image(systemName: "arrow.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Image(systemName: "mappin.circle.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.red)
                    Text(end.name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.thickMaterial)
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.55),
                                Color.white.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        }
        .shadow(color: Color.black.opacity(0.28), radius: 18, x: 0, y: 8)
        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
        .accessibilityElement(children: .combine)
    }

    private func directionsStartButton() -> some View {
        Button {
            viewModel.startNavigation()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.subheadline.weight(.bold))
                Text(AppString.directionsStartTripButton)
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.0, green: 0.55, blue: 0.45),
                                Color(red: 0.0, green: 0.42, blue: 0.85)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            }
            .shadow(color: Color(red: 0.0, green: 0.35, blue: 0.55).opacity(0.45), radius: 12, x: 0, y: 5)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(AppString.directionsStartTripButton))
        .disabled(viewModel.route == nil || viewModel.isCalculating)
    }
}
