import CoreLocation
import Foundation

enum RouteSummaryFormatting {
    private static let distanceFormatter: MeasurementFormatter = {
        let f = MeasurementFormatter()
        f.locale = .current
        f.unitOptions = .providedUnit
        f.unitStyle = .short
        return f
    }()

    private static let speedFormatter: MeasurementFormatter = {
        let f = MeasurementFormatter()
        f.locale = .current
        f.unitOptions = .providedUnit
        f.unitStyle = .short
        f.numberFormatter.maximumFractionDigits = 1
        f.numberFormatter.minimumFractionDigits = 1
        return f
    }()

    static func distance(meters: CLLocationDistance) -> String {
        if meters.isNaN || meters.isInfinite { return String(localized: "route_duration_na") }
        let m = max(0, meters)
        if m >= 1000 {
            return distanceFormatter.string(from: Measurement(value: m / 1000, unit: UnitLength.kilometers))
        }
        return distanceFormatter.string(from: Measurement(value: m, unit: UnitLength.meters))
    }

    static func duration(seconds: TimeInterval) -> String {
        if seconds < 60 {
            return String(localized: "route_duration_lt1min")
        }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        if seconds >= 3600 {
            formatter.allowedUnits = [.hour, .minute]
        } else {
            formatter.allowedUnits = [.minute]
        }
        return formatter.string(from: seconds) ?? String(localized: "route_duration_na")
    }

    /// Hiển thị tốc độ (km/h).
    static func speedKmh(_ kmh: Double) -> String {
        if kmh.isNaN || kmh.isInfinite { return String(localized: "route_speed_na") }
        let k = max(0, kmh)
        return speedFormatter.string(from: Measurement(value: k, unit: UnitSpeed.kilometersPerHour))
    }
}
