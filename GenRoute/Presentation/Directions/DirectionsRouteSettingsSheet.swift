import SwiftUI

struct DirectionsRouteSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: DirectionsRouteOptions
    let onApply: (DirectionsRouteOptions) -> Void

    init(initial: DirectionsRouteOptions, onApply: @escaping (DirectionsRouteOptions) -> Void) {
        _draft = State(initialValue: initial)
        self.onApply = onApply
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker(selection: $draft.vehicle) {
                        Text(AppString.directionsVehicleBicycle).tag(DirectionsVehicleType.bicycle)
                        Text(AppString.directionsVehicleMotorcycle).tag(DirectionsVehicleType.motorcycle)
                    } label: {
                        Label(
                            AppString.directionsVehicleTypeLabel,
                            systemImage: draft.vehicle.routeSummarySystemImage
                        )
                    }
                } header: {
                    Text(AppString.directionsVehicleSection)
                }

                Section {
                    Toggle(AppString.directionsAvoidHighway, isOn: $draft.avoidHighways)
                    Toggle(AppString.directionsAvoidToll, isOn: $draft.avoidTolls)
                    Toggle(AppString.directionsAvoidFerry, isOn: $draft.avoidFerries)
                    Toggle(AppString.directionsAvoidPoorRoad, isOn: $draft.avoidPoorRoads)
                } header: {
                    Text(AppString.directionsAvoidSection)
                } footer: {
                    Text(AppString.directionsSettingsFooterNote)
                        .font(.footnote)
                }
            }
            .navigationTitle(AppString.directionsSettingsTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AppString.directionsSettingsCancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AppString.directionsSettingsApply) {
                        onApply(draft)
                        dismiss()
                    }
                }
            }
        }
    }
}
