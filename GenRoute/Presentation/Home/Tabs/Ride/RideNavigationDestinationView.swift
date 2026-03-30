import SwiftUI

/// Tách `navigationDestination` để tránh SwiftUI type-check quá nặng trong `RidePage.body`.
struct RideNavigationDestinationView: View {
    let destination: RideNavigationDestination
    @Binding var path: NavigationPath
    private let journeysRepository: JourneysRepositoryProtocol = JourneysRepository()

    var body: some View {
        switch destination {
        case .directions(let payload):
            DirectionsScreen(
                viewModel: DirectionsScreenViewModel(
                    navigation: payload,
                    onTripCompleted: { summary in
                        _ = journeysRepository.addJourney(from: summary)
                        path.removeLast()
                        path.append(RideNavigationDestination.tripResult(summary))
                    }
                )
            )
        case .tripResult(let summary):
            TripResultScreen(viewModel: TripResultViewModel(summary: summary))
        }
    }
}
