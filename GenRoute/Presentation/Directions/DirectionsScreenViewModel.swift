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

    @Published var route: MKRoute?
    @Published var routeOptions: DirectionsRouteOptions
    @Published var cameraPosition: MapCameraPosition = .automatic
    /// Góc xoay bản đồ (độ), dùng cho la bàn tùy chỉnh — đồng bộ qua `onMapCameraChange`.
    @Published private(set) var mapHeadingDegrees: Double = 0
    @Published var isCalculating = true
    @Published var errorMessage: String?

    /// Puck điều hướng: dev = giả lập dọc tuyến; release = GPS thật.
    @Published private(set) var navigationPuckCoordinate: CLLocationCoordinate2D?
    @Published private(set) var isNavigating: Bool = false

    /// Quãng đường đã đi dọc tuyến (ước lượng từ polyline).
    @Published private(set) var distanceTraveledAlongRoute: CLLocationDistance = 0
    /// Chỉ dẫn bước hiện tại (từ `MKRoute.Step`).
    @Published private(set) var currentManeuverInstruction: String = ""
    /// Khoảng cách còn lại tới hết bước chỉ dẫn hiện tại (mét).
    @Published private(set) var distanceToNextManeuverMeters: CLLocationDistance = 0

    /// Heading cho mini map preview (độ, theo chiều kim đồng hồ từ Bắc).
    @Published private(set) var navigationHeadingDegrees: CLLocationDirection = 0
    /// Route đã pre-compute sang hệ toạ độ phẳng — dùng cho mini map.
    private(set) var navigationRouteStatic: NavigationRouteStatic?
    /// Lane spokes đã tính từ route — dùng cho mini map.
    private(set) var navigationLaneSpokes: [LaneSpoke] = []

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

        #if DEBUG
        print("DirectionsScreenViewModel init: startPlaceId=\(String(describing: navigation.startPlaceId)) startCoord=\(String(describing: self.startCoordinate)) endPlaceId=\(navigation.endPlaceId)")
        #endif
    }

    func loadRouteFromSavedPlaces() async {
        stopNavigation()
        errorMessage = nil
        route = nil
        activeRouteSampler = nil
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

        #if DEBUG
        if let coord = startCoordinate {
            print("loadRouteFromSavedPlaces: startCoord=\(coord.latitude),\(coord.longitude) endPlaceId=\(endPlaceId) end=\(endPlace.latitude),\(endPlace.longitude)")
        } else {
            print("loadRouteFromSavedPlaces: startPlaceId=\(String(describing: startPlaceId)) endPlaceId=\(endPlaceId) end=\(endPlace.latitude),\(endPlace.longitude)")
        }
        #endif

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
        guard let route = route, let sampler = activeRouteSampler, let startCoord = startEndpoint?.coordinate else { return }
        stopNavigation()
        isNavigating = true
        distanceTraveledAlongRoute = 0
        navigationSessionStart = Date()
        maxObservedSpeedKmh = 0
        lastPuckForCameraBearing = startCoord
        navigationPuckCoordinate = startCoord

        let totalLen = min(route.distance, sampler.totalLength)
        refreshTurnByTurn(for: route, traveled: 0, totalPolylineLength: totalLen)
        followNavigationCamera(to: startCoord, headingDegrees: nil)

        if DirectionsEnvironment.isDev {
            startSimulatedPuckAlongRoute(sampler: sampler, totalPolylineLength: totalLen, startCoordinate: startCoord)
        } else {
            startLiveUserPuck(route: route, sampler: sampler, totalPolylineLength: totalLen)
        }
    }

    func stopNavigation() {
        simulationTask?.cancel()
        simulationTask = nil
        liveNavigationService?.stop()
        liveNavigationService = nil
        isNavigating = false
        lastPuckForCameraBearing = nil
        navigationPuckCoordinate = nil
        distanceTraveledAlongRoute = 0
        currentManeuverInstruction = ""
        distanceToNextManeuverMeters = 0
        navigationHeadingDegrees = 0
        showTripCompletionDialog = false
        pendingTripSummary = nil
        navigationSessionStart = nil
        maxObservedSpeedKmh = 0
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
        guard let route = route, sampler.totalLength > 0 else {
            isNavigating = false
            return
        }

        simulationTask = Task { @MainActor in
            var distance: CLLocationDistance = 0
            var lastDate = Date()
            var previousPuck = startCoordinate
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(50))
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
                if let h = heading {
                    self.navigationHeadingDegrees = h
                }
                previousPuck = coord
                followNavigationCamera(to: coord, headingDegrees: heading)

                refreshTurnByTurn(for: route, traveled: distance, totalPolylineLength: totalPolylineLength)
                if !isNavigating { break }
            }
        }
    }

    private func startLiveUserPuck(route: MKRoute, sampler: RoutePolylineSampler, totalPolylineLength: CLLocationDistance) {
        let service = LiveNavigationLocationService()
        liveNavigationService = service
        service.onLocation = { [weak self] loc in
            Task { @MainActor in
                guard let self else { return }
                guard self.isNavigating else { return }
                self.navigationPuckCoordinate = loc.coordinate
                let traveled = sampler.distanceAlongRoute(closestTo: loc.coordinate)
                self.distanceTraveledAlongRoute = traveled
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
                if let h = heading {
                    self.navigationHeadingDegrees = h
                }
                self.lastPuckForCameraBearing = loc.coordinate
                self.followNavigationCamera(to: loc.coordinate, headingDegrees: heading)

                self.refreshTurnByTurn(for: route, traveled: traveled, totalPolylineLength: totalPolylineLength)
            }
        }
        service.start()
    }

    /// Giữ camera bám puck; có `heading` thì xoay map như chế độ chỉ đường.
    private func followNavigationCamera(to coordinate: CLLocationCoordinate2D, headingDegrees: CLLocationDirection?) {
        guard isNavigating else { return }
        if let heading = headingDegrees, heading.isFinite, heading >= 0 {
            withAnimation(NativeMotion.directionsMapCamera) {
                cameraPosition = .camera(
                    MapCamera(
                        centerCoordinate: coordinate,
                        distance: navigationCameraDistance,
                        heading: heading,
                        pitch: navigationCameraPitch
                    )
                )
            }
        } else {
            withAnimation(NativeMotion.directionsMapCamera) {
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

    private func refreshTurnByTurn(for route: MKRoute, traveled: CLLocationDistance, totalPolylineLength: CLLocationDistance) {
        if traveled >= totalPolylineLength - arrivalEpsilonMeters {
            completeNavigationArrival()
            return
        }

        let steps = route.steps
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
        if let d = route?.distance, d > 0 {
            startToDestination = d
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
        navigationHeadingDegrees = 0
        navigationSessionStart = nil
        maxObservedSpeedKmh = 0
    }

    private func releaseHeavyResourcesAfterTripFlow() {
        simulationTask?.cancel()
        simulationTask = nil
        liveNavigationService?.stop()
        liveNavigationService = nil
        activeRouteSampler = nil
        navigationRouteStatic = nil
        navigationLaneSpokes = []
        route = nil
    }

    private func runRouteCalculation() async {
        defer { isCalculating = false }
        guard let start = startEndpoint, let end = endEndpoint else { return }

        do {
            let calculated = try await routingService.calculateRoute(from: start, to: end, options: routeOptions)
            route = calculated
            activeRouteSampler = RoutePolylineSampler(polyline: calculated.polyline)
            navigationRouteStatic = NavigationRouteStatic(coordinates: calculated.polyline.routeCoordinates)
            navigationLaneSpokes = MiniMapLaneGenerator.generateLanes(from: calculated)
            fitMap(to: calculated)
        } catch DirectionsRoutingError.noRouteFound {
            errorMessage = String(localized: "directions_error_no_route_found")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fitMap(to route: MKRoute) {
        let rect = route.polyline.boundingMapRect
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
