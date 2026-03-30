import CoreLocation
import Foundation

/// Lấy một lần tọa độ GPS (sau khi user bấm “về vị trí của tôi” để đồng bộ điểm lưu với tọa độ thật).
final class OneShotLocationFetcher: NSObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private var completion: ((CLLocationCoordinate2D?) -> Void)?

    func fetchCoordinate(completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        self.completion = completion
        locationManager.delegate = self
        let status = locationManager.authorizationStatus
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.requestLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        default:
            finish(locationManager.location?.coordinate)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        if status == .authorizedAlways || status == .authorizedWhenInUse {
            manager.requestLocation()
        } else if status != .notDetermined {
            finish(manager.location?.coordinate)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        finish(locations.last?.coordinate ?? manager.location?.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(manager.location?.coordinate)
    }

    private func finish(_ coordinate: CLLocationCoordinate2D?) {
        completion?(coordinate)
        completion = nil
        locationManager.delegate = nil
    }
}
