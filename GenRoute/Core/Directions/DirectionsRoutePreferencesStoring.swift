import Foundation

/// Lưu / đọc tùy chọn chỉ đường (DIP — ViewModel phụ thuộc protocol).
protocol DirectionsRoutePreferencesStoring: AnyObject {
    func loadOptions() -> DirectionsRouteOptions
    func saveOptions(_ options: DirectionsRouteOptions)
}

final class UserDefaultsDirectionsRoutePreferencesStore: DirectionsRoutePreferencesStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "directions_route_options_v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadOptions() -> DirectionsRouteOptions {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(DirectionsRouteOptions.self, from: data) else {
            return .default
        }
        return decoded
    }

    func saveOptions(_ options: DirectionsRouteOptions) {
        guard let data = try? JSONEncoder().encode(options) else { return }
        defaults.set(data, forKey: key)
    }
}
