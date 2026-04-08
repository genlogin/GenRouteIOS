import CoreLocation
import Foundation

/// Decode polyline6 (Google Encoded Polyline, precision 1e-6) giống `PolylineUtils.decode(geom, 6)` bên Android.
enum Polyline6 {
    static func decode(_ encoded: String) -> [CLLocationCoordinate2D] {
        guard !encoded.isEmpty else { return [] }
        let bytes = Array(encoded.utf8)
        var idx = 0
        var lat = 0
        var lon = 0
        var out: [CLLocationCoordinate2D] = []
        out.reserveCapacity(encoded.count / 4)

        func decodeValue() -> Int? {
            var result = 0
            var shift = 0
            while idx < bytes.count {
                let b = Int(bytes[idx]) - 63
                idx += 1
                result |= (b & 0x1F) << shift
                shift += 5
                if b < 0x20 { break }
            }
            let delta = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
            return delta
        }

        while idx < bytes.count {
            guard let dLat = decodeValue(), let dLon = decodeValue() else { break }
            lat += dLat
            lon += dLon
            out.append(
                CLLocationCoordinate2D(
                    latitude: Double(lat) / 1_000_000.0,
                    longitude: Double(lon) / 1_000_000.0
                )
            )
        }

        return out
    }
}

