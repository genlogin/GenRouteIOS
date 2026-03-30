import SwiftUI

struct RidePage: View {
    @StateObject var viewModel: RidePageViewModel

    @State private var navigationPath = NavigationPath()
    
    @State private var placeToEdit: PlaceModel? = nil
    @State private var editName: String = ""
    @State private var indexToDelete: IndexSet? = nil
    @State private var showDeleteConfirm: Bool = false
    @State private var showEditDialog: Bool = false
    @State private var showDirectionsNeedTwoPlaces: Bool = false
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                VStack {
                    if viewModel.savedPlaces.isEmpty {
                        Spacer()
                        VStack(spacing: 20) {
                            Image(systemName: "map.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .foregroundColor(.gray.opacity(0.4))
                            
                            Text(AppString.rideEmptyTitle)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    } else {
                        List {
                            Section(header: Text(AppString.rideFavoritePlaces).font(.caption).foregroundColor(.gray)) {
                                ForEach(viewModel.savedPlaces) { place in
                                    HStack(spacing: 16) {
                                        Group {
                                            if let payload = viewModel.directionsNavigation(to: place) {
                                                NavigationLink(value: RideNavigationDestination.directions(payload)) {
                                                    ridePlaceRowContent(place: place)
                                                }
                                                .buttonStyle(.plain)
                                            } else {
                                                Button {
                                                    showDirectionsNeedTwoPlaces = true
                                                } label: {
                                                    ridePlaceRowContent(place: place)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }

                                        Button(action: {
                                            editName = place.name
                                            placeToEdit = place
                                            showEditDialog = true
                                        }) {
                                            Image(systemName: "pencil.circle.fill")
                                                .font(.system(size: 24, weight: .semibold))
                                                .foregroundColor(Color.blue.opacity(0.8))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .onDelete { indexSet in
                                    indexToDelete = indexSet
                                    showDeleteConfirm = true
                                }
                                .onMove { source, destination in
                                    viewModel.movePlaces(from: source, to: destination)
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                    Spacer()
                }
            }
            .navigationTitle(AppString.tabRide)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !viewModel.savedPlaces.isEmpty {
                        EditButton()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.addPlaceTapped()
                    }) {
                        Label(AppString.rideAddPlace, systemImage: "plus.circle.fill")
                    }
                }
            }
            .fullScreenCover(isPresented: $viewModel.showPlaceEditor, onDismiss: {
                viewModel.loadPlaces()
            }) {
                PlaceEditorScreen(viewModel: PlaceEditorScreenViewModel())
            }
            .alert(isPresented: $viewModel.showPermissionAlert) {
                Alert(
                    title: Text(AppString.ridePermissionTitle),
                    message: Text(AppString.ridePermissionDesc),
                    dismissButton: .default(Text(AppString.rideOk))
                )
            }
            .onAppear {
                viewModel.loadPlaces()
                viewModel.refreshCurrentUserCoordinate()
            }
            .navigationDestination(for: RideNavigationDestination.self) { destination in
                RideNavigationDestinationView(destination: destination, path: $navigationPath)
            }
        }
        .alert(AppString.rideEditTitle, isPresented: $showEditDialog) {
            TextField(AppString.mapEditorSaveName, text: $editName)
            Button(AppString.rideCancel, role: .cancel) { }
            Button(AppString.rideEditSave) {
                if let place = placeToEdit {
                    viewModel.updatePlaceName(for: place, newName: editName)
                }
            }
        }
        .alert(AppString.rideDeleteConfirmTitle, isPresented: $showDeleteConfirm) {
            Button(AppString.rideDelete, role: .destructive) {
                if let indexSet = indexToDelete {
                    withAnimation {
                        viewModel.deletePlaces(at: indexSet)
                    }
                }
            }
            Button(AppString.rideCancel, role: .cancel) { }
        } message: {
            Text(AppString.rideDeleteConfirmDesc)
        }
        .alert(AppString.rideDirectionsNeedTwoPlacesTitle, isPresented: $showDirectionsNeedTwoPlaces) {
            Button(AppString.rideOk, role: .cancel) { }
        } message: {
            Text(AppString.rideDirectionsNeedTwoPlacesMessage)
        }
    }

    @ViewBuilder
    private func ridePlaceRowContent(place: PlaceModel) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "star.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 18))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(String(format: String(localized: "ride_place_lat_lng_format"), place.latitude, place.longitude))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}
