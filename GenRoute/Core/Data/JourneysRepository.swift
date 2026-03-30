import Foundation
import SwiftData

protocol JourneysRepositoryProtocol {
    func fetchJourneys() -> [JourneyModel]
    @discardableResult
    func addJourney(from summary: TripResultSummary) -> Bool
    func deleteJourney(_ journey: JourneyModel)
}

final class JourneysRepository: JourneysRepositoryProtocol {
    private let context: ModelContext

    init() {
        context = AppModelContainer.shared.mainContext
    }

    init(context: ModelContext) {
        self.context = context
    }

    func fetchJourneys() -> [JourneyModel] {
        let descriptor = FetchDescriptor<JourneyModel>(sortBy: [SortDescriptor(\.completedAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func addJourney(from summary: TripResultSummary) -> Bool {
        let model = JourneyModel(summary: summary)
        context.insert(model)
        do {
            try context.save()
            return true
        } catch {
            assertionFailure("SwiftData save failed: \(error.localizedDescription)")
            return false
        }
    }

    func deleteJourney(_ journey: JourneyModel) {
        context.delete(journey)
        try? context.save()
    }
}

