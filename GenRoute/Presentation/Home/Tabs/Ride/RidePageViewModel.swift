import Foundation
import SwiftData
import CoreLocation
import Combine
import SwiftUI

@MainActor
class RidePageViewModel: BaseViewModel {
    @Published var savedPlaces: [PlaceModel] = []
    @Published var showPlaceEditor: Bool = false
    @Published var showPermissionAlert: Bool = false
    @Published private(set) var currentUserCoordinate: CLLocationCoordinate2D?
    
    private let locationService: LocationServiceProtocol
    private let placesRepository: PlacesRepositoryProtocol
    private var currentLocationFetcher: OneShotLocationFetcher?
    
    init(
        locationService: LocationServiceProtocol = LocationService(),
        placesRepository: PlacesRepositoryProtocol? = nil
    ) {
        self.locationService = locationService
        self.placesRepository = placesRepository ?? PlacesRepository()
        super.init()
    }
    
    func loadPlaces() {
        savedPlaces = placesRepository.fetchPlaces()
    }

    func refreshCurrentUserCoordinate() {
        let fetcher = OneShotLocationFetcher()
        currentLocationFetcher = fetcher
        fetcher.fetchCoordinate { [weak self] coordinate in
            DispatchQueue.main.async {
                self?.currentUserCoordinate = coordinate
                self?.currentLocationFetcher = nil
            }
        }
    }
    
    func deletePlaces(at offsets: IndexSet) {
        for index in offsets {
            let place = savedPlaces[index]
            placesRepository.deletePlace(place)
        }
        savedPlaces.remove(atOffsets: offsets)
    }
    
    func updatePlaceName(for place: PlaceModel, newName: String) {
        placesRepository.updatePlaceName(place, newName: newName)
        loadPlaces()
    }
    
    func movePlaces(from source: IndexSet, to destination: Int) {
        savedPlaces.move(fromOffsets: source, toOffset: destination)
    }
    
    func addPlaceTapped() {
        locationService.requestWhenInUseAuthorization { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.showPlaceEditor = true
                } else {
                    self?.showPermissionAlert = true
                }
            }
        }
    }

    /// Logic đúng:
    /// - **End**: item bạn bấm (địa điểm đã lưu).
    /// - **Start**: ưu tiên **GPS hiện tại** (mock/user). Nếu chưa lấy được GPS thì fallback sang 1 place đã lưu khác.
    /// Ưu tiên đọc từ SwiftData, nhưng fallback sang `savedPlaces` (đang render) để tránh lệch giữa UI và DB.
    func directionsNavigation(to destination: PlaceModel) -> DirectionsRouteNavigationValue? {
        let repositoryPlaces = placesRepository.fetchPlaces()
        var candidates: [PlaceModel] = repositoryPlaces
        if repositoryPlaces.count < 2 || !repositoryPlaces.contains(where: { $0.id == destination.id }) {
            // Fallback để đảm bảo `destination` tồn tại và UI đang render đúng với DB.
            candidates = savedPlaces
        }
        guard candidates.contains(where: { $0.id == destination.id }) else { return nil }

        let end = destination

        if let coord = currentUserCoordinate {
            return .userLocationToSaved(endPlaceId: end.id, userLatitude: coord.latitude, userLongitude: coord.longitude)
        }

        // Fallback: nếu chưa có GPS, dùng 1 place khác trong DB để vẫn mở được directions khi có >= 2 place.
        let others = candidates.filter { $0.id != end.id }
        guard let start = others.max(by: { $0.timestamp < $1.timestamp }) else { return nil }
        return .savedToSaved(startPlaceId: start.id, endPlaceId: end.id)
    }
}
