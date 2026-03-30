import CoreLocation
import Foundation

/// Bản sao giá trị của một địa điểm đã lưu, dùng cho tầng tính tuyến (tách khỏi SwiftData `PlaceModel`).
struct RouteEndpoint: Sendable {
    let id: UUID
    /// Nhãn / tên địa điểm người dùng đã lưu trong DB.
    let name: String
    let coordinate: CLLocationCoordinate2D

    init(id: UUID, name: String, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
    }

    init(place: PlaceModel) {
        self.id = place.id
        self.name = place.name
        self.coordinate = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
    }
}

extension RouteEndpoint: Equatable {
    static func == (lhs: RouteEndpoint, rhs: RouteEndpoint) -> Bool {
        lhs.id == rhs.id && lhs.name == rhs.name
            && lhs.coordinate.latitude == rhs.coordinate.latitude
            && lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}
