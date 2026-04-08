import CoreLocation
import MapKit

extension MKPolyline {
    static func fromRouteCoordinates(_ coordinates: [CLLocationCoordinate2D]) -> MKPolyline {
        var copy = coordinates
        return MKPolyline(coordinates: &copy, count: copy.count)
    }

    /// Toạ độ lấy từ polyline tuyến (để nội suy quãng đường).
    var routeCoordinates: [CLLocationCoordinate2D] {
        guard pointCount > 0 else { return [] }
        var coords = [CLLocationCoordinate2D](
            repeating: kCLLocationCoordinate2DInvalid,
            count: pointCount
        )
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
