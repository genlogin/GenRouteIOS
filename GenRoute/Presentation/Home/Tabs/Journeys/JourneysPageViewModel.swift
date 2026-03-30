import Foundation
import Combine
import SwiftUI

@MainActor
final class JourneysPageViewModel: BaseViewModel {
    @Published private(set) var journeys: [JourneyModel] = []

    private let journeysRepository: JourneysRepositoryProtocol

    init(journeysRepository: JourneysRepositoryProtocol? = nil) {
        self.journeysRepository = journeysRepository ?? JourneysRepository()
        super.init()
    }

    func loadJourneys() {
        journeys = journeysRepository.fetchJourneys()
    }

    func deleteJourneys(at offsets: IndexSet) {
        for index in offsets {
            journeysRepository.deleteJourney(journeys[index])
        }
        journeys.remove(atOffsets: offsets)
    }
}
