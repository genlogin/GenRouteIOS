import Foundation
import CoreLocation

// MARK: - Protocol
protocol LocationServiceProtocol {
    var authorizationStatus: CLAuthorizationStatus { get }
    func requestWhenInUseAuthorization(completion: @escaping (Bool) -> Void)
}

// MARK: - Implementation
class LocationService: NSObject, LocationServiceProtocol, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var authCompletion: ((Bool) -> Void)?
    
    override init() {
        super.init()
        locationManager.delegate = self
    }
    
    var authorizationStatus: CLAuthorizationStatus {
        return locationManager.authorizationStatus
    }
    
    func requestWhenInUseAuthorization(completion: @escaping (Bool) -> Void) {
        let status = locationManager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            completion(true)
        } else if status == .denied || status == .restricted {
            completion(false)
        } else {
            self.authCompletion = completion
            locationManager.requestWhenInUseAuthorization()
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status != .notDetermined {
            let granted = (status == .authorizedWhenInUse || status == .authorizedAlways)
            authCompletion?(granted)
            authCompletion = nil
        }
    }
}
