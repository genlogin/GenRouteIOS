import Foundation

@MainActor
final class TripResultViewModel: BaseViewModel {
    let summary: TripResultSummary

    init(summary: TripResultSummary) {
        self.summary = summary
        super.init()
    }

    /// Kiểu phụ đề trong mockup: "Mar 30 2026 at 10:52"
    var completedAtSubtitleFormatted: String {
        let f = DateFormatter()
        f.locale = .current
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: summary.completedAt)
    }

    var distanceTraveledDisplay: String {
        RouteSummaryFormatting.distance(meters: summary.distanceTraveledMeters)
    }

    var movingClockMMSS: String {
        Self.clockMMSS(seconds: summary.movingDurationSeconds)
    }

    var elapsedClockMMSS: String {
        Self.clockMMSS(seconds: summary.elapsedDurationSeconds)
    }

    var averageSpeedDisplay: String {
        RouteSummaryFormatting.speedKmh(summary.averageSpeedKmh)
    }

    var maxSpeedDisplay: String {
        RouteSummaryFormatting.speedKmh(summary.maxSpeedKmh)
    }

    private static func clockMMSS(seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let m = total / 60
        let s = total % 60
        return String(format: "%02d:%02d", m, s)
    }

    // Speed formatting is centralized in `RouteSummaryFormatting` for localization & unit style.
}
