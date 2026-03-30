import Foundation
import MapKit
import Combine

protocol LocalSearchServiceProtocol {
    var searchResults: AnyPublisher<[MKLocalSearchCompletion], Never> { get }
    func search(query: String)
    func geocode(coordinate: CLLocationCoordinate2D) async throws -> String?
}

class LocalSearchService: NSObject, LocalSearchServiceProtocol, MKLocalSearchCompleterDelegate {
    private let completer = MKLocalSearchCompleter()
    
    private let searchResultsSubject = CurrentValueSubject<[MKLocalSearchCompletion], Never>([])
    var searchResults: AnyPublisher<[MKLocalSearchCompletion], Never> {
        searchResultsSubject.eraseToAnyPublisher()
    }
    
    override init() {
        super.init()
        completer.delegate = self
        // Prioritize points of interest (businesses, landmarks) over raw coordinates
        completer.resultTypes = .pointOfInterest
    }
    
    func search(query: String) {
        if query.isEmpty {
            searchResultsSubject.send([])
            return
        }
        completer.queryFragment = query
    }
    
    // MARK: - MKLocalSearchCompleterDelegate
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        searchResultsSubject.send(completer.results)
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        searchResultsSubject.send([])
    }
    
    // MARK: - Reverse Geocoding
    func geocode(coordinate: CLLocationCoordinate2D) async throws -> String? {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        
        if let placemark = placemarks.first {
            // Join descriptive names together
            let components = [placemark.name, placemark.locality].compactMap { $0 }
            return components.joined(separator: ", ")
        }
        return nil
    }
}
