import Foundation
import SwiftData
import CoreLocation

@Model
final class JourneyModel: Identifiable {
    @Attribute(.unique) var id: UUID

    var recordName: String
    var completedAt: Date
    var startToDestinationMeters: Double
    var distanceTraveledMeters: Double
    var movingDurationSeconds: Double
    var elapsedDurationSeconds: Double
    var averageSpeedKmh: Double
    var maxSpeedKmh: Double
    var completionReasonRaw: String

    var mapStartLatitude: Double
    var mapStartLongitude: Double
    var mapEndLatitude: Double
    var mapEndLongitude: Double
    var startPlaceName: String
    var endPlaceName: String

    init(id: UUID = UUID(), summary: TripResultSummary) {
        self.id = id
        self.recordName = summary.recordName
        self.completedAt = summary.completedAt
        self.startToDestinationMeters = summary.startToDestinationMeters
        self.distanceTraveledMeters = summary.distanceTraveledMeters
        self.movingDurationSeconds = summary.movingDurationSeconds
        self.elapsedDurationSeconds = summary.elapsedDurationSeconds
        self.averageSpeedKmh = summary.averageSpeedKmh
        self.maxSpeedKmh = summary.maxSpeedKmh
        self.completionReasonRaw = summary.completionReason.rawValue
        self.mapStartLatitude = summary.mapStartLatitude
        self.mapStartLongitude = summary.mapStartLongitude
        self.mapEndLatitude = summary.mapEndLatitude
        self.mapEndLongitude = summary.mapEndLongitude
        self.startPlaceName = summary.startPlaceName
        self.endPlaceName = summary.endPlaceName
    }

    var summary: TripResultSummary {
        TripResultSummary(
            recordName: recordName,
            completedAt: completedAt,
            startToDestinationMeters: startToDestinationMeters,
            distanceTraveledMeters: distanceTraveledMeters,
            movingDurationSeconds: movingDurationSeconds,
            elapsedDurationSeconds: elapsedDurationSeconds,
            averageSpeedKmh: averageSpeedKmh,
            maxSpeedKmh: maxSpeedKmh,
            completionReason: TripCompletionReason(rawValue: completionReasonRaw) ?? .arrivedAtDestination,
            mapStartLatitude: mapStartLatitude,
            mapStartLongitude: mapStartLongitude,
            mapEndLatitude: mapEndLatitude,
            mapEndLongitude: mapEndLongitude,
            startPlaceName: startPlaceName,
            endPlaceName: endPlaceName
        )
    }
}

