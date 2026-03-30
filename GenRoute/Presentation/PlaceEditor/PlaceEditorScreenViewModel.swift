import Foundation
import Combine
import CoreLocation
import MapKit
import SwiftUI

@MainActor
class PlaceEditorScreenViewModel: BaseViewModel {
    // Dependencies
    private let searchService: LocalSearchServiceProtocol
    private let placesRepository: PlacesRepositoryProtocol

    private var cancellables = Set<AnyCancellable>()
    private var locationFetcher: OneShotLocationFetcher?
    
    // Search UI State
    @Published var searchQuery: String = ""
    @Published var searchResults: [MKLocalSearchCompletion] = []
    
    // Map Context
    @Published var cameraPosition: MapCameraPosition = .automatic
    @Published var selectedCoordinate: CLLocationCoordinate2D?
    @Published var selectedPlaceName: String = ""

    // Nếu user đã chọn tọa độ thủ công (tap map / chọn search result) thì không để `centerOnUser()`
    // async override lại `selectedCoordinate` sau đó.
    private var didSelectCoordinateManually: Bool = false
    
    init(
        searchService: LocalSearchServiceProtocol = LocalSearchService(),
        placesRepository: PlacesRepositoryProtocol? = nil
    ) {
        self.searchService = searchService
        self.placesRepository = placesRepository ?? PlacesRepository()
        super.init()
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Debounce search keystrokes to optimize MKLocalSearchCompleter
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.searchService.search(query: query)
            }
            .store(in: &cancellables)
            
        searchService.searchResults
            .receive(on: RunLoop.main)
            .sink { [weak self] results in
                self?.searchResults = results
            }
            .store(in: &cancellables)
    }
    
    func mapTapped(coordinate: CLLocationCoordinate2D) {
        didSelectCoordinateManually = true
        selectedCoordinate = coordinate
        reverseGeocodeAndUpdateSearch(coordinate: coordinate)
    }

    private func reverseGeocodeAndUpdateSearch(coordinate: CLLocationCoordinate2D) {
        Task { @MainActor in
            do {
                if let name = try await searchService.geocode(coordinate: coordinate) {
                    selectedPlaceName = name
                    searchQuery = name
                } else {
                    selectedPlaceName = String(localized: "unknown_location")
                }
            } catch {
                selectedPlaceName = String(localized: "unknown_location")
            }
        }
    }
    
    func resultSelected(_ completion: MKLocalSearchCompletion) {
        didSelectCoordinateManually = true
        let searchRequest = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { [weak self] response, error in
            guard let self = self, let coordinate = response?.mapItems.first?.placemark.coordinate else { return }
            
            DispatchQueue.main.async {
                self.selectedCoordinate = coordinate
                self.selectedPlaceName = completion.title
                self.searchQuery = completion.title
                
                // Fly to coordinate instantly
                self.cameraPosition = .region(MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)))
            }
        }
    }
    
    func centerOnUser() {
        cameraPosition = .userLocation(fallback: .automatic)
        let fetcher = OneShotLocationFetcher()
        locationFetcher = fetcher
        fetcher.fetchCoordinate { [weak self] coordinate in
            guard let self else { return }
            defer { self.locationFetcher = nil }
            guard let coordinate else { return }
            DispatchQueue.main.async {
                guard self.didSelectCoordinateManually == false else { return }
                self.selectedCoordinate = coordinate
                self.reverseGeocodeAndUpdateSearch(coordinate: coordinate)
            }
        }
    }
    
    /// `true` khi đã có tọa độ và ghi DB thành công.
    @discardableResult
    func savePlace(withName name: String) -> Bool {
        guard let location = selectedCoordinate else { return false }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? (selectedPlaceName.isEmpty ? String(localized: "unknown_short") : selectedPlaceName) : trimmed

        let newPlace = PlaceModel(name: finalName, latitude: location.latitude, longitude: location.longitude)
        return placesRepository.addPlace(newPlace)
    }
    
    func clearState() {
        self.searchQuery = ""
        self.searchResults = []
        self.selectedCoordinate = nil
        self.selectedPlaceName = ""
        self.didSelectCoordinateManually = false
        self.cancellables.removeAll()
    }
    
    // Dynamic Icon Logic Provider
    func getIconData(for completion: MKLocalSearchCompletion) -> (name: String, color: Color) {
        let text = (completion.title + " " + completion.subtitle).lowercased()
        
        if text.contains("đại học") || text.contains("trường") || text.contains("học viện") || text.contains("school") || text.contains("college") {
            return ("graduationcap.fill", .brown)
        } else if text.contains("bệnh viện") || text.contains("y tế") || text.contains("hospital") || text.contains("clinic") || text.contains("nha khoa") {
            return ("cross.case.fill", .red)
        } else if text.contains("ngân hàng") || text.contains("bank") || text.contains("atm") {
            return ("building.columns.fill", .blue)
        } else if text.contains("cà phê") || text.contains("cafe") || text.contains("coffee") {
            return ("cup.and.saucer.fill", .orange)
        } else if text.contains("nhà hàng") || text.contains("quán") || text.contains("restaurant") || text.contains("food") {
            return ("fork.knife", .orange)
        } else if text.contains("sân bay") || text.contains("airport") || text.contains("flight") {
            return ("airplane", .cyan)
        } else if text.contains("chợ") || text.contains("siêu thị") || text.contains("mart") || text.contains("market") || text.contains("shop") || text.contains("mall") {
            return ("cart.fill", .green)
        } else if text.contains("công viên") || text.contains("park") || text.contains("vườn") || text.contains("garden") {
            return ("tree.fill", .green)
        } else {
            return ("mappin", .gray)
        }
    }
}
