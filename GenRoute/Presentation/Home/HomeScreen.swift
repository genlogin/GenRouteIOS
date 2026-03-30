import SwiftUI

struct HomeScreen: View {
    @StateObject var viewModel: HomeScreenViewModel
    /// Một instance cho tab Ride — tránh tạo ViewModel mới mỗi lần `body` của Home refresh (mất `savedPlaces` / lệch với DB).
    @StateObject private var ridePageViewModel = RidePageViewModel()

    var body: some View {
        TabView {
            RidePage(viewModel: ridePageViewModel)
                .tabItem {
                    Label(AppString.tabRide, systemImage: "car.fill")
                }
            
            JourneysPage(viewModel: JourneysPageViewModel())
                .tabItem {
                    Label(AppString.tabJourneys, systemImage: "list.bullet.rectangle.portrait.fill")
                }
            
            SettingsPage(viewModel: SettingsPageViewModel())
                .tabItem {
                    Label(AppString.tabSettings, systemImage: "gearshape.fill")
                }
        }
        .onAppear {
            viewModel.fetchLocation()
        }
    }
}
