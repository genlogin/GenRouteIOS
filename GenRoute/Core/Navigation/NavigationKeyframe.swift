import CoreLocation
import Foundation

struct NavigationKeyframe: Sendable {
    let coordinate: CLLocationCoordinate2D
    /// Heading độ \(0...360). `nil` nếu chưa xác định.
    let headingDegrees: CLLocationDirection?
    /// Quãng đường đã đi dọc tuyến (mét).
    let traveledMeters: CLLocationDistance
    /// Timestamp của keyframe.
    let timestamp: TimeInterval

    init(
        coordinate: CLLocationCoordinate2D,
        headingDegrees: CLLocationDirection?,
        traveledMeters: CLLocationDistance,
        timestamp: TimeInterval = Date().timeIntervalSince1970
    ) {
        self.coordinate = coordinate
        self.headingDegrees = headingDegrees
        self.traveledMeters = traveledMeters
        self.timestamp = timestamp
    }
}

