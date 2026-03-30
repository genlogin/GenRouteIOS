import CoreLocation
import MapKit

enum TripResultMapGeometry {
    /// Vùng bản đồ bao hai điểm, tương tự fit route trên màn chỉ đường.
    static func fittingRegion(for summary: TripResultSummary, paddingFactor: Double = 1.48) -> MKCoordinateRegion {
        let a = CLLocationCoordinate2D(latitude: summary.mapStartLatitude, longitude: summary.mapStartLongitude)
        let b = CLLocationCoordinate2D(latitude: summary.mapEndLatitude, longitude: summary.mapEndLongitude)
        let latMin = min(a.latitude, b.latitude)
        let latMax = max(a.latitude, b.latitude)
        let lonMin = min(a.longitude, b.longitude)
        let lonMax = max(a.longitude, b.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (latMin + latMax) / 2,
            longitude: (lonMin + lonMax) / 2
        )
        var latDelta = max((latMax - latMin) * paddingFactor, 0.012)
        var lonDelta = max((lonMax - lonMin) * paddingFactor, 0.012)
        if latDelta.isNaN || latDelta == 0 { latDelta = 0.02 }
        if lonDelta.isNaN || lonDelta == 0 { lonDelta = 0.02 }
        return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta))
    }

    static func startCoordinate(from summary: TripResultSummary) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: summary.mapStartLatitude, longitude: summary.mapStartLongitude)
    }

    static func endCoordinate(from summary: TripResultSummary) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: summary.mapEndLatitude, longitude: summary.mapEndLongitude)
    }
}
