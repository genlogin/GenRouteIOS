import SwiftUI

struct JourneysPage: View {
    @StateObject var viewModel: JourneysPageViewModel
    
    var body: some View {
        NavigationStack {
            List {
                if viewModel.journeys.isEmpty {
                    Text(AppString.journeyEmptyList)
                        .foregroundColor(.gray)
                } else {
                    ForEach(viewModel.journeys) { journey in
                        NavigationLink {
                            TripResultScreen(viewModel: TripResultViewModel(summary: journey.summary))
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(journey.recordName)
                                    .font(.body.weight(.semibold))
                                Text(journey.completedAt, style: .date)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text("\(journey.startPlaceName) → \(journey.endPlaceName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete(perform: viewModel.deleteJourneys)
                }
            }
            .navigationTitle(AppString.tabJourneys)
        }
        .onAppear {
            viewModel.loadJourneys()
        }
    }
}
