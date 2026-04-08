import Combine
import CoreLocation
import Foundation
import MapKit
import SwiftUI

@MainActor
final class DirectionsScreenViewModel: BaseViewModel {
    private let endPlaceId: UUID
    private let startPlaceId: UUID?
    private let startCoordinate: CLLocationCoordinate2D?
    private let placesRepository: PlacesRepositoryProtocol
    private let routingService: DirectionsRoutingServiceProtocol
    private let preferencesStore: DirectionsRoutePreferencesStoring
    private let onTripCompleted: (TripResultSummary) -> Void

    /// Điểm xuất phát đã resolve từ DB (địa chỉ = `name` đã lưu).
    @Published private(set) var startEndpoint: RouteEndpoint?
    /// Điểm đến đã resolve từ DB.
    @Published private(set) var endEndpoint: RouteEndpoint?

    /// Tuyến hiển thị (mặc định Valhalla); MapKit chỉ khi Valhalla lỗi.
    @Published private(set) var navigationPolyline: MKPolyline?
    @Published private(set) var navigationRouteDistanceMeters: CLLocationDistance = 0
    @Published private(set) var navigationRouteDurationSeconds: TimeInterval = 0
    private var navigationTurnSteps: [NavigationTurnStep] = []

    @Published var routeOptions: DirectionsRouteOptions
    @Published var cameraPosition: MapCameraPosition = .automatic
    /// Góc xoay bản đồ (độ), dùng cho la bàn tùy chỉnh — đồng bộ qua `onMapCameraChange`.
    @Published private(set) var mapHeadingDegrees: Double = 0
    @Published var isCalculating = true
    @Published var errorMessage: String?

    // MARK: - Dev mini-map preview (Valhalla context)

    @Published private(set) var devPreviewRouteCoordinates: [CLLocationCoordinate2D] = []
    @Published private(set) var devPreviewLanePolylines: [[CLLocationCoordinate2D]] = []
    @Published private(set) var devPreviewDebugText: String = ""
    private var devPreviewIntersections: [ValhallaOSRMRouteService.Intersection] = []
    private var devPreviewRouteSampler: RoutePolylineSampler?
    private var lastLoggedDevPreviewSummary: String?
    private var lastDevLaneRefreshAt: Date = .distantPast

    /// Puck điều hướng: dev = giả lập dọc tuyến; release = GPS thật.
    @Published private(set) var navigationPuckCoordinate: CLLocationCoordinate2D?
    @Published private(set) var isNavigating: Bool = false

    /// Quãng đường đã đi dọc tuyến (ước lượng từ polyline).
    @Published private(set) var distanceTraveledAlongRoute: CLLocationDistance = 0
    /// Chỉ dẫn bước hiện tại (OSRM/Valhalla hoặc MapKit fallback).
    @Published private(set) var currentManeuverInstruction: String = ""
    /// Khoảng cách còn lại tới hết bước chỉ dẫn hiện tại (mét).
    @Published private(set) var distanceToNextManeuverMeters: CLLocationDistance = 0

    /// Dialog sau khi tới đích / dừng; bấm nút sẽ đi tới màn kết quả và giải phóng stack chỉ đường.
    @Published var showTripCompletionDialog: Bool = false
    private var navigationSessionStart: Date?
    private var maxObservedSpeedKmh: Double = 0
    private var pendingTripSummary: TripResultSummary?

    /// Dev: tốc độ giả lập (km/h), điều chỉnh bằng slider.
    @Published var devSpeedKmh: Double = 35

    private var lastCameraForNorthUp: MapCamera?
    private var simulationTask: Task<Void, Never>?
    private var liveNavigationService: LiveNavigationLocationService?
    private var activeRouteSampler: RoutePolylineSampler?
    private var lastPuckForCameraBearing: CLLocationCoordinate2D?
    private var smoothingTask: Task<Void, Never>?
    private let keyframeSmoother = NavigationKeyframeSmoother()
    private var lastDevPreviewBearingDegrees: CLLocationDirection?

    /// Camera điều hướng: zoom gần + pitch (giống Google Maps).
    private let navigationCameraDistance: CLLocationDistance = 720
    private let navigationCameraPitch: CGFloat = 38
    private let navigationRegionSpan = MKCoordinateSpan(latitudeDelta: 0.0075, longitudeDelta: 0.0075)

    private let arrivalEpsilonMeters: CLLocationDistance = 30

    init(
        navigation: DirectionsRouteNavigationValue,
        placesRepository: PlacesRepositoryProtocol? = nil,
        routingService: DirectionsRoutingServiceProtocol = DirectionsRoutingService(),
        preferencesStore: DirectionsRoutePreferencesStoring = UserDefaultsDirectionsRoutePreferencesStore(),
        onTripCompleted: @escaping (TripResultSummary) -> Void
    ) {
        self.endPlaceId = navigation.endPlaceId
        self.startPlaceId = navigation.startPlaceId
        if let lat = navigation.startLatitude, let lon = navigation.startLongitude {
            self.startCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        } else {
            self.startCoordinate = nil
        }
        self.placesRepository = placesRepository ?? PlacesRepository()
        self.routingService = routingService
        self.preferencesStore = preferencesStore
        self.onTripCompleted = onTripCompleted
        self.routeOptions = preferencesStore.loadOptions()
        super.init()

        DirectionsDevLog.log(
            "VM init startPlaceId=\(String(describing: navigation.startPlaceId)) startCoord=\(String(describing: self.startCoordinate)) endPlaceId=\(navigation.endPlaceId)"
        )
    }

    func loadRouteFromSavedPlaces() async {
        stopNavigation()
        errorMessage = nil
        clearComputedRouteState()
        startEndpoint = nil
        endEndpoint = nil
        isCalculating = true

        if let startPlaceId, startPlaceId == endPlaceId {
            isCalculating = false
            errorMessage = String(localized: "directions_error_same_place")
            return
        }

        guard let endPlace = placesRepository.fetchPlace(byId: endPlaceId) else {
            isCalculating = false
            errorMessage = String(localized: "directions_error_load_places_failed")
            return
        }

        let start: RouteEndpoint
        if let coord = startCoordinate {
            start = RouteEndpoint(id: UUID(), name: String(localized: "directions_start_label"), coordinate: coord)
        } else if let startPlaceId, let startPlace = placesRepository.fetchPlace(byId: startPlaceId) {
            start = RouteEndpoint(place: startPlace)
        } else {
            isCalculating = false
            errorMessage = String(localized: "directions_error_start_unknown")
            return
        }

        if let coord = startCoordinate {
            DirectionsDevLog.log(
                "loadRoute startCoord=\(coord.latitude),\(coord.longitude) endPlaceId=\(endPlaceId) end=\(endPlace.latitude),\(endPlace.longitude)"
            )
        } else {
            DirectionsDevLog.log(
                "loadRoute startPlaceId=\(String(describing: startPlaceId)) endPlaceId=\(endPlaceId) end=\(endPlace.latitude),\(endPlace.longitude)"
            )
        }

        let end = RouteEndpoint(place: endPlace)
        startEndpoint = start
        endEndpoint = end
        cameraPosition = .region(regionFitting(start: start, end: end))
        routeOptions = preferencesStore.loadOptions()

        await runRouteCalculation()
    }

    func applyRouteOptions(_ options: DirectionsRouteOptions) async {
        stopNavigation()
        routeOptions = options
        preferencesStore.saveOptions(options)
        isCalculating = true
        await runRouteCalculation()
    }

    /// Bắt đầu “di chuyển”: dev → giả lập theo tốc độ slider; release → GPS thật.
    func startNavigation() {
        guard navigationPolyline != nil, let sampler = activeRouteSampler, let startCoord = startEndpoint?.coordinate else { return }
        // `stopNavigation()` mặc định xóa cache Valhalla — giữ lại để mini-map vẫn có round context khi bắt đầu chạy.
        stopNavigation(preserveDevPreview: true)
        isNavigating = true
        distanceTraveledAlongRoute = 0
        navigationSessionStart = Date()
        maxObservedSpeedKmh = 0
        lastPuckForCameraBearing = startCoord
        lastDevPreviewBearingDegrees = nil
        navigationPuckCoordinate = startCoord
        keyframeSmoother.reset()
        refreshDevPreviewLanePolylinesIfPossible(force: true)

        let polyLen = sampler.totalLength
        refreshTurnByTurn(traveled: 0, totalPolylineLength: polyLen)
        followNavigationCamera(to: startCoord, headingDegrees: nil)

        if DirectionsEnvironment.isDev {
            startSimulatedPuckAlongRoute(sampler: sampler, totalPolylineLength: polyLen, startCoordinate: startCoord)
        } else {
            startLiveUserPuck(sampler: sampler, totalPolylineLength: polyLen)
        }
    }

    /// - Parameter preserveDevPreview: `true` khi chuyển thẳng sang `startNavigation()` — giữ polyline Valhalla + intersections cho mini-map.
    func stopNavigation(preserveDevPreview: Bool = false) {
        simulationTask?.cancel()
        simulationTask = nil
        smoothingTask?.cancel()
        smoothingTask = nil
        liveNavigationService?.stop()
        liveNavigationService = nil
        isNavigating = false
        lastPuckForCameraBearing = nil
        lastDevPreviewBearingDegrees = nil
        navigationPuckCoordinate = nil
        distanceTraveledAlongRoute = 0
        currentManeuverInstruction = ""
        distanceToNextManeuverMeters = 0
        showTripCompletionDialog = false
        pendingTripSummary = nil
        navigationSessionStart = nil
        maxObservedSpeedKmh = 0
        if !preserveDevPreview {
            replaceDevPreviewRouteCoordinates([])
            devPreviewLanePolylines = []
            devPreviewIntersections = []
            devPreviewDebugText = ""
            lastLoggedDevPreviewSummary = nil
        }
    }

    /// Gọi sau khi user bấm Stop và xác nhận: chốt thống kê, hiện dialog hoàn thành.
    func finishTripAfterUserStopped() {
        simulationTask?.cancel()
        simulationTask = nil
        liveNavigationService?.stop()
        liveNavigationService = nil

        let summary = buildTripSummary(reason: .stoppedByUser)
        completeNavigationTeardownAfterTrip()
        pendingTripSummary = summary
        showTripCompletionDialog = true
    }

    /// User bấm nút trên dialog hoàn thành → chuyển sang màn kết quả và thu hồi bộ nhớ nặng.
    func confirmTripCompletionAndNavigate() {
        guard let summary = pendingTripSummary else { return }
        pendingTripSummary = nil
        showTripCompletionDialog = false
        releaseHeavyResourcesAfterTripFlow()
        onTripCompleted(summary)
    }

    private func startSimulatedPuckAlongRoute(
        sampler: RoutePolylineSampler,
        totalPolylineLength: CLLocationDistance,
        startCoordinate: CLLocationCoordinate2D
    ) {
        guard navigationPolyline != nil, sampler.totalLength > 0 else {
            isNavigating = false
            return
        }

        simulationTask = Task { @MainActor in
            var distance: CLLocationDistance = 0
            var lastDate = Date()
            var previousPuck = startCoordinate
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(33))
                guard isNavigating else { break }
                let now = Date()
                let dt = now.timeIntervalSince(lastDate)
                lastDate = now
                let speedMetersPerSecond = devSpeedKmh / 3.6
                distance += speedMetersPerSecond * dt
                distance = min(distance, totalPolylineLength)
                distanceTraveledAlongRoute = distance
                let coord = sampler.coordinate(atDistance: distance)
                navigationPuckCoordinate = coord
                self.maxObservedSpeedKmh = max(self.maxObservedSpeedKmh, self.devSpeedKmh)

                let prevLoc = CLLocation(latitude: previousPuck.latitude, longitude: previousPuck.longitude)
                let curLoc = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
                let heading: CLLocationDirection? = prevLoc.distance(from: curLoc) > 1.5
                    ? Self.bearingDegrees(from: previousPuck, to: coord)
                    : nil
                if let h = heading { self.lastDevPreviewBearingDegrees = h }
                previousPuck = coord
                refreshDevPreviewLanePolylinesIfPossible()
                followNavigationCamera(to: coord, headingDegrees: heading)

                refreshTurnByTurn(traveled: distance, totalPolylineLength: totalPolylineLength)
                if !isNavigating { break }
            }
        }
    }

    private func startLiveUserPuck(sampler: RoutePolylineSampler, totalPolylineLength: CLLocationDistance) {
        let service = LiveNavigationLocationService()
        liveNavigationService = service
        keyframeSmoother.reset()
        smoothingTask?.cancel()
        smoothingTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(33))
                guard isNavigating else { break }
                guard let smooth = keyframeSmoother.sample(at: Date().timeIntervalSince1970) else { continue }
                navigationPuckCoordinate = smooth.coordinate
                distanceTraveledAlongRoute = smooth.traveledMeters
                if let h = smooth.headingDegrees { self.lastDevPreviewBearingDegrees = h }
                refreshDevPreviewLanePolylinesIfPossible()
                followNavigationCamera(to: smooth.coordinate, headingDegrees: smooth.headingDegrees)
                refreshTurnByTurn(traveled: smooth.traveledMeters, totalPolylineLength: totalPolylineLength)
            }
        }
        service.onLocation = { [weak self] loc in
            Task { @MainActor in
                guard let self else { return }
                guard self.isNavigating else { return }
                let traveled = sampler.distanceAlongRoute(closestTo: loc.coordinate)
                if loc.speed >= 0 {
                    self.maxObservedSpeedKmh = max(self.maxObservedSpeedKmh, loc.speed * 3.6)
                }

                var heading: CLLocationDirection? = loc.course >= 0 ? loc.course : nil
                if heading == nil, let prev = self.lastPuckForCameraBearing {
                    let a = CLLocation(latitude: prev.latitude, longitude: prev.longitude)
                    let b = CLLocation(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
                    if a.distance(from: b) > 3 {
                        heading = Self.bearingDegrees(from: prev, to: loc.coordinate)
                    }
                }
                self.lastPuckForCameraBearing = loc.coordinate
                self.keyframeSmoother.push(
                    NavigationKeyframe(
                        coordinate: loc.coordinate,
                        headingDegrees: heading,
                        traveledMeters: traveled,
                        timestamp: loc.timestamp.timeIntervalSince1970
                    )
                )
            }
        }
        service.start()
    }

    /// Luôn có giá trị: heading-up theo −Y chiếu — ưu tiên course/GPS hoặc tiếp tuyến polyline.
    func devPreviewBearingDegrees() -> Double {
        if let h = lastDevPreviewBearingDegrees, h.isFinite, h >= 0 {
            return h
        }
        if let sampler = activeRouteSampler, sampler.totalLength > 1 {
            let d = min(max(0, distanceTraveledAlongRoute), sampler.totalLength)
            let span = min(14.0, max(4.0, sampler.totalLength * 0.03))
            let d1 = max(0, d - span)
            let d2 = min(sampler.totalLength, d + span)
            let c1 = sampler.coordinate(atDistance: d1)
            let c2 = sampler.coordinate(atDistance: d2)
            let a = CLLocation(latitude: c1.latitude, longitude: c1.longitude)
            let b = CLLocation(latitude: c2.latitude, longitude: c2.longitude)
            if a.distance(from: b) > 0.4 {
                return Self.bearingDegrees(from: c1, to: c2)
            }
        }
        let coords = devPreviewRouteCoordinates
        if coords.count >= 2 {
            return Self.bearingDegrees(from: coords[0], to: coords[1])
        }
        if let poly = navigationPolyline?.routeCoordinates, poly.count >= 2 {
            return Self.bearingDegrees(from: poly[0], to: poly[1])
        }
        return 0
    }

    func devPreviewCenterCoordinate(fallback: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        if isNavigating,
           let mk = activeRouteSampler,
           mk.totalLength > 0
        {
            let traveled = min(max(0, distanceTraveledAlongRoute), mk.totalLength)
            if let valhalla = devPreviewRouteSampler, valhalla.totalLength > 0 {
                let scaled = traveled * (valhalla.totalLength / mk.totalLength)
                return valhalla.coordinate(atDistance: min(scaled, valhalla.totalLength))
            }
            return mk.coordinate(atDistance: traveled)
        }
        guard devPreviewRouteCoordinates.count >= 2 else { return fallback }
        return RouteSnapper.snapToPolyline(point: fallback, polyline: devPreviewRouteCoordinates) ?? fallback
    }

    private func replaceDevPreviewRouteCoordinates(_ coords: [CLLocationCoordinate2D]) {
        devPreviewRouteCoordinates = coords
        devPreviewRouteSampler = coords.count >= 2 ? RoutePolylineSampler(coordinates: coords) : nil
        lastDevLaneRefreshAt = .distantPast
    }

    private func refreshDevPreviewLanePolylinesIfPossible(force: Bool = false) {
        guard DirectionsEnvironment.isDev else { return }
        guard !devPreviewIntersections.isEmpty else {
            devPreviewLanePolylines = []
            devPreviewDebugText = "Valhalla: no intersections"
            if lastLoggedDevPreviewSummary != devPreviewDebugText {
                lastLoggedDevPreviewSummary = devPreviewDebugText
                DirectionsDevLog.log(devPreviewDebugText)
            }
            return
        }
        let now = Date()
        if !force, now.timeIntervalSince(lastDevLaneRefreshAt) < 0.22 { return }
        lastDevLaneRefreshAt = now

        let user = navigationPuckCoordinate ?? startEndpoint?.coordinate ?? endEndpoint?.coordinate
        guard let user else { return }
        devPreviewLanePolylines = Self.buildValhallaLanePolylinesNearUser(
            intersections: devPreviewIntersections,
            user: user,
            maxIntersections: 10,
            maxBearingsPerIntersection: 3,
            laneLengthMeters: 25
        )
        devPreviewDebugText = "Valhalla routePts=\(devPreviewRouteCoordinates.count) intersections=\(devPreviewIntersections.count) lanes=\(devPreviewLanePolylines.count)"
        if lastLoggedDevPreviewSummary != devPreviewDebugText {
            lastLoggedDevPreviewSummary = devPreviewDebugText
            DirectionsDevLog.log(devPreviewDebugText)
        }
    }

    /// Giữ camera bám puck; có `heading` thì xoay map như chế độ chỉ đường.
    private func followNavigationCamera(to coordinate: CLLocationCoordinate2D, headingDegrees: CLLocationDirection?) {
        guard isNavigating else { return }
        var tx = Transaction()
        tx.disablesAnimations = true
        withTransaction(tx) {
            if let heading = headingDegrees, heading.isFinite, heading >= 0 {
                cameraPosition = .camera(
                    MapCamera(
                        centerCoordinate: coordinate,
                        distance: navigationCameraDistance,
                        heading: heading,
                        pitch: navigationCameraPitch
                    )
                )
            } else {
                cameraPosition = .region(MKCoordinateRegion(center: coordinate, span: navigationRegionSpan))
            }
        }
    }

    private static func bearingDegrees(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> CLLocationDirection {
        let lat1 = from.latitude * (.pi / 180)
        let lon1 = from.longitude * (.pi / 180)
        let lat2 = to.latitude * (.pi / 180)
        let lon2 = to.longitude * (.pi / 180)
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        var deg = atan2(y, x) * 180 / .pi
        if deg < 0 { deg += 360 }
        return deg
    }

    private func refreshTurnByTurn(traveled: CLLocationDistance, totalPolylineLength: CLLocationDistance) {
        if traveled >= totalPolylineLength - arrivalEpsilonMeters {
            completeNavigationArrival()
            return
        }

        let steps = navigationTurnSteps
        guard !steps.isEmpty else {
            if let name = endEndpoint?.name {
                currentManeuverInstruction = String(format: String(localized: "directions_maneuver_head_toward_format"), name)
            } else {
                currentManeuverInstruction = String(localized: "directions_continue_route_fallback")
            }
            distanceToNextManeuverMeters = max(0, totalPolylineLength - traveled)
            return
        }

        var acc: CLLocationDistance = 0
        for step in steps {
            let endOfStep = acc + step.distance
            if traveled < endOfStep {
                let instruction = step.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
                currentManeuverInstruction = instruction.isEmpty ? String(localized: "directions_continue_route_fallback") : instruction
                distanceToNextManeuverMeters = max(0, endOfStep - traveled)
                return
            }
            acc = endOfStep
        }

        let last = steps.last!
        let ins = last.instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        currentManeuverInstruction = ins.isEmpty ? String(localized: "directions_maneuver_arrive_destination") : ins
        distanceToNextManeuverMeters = max(0, totalPolylineLength - traveled)
    }

    private func completeNavigationArrival() {
        guard isNavigating else { return }
        simulationTask?.cancel()
        simulationTask = nil
        liveNavigationService?.stop()
        liveNavigationService = nil

        if let end = endEndpoint {
            navigationPuckCoordinate = end.coordinate
            followNavigationCamera(to: end.coordinate, headingDegrees: nil)
        }
        if let sampler = activeRouteSampler {
            distanceTraveledAlongRoute = sampler.totalLength
        }

        let summary = buildTripSummary(reason: .arrivedAtDestination)
        completeNavigationTeardownAfterTrip()
        pendingTripSummary = summary
        showTripCompletionDialog = true
    }

    private func buildTripSummary(reason: TripCompletionReason) -> TripResultSummary {
        let completedAt = Date()
        let startCoord = startEndpoint?.coordinate
        let endCoord = endEndpoint?.coordinate
        let startToDestination: CLLocationDistance
        if navigationRouteDistanceMeters > 0 {
            startToDestination = navigationRouteDistanceMeters
        } else if let a = startCoord, let b = endCoord {
            startToDestination = GeodesicDistance.meters(from: a, to: b)
        } else {
            startToDestination = 0
        }

        let traveled = max(0, distanceTraveledAlongRoute)
        let sessionStart = navigationSessionStart ?? completedAt
        let duration = max(0, completedAt.timeIntervalSince(sessionStart))

        let avgKmh: Double
        if duration > 0.5 {
            avgKmh = (traveled / duration) * 3.6
        } else {
            avgKmh = 0
        }

        var maxKmh = maxObservedSpeedKmh
        if maxKmh <= 0, traveled > 0, duration > 0.5 {
            maxKmh = avgKmh
        }

        return TripResultSummary(
            recordName: TripRecordNaming.defaultRecordName(completedAt: completedAt),
            completedAt: completedAt,
            startToDestinationMeters: startToDestination,
            distanceTraveledMeters: traveled,
            movingDurationSeconds: duration,
            elapsedDurationSeconds: duration,
            averageSpeedKmh: avgKmh,
            maxSpeedKmh: maxKmh,
            completionReason: reason,
            mapStartLatitude: startCoord?.latitude ?? 0,
            mapStartLongitude: startCoord?.longitude ?? 0,
            mapEndLatitude: endCoord?.latitude ?? 0,
            mapEndLongitude: endCoord?.longitude ?? 0,
            startPlaceName: startEndpoint?.name ?? "",
            endPlaceName: endEndpoint?.name ?? ""
        )
    }

    private func completeNavigationTeardownAfterTrip() {
        isNavigating = false
        lastPuckForCameraBearing = nil
        navigationPuckCoordinate = nil
        distanceTraveledAlongRoute = 0
        currentManeuverInstruction = ""
        distanceToNextManeuverMeters = 0
        navigationSessionStart = nil
        maxObservedSpeedKmh = 0
    }

    private func releaseHeavyResourcesAfterTripFlow() {
        simulationTask?.cancel()
        simulationTask = nil
        liveNavigationService?.stop()
        liveNavigationService = nil
        activeRouteSampler = nil
        navigationPolyline = nil
        navigationRouteDistanceMeters = 0
        navigationRouteDurationSeconds = 0
        navigationTurnSteps = []
    }

    private func runRouteCalculation() async {
        defer { isCalculating = false }
        guard let start = startEndpoint, let end = endEndpoint else { return }

        resetRouteCalculationState()

        do {
            let nav = try await ValhallaOSRMRouteService.fetchNavigationRoute(
                baseURL: DirectionsEnvironment.valhallaBaseURL,
                start: start.coordinate,
                end: end.coordinate,
                options: routeOptions
            )
            applyValhallaNavigationRoute(nav)
            if let poly = navigationPolyline {
                fitMap(to: poly)
            }
        } catch {
            DirectionsDevLog.log("Valhalla route failed, MapKit fallback: \(error.localizedDescription)")
            do {
                let calculated = try await routingService.calculateRoute(from: start, to: end, options: routeOptions)
                applyMapKitFallbackRoute(calculated)
                fitMap(to: calculated.polyline)
            } catch DirectionsRoutingError.noRouteFound {
                errorMessage = String(localized: "directions_error_no_route_found")
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func clearComputedRouteState() {
        navigationPolyline = nil
        navigationRouteDistanceMeters = 0
        navigationRouteDurationSeconds = 0
        navigationTurnSteps = []
        activeRouteSampler = nil
    }

    private func resetRouteCalculationState() {
        clearComputedRouteState()
        replaceDevPreviewRouteCoordinates([])
        devPreviewLanePolylines = []
        devPreviewIntersections = []
        lastLoggedDevPreviewSummary = nil
        devPreviewDebugText = ""
    }

    private func applyValhallaNavigationRoute(_ nav: ValhallaOSRMRouteService.ValhallaNavigationRoute) {
        let poly = MKPolyline.fromRouteCoordinates(nav.routeCoordinates)
        navigationPolyline = poly
        navigationRouteDistanceMeters = nav.distanceMeters
        navigationRouteDurationSeconds = nav.durationSeconds
        navigationTurnSteps = nav.turnSteps
        activeRouteSampler = RoutePolylineSampler(coordinates: nav.routeCoordinates)
        replaceDevPreviewRouteCoordinates(nav.routeCoordinates)
        devPreviewIntersections = nav.intersections
        devPreviewLanePolylines = []
        refreshDevPreviewLanePolylinesIfPossible(force: true)
    }

    private func applyMapKitFallbackRoute(_ mk: MKRoute) {
        navigationPolyline = mk.polyline
        navigationRouteDistanceMeters = mk.distance
        navigationRouteDurationSeconds = mk.expectedTravelTime
        navigationTurnSteps = mk.steps.map { NavigationTurnStep(distance: $0.distance, instructions: $0.instructions) }
        activeRouteSampler = RoutePolylineSampler(polyline: mk.polyline)
        replaceDevPreviewRouteCoordinates([])
        devPreviewIntersections = []
        devPreviewLanePolylines = []
        devPreviewDebugText = "MapKit fallback (no Valhalla context)"
        lastLoggedDevPreviewSummary = nil
    }

    private static func buildValhallaLanePolylinesNearUser(
        intersections: [ValhallaOSRMRouteService.Intersection],
        user: CLLocationCoordinate2D,
        maxIntersections: Int,
        maxBearingsPerIntersection: Int,
        laneLengthMeters: Double
    ) -> [[CLLocationCoordinate2D]] {
        guard !intersections.isEmpty else { return [] }
        let sorted = intersections.sorted { a, b in
            let da = squaredDistance(from: user, to: a.coordinate)
            let db = squaredDistance(from: user, to: b.coordinate)
            return da < db
        }

        var picked: [ValhallaOSRMRouteService.Intersection] = []
        picked.reserveCapacity(maxIntersections)
        let minHubSeparationMeters: CLLocationDistance = 18
        for h in sorted {
            guard picked.count < maxIntersections else { break }
            let locH = CLLocation(latitude: h.coordinate.latitude, longitude: h.coordinate.longitude)
            let tooClose = picked.contains { p in
                locH.distance(from: CLLocation(latitude: p.coordinate.latitude, longitude: p.coordinate.longitude)) < minHubSeparationMeters
            }
            if tooClose { continue }
            picked.append(h)
        }

        var out: [[CLLocationCoordinate2D]] = []
        out.reserveCapacity(picked.count * maxBearingsPerIntersection)
        for h in picked {
            for b in h.bearings.prefix(maxBearingsPerIntersection) {
                let end = destinationPoint(start: h.coordinate, bearingDegrees: Double(b), distanceMeters: laneLengthMeters)
                out.append([h.coordinate, end])
            }
        }
        return out
    }

    private static func squaredDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let dx = from.latitude - to.latitude
        let dy = from.longitude - to.longitude
        return dx * dx + dy * dy
    }

    private static func destinationPoint(
        start: CLLocationCoordinate2D,
        bearingDegrees: Double,
        distanceMeters: Double
    ) -> CLLocationCoordinate2D {
        let r = 6_371_000.0
        let brng = bearingDegrees * (.pi / 180)
        let lat1 = start.latitude * (.pi / 180)
        let lon1 = start.longitude * (.pi / 180)
        let lat2 = asin(
            sin(lat1) * cos(distanceMeters / r) +
                cos(lat1) * sin(distanceMeters / r) * cos(brng)
        )
        let lon2 = lon1 + atan2(
            sin(brng) * sin(distanceMeters / r) * cos(lat1),
            cos(distanceMeters / r) - sin(lat1) * sin(lat2)
        )
        return CLLocationCoordinate2D(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
    }

    private func fitMap(to polyline: MKPolyline) {
        let rect = polyline.boundingMapRect
        var region = MKCoordinateRegion(rect)
        region.span.latitudeDelta *= 1.12
        region.span.longitudeDelta *= 1.12
        cameraPosition = .region(region)
    }

    func focusCameraOnStart() {
        guard let start = startEndpoint else { return }
        let span = MKCoordinateSpan(latitudeDelta: 0.035, longitudeDelta: 0.035)
        withAnimation(NativeMotion.directionsFocusStart) {
            cameraPosition = .region(MKCoordinateRegion(center: start.coordinate, span: span))
        }
    }

    func syncMapCameraFromMap(_ camera: MapCamera) {
        mapHeadingDegrees = camera.heading
        lastCameraForNorthUp = camera
    }

    /// Xoay bản đồ về hướng Bắc (heading 0), giữ tâm và zoom hiện tại.
    func resetMapHeadingToNorth() {
        guard let cam = lastCameraForNorthUp else {
            focusCameraOnStart()
            return
        }
        withAnimation(NativeMotion.directionsNorthUp) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: cam.centerCoordinate,
                    distance: cam.distance,
                    heading: 0,
                    pitch: cam.pitch
                )
            )
        }
    }

    private func regionFitting(start: RouteEndpoint, end: RouteEndpoint) -> MKCoordinateRegion {
        let latMin = min(start.coordinate.latitude, end.coordinate.latitude)
        let latMax = max(start.coordinate.latitude, end.coordinate.latitude)
        let lonMin = min(start.coordinate.longitude, end.coordinate.longitude)
        let lonMax = max(start.coordinate.longitude, end.coordinate.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (latMin + latMax) / 2,
            longitude: (lonMin + lonMax) / 2
        )
        let latDelta = max((latMax - latMin) * 1.5, 0.02)
        let lonDelta = max((lonMax - lonMin) * 1.5, 0.02)
        return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta))
    }
}
