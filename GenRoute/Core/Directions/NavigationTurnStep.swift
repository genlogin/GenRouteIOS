import CoreLocation
import Foundation

/// Một bước chỉ dẫn (OSRM/Valhalla hoặc MapKit fallback).
struct NavigationTurnStep: Sendable, Equatable {
    let distance: CLLocationDistance
    let instructions: String
}
