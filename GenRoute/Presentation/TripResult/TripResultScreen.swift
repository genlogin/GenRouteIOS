import MapKit
import SwiftUI

/// Điều phối màn kết quả: map + chrome dưới; toolbar/navigation do hệ thống.
struct TripResultScreen: View {
    @ObservedObject var viewModel: TripResultViewModel

    @State private var cameraPosition: MapCameraPosition
    @State private var selectedRatingIndex: Int?

    init(viewModel: TripResultViewModel) {
        self.viewModel = viewModel
        let region = TripResultMapGeometry.fittingRegion(for: viewModel.summary)
        _cameraPosition = State(initialValue: .region(region))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                TripResultMapLayer(cameraPosition: $cameraPosition, summary: viewModel.summary)

                TripResultBottomChrome(
                    viewModel: viewModel,
                    selectedRatingIndex: $selectedRatingIndex,
                    bottomSafeInset: proxy.safeAreaInsets.bottom
                )
                .zIndex(1)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .navigationTitle(AppString.tripResultTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.automatic, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
    }
}
