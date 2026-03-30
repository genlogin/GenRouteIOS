import SwiftUI
import MapKit

struct PlaceEditorScreen: View {
    @StateObject var viewModel: PlaceEditorScreenViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var sheetHeight: PresentationDetent = .height(90)
    @FocusState private var isSearchFocused: Bool
    @State private var showSaveDialog: Bool = false
    @State private var customName: String = ""
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            
            // Map Fullscreen
            MapReader { reader in
                Map(position: $viewModel.cameraPosition) {
                    UserAnnotation()
                    
                    if let coord = viewModel.selectedCoordinate {
                        Annotation(viewModel.selectedPlaceName, coordinate: coord) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.red)
                                .background(Circle().fill(Color.white))
                        }
                    }
                }
                .onTapGesture(coordinateSpace: .local) { location in
                    if let coordinate = reader.convert(location, from: .local) {
                        viewModel.mapTapped(coordinate: coordinate)
                    }
                }
            }
            .ignoresSafeArea()
            
            // Top Left Close Button
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color(UIColor.systemGray), .white)
                    .font(.system(size: 32))
                    .shadow(radius: 4)
            }
            .padding()
            .padding(.top, 44) // Stay below Dynamic Island/notch
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Interaction Overlays - Vertical Top Right
            VStack(spacing: 20) {
                Button(action: {
                    customName = viewModel.selectedPlaceName
                    showSaveDialog = true
                }) {
                    Text(AppString.mapEditorSave)
                        .font(.headline)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 20)
                        .background(viewModel.selectedCoordinate == nil ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                }
                .disabled(viewModel.selectedCoordinate == nil)
                
                Button(action: {
                    withAnimation {
                        viewModel.centerOnUser()
                    }
                }) {
                    Image(systemName: "location.fill")
                        .font(.title2)
                        .padding()
                        .background(Color.white)
                        .foregroundColor(.blue)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
            }
            .padding()
            .padding(.top, 40) // Stay away from system notch
            
        }
        .sheet(isPresented: .constant(true)) {
            // Interactive Search Bottom Sheet
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 40, height: 4)
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                
                if sheetHeight == .height(90) {
                    // Collapsed View (Button disguised as TextField)
                    Button(action: {
                        withAnimation {
                            sheetHeight = .medium
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                                .font(.system(size: 18, weight: .medium))
                            
                            if viewModel.searchQuery.isEmpty {
                                Text(AppString.mapEditorSearchPrompt)
                                    .foregroundColor(.secondary)
                                    .font(.body)
                            } else {
                                Text(viewModel.searchQuery)
                                    .foregroundColor(.primary)
                                    .font(.body)
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(Color(UIColor.tertiarySystemFill))
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                } else {
                    // Expanded View (Real TextField)
                    HStack(spacing: 8) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                                .font(.system(size: 18, weight: .medium))
                            
                            TextField(AppString.mapEditorSearchPrompt, text: $viewModel.searchQuery)
                                .focused($isSearchFocused)
                                
                            if !viewModel.searchQuery.isEmpty {
                                Button(action: {
                                    viewModel.searchQuery = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 16))
                                }
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(Color(UIColor.tertiarySystemFill))
                        .clipShape(Capsule())
                        
                        Button(action: {
                            withAnimation {
                                sheetHeight = .height(90)
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) // Dismiss Keyboard
                                viewModel.searchQuery = ""
                            }
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.secondary)
                                .padding(8)
                                .background(Color(UIColor.tertiarySystemFill))
                                .clipShape(Circle())
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                }
                
                if sheetHeight != .height(90) {
                    if viewModel.searchQuery.isEmpty {
                        Spacer()
                    } else if viewModel.searchResults.isEmpty {
                        Text(AppString.mapEditorNoResults)
                            .foregroundColor(.gray)
                            .padding(.top, 40)
                        Spacer()
                    } else {
                        List(viewModel.searchResults, id: \.self) { result in
                            Button(action: {
                                viewModel.resultSelected(result)
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) // Dismiss Keyboard
                                sheetHeight = .height(90) // Snap back to lower height
                            }) {
                                let iconData = viewModel.getIconData(for: result)
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(iconData.color.opacity(0.8))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: iconData.name)
                                            .foregroundColor(.white)
                                            .font(.system(size: 16))
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.title)
                                            .font(.system(.body, design: .default))
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        
                                        if !result.subtitle.isEmpty {
                                            Text(result.subtitle)
                                                .font(.system(.subheadline))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                            }
                        }
                        .listStyle(.plain)
                    }
                } else {
                    Spacer()
                }
            }
            .alert(AppString.mapEditorSaveTitle, isPresented: $showSaveDialog) {
                TextField(AppString.mapEditorSaveName, text: $customName)
                Button(AppString.mapEditorDismiss, role: .cancel) { }
                Button(AppString.mapEditorSave) {
                    guard viewModel.savePlace(withName: customName) else { return }
                    viewModel.clearState()
                    dismiss()
                }
            } message: {
                Text(AppString.mapEditorSaveDesc)
            }
            .presentationDetents([.height(90), .medium, .large], selection: $sheetHeight)
            .onChange(of: sheetHeight) { height in
                if height != .height(90) {
                    isSearchFocused = true
                } else {
                    isSearchFocused = false
                }
            }
            .presentationBackground(.thickMaterial)
            .presentationCornerRadius(32)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium)) // Allows tapping the map behind it!
            .interactiveDismissDisabled() // Keeps it glued permanently
        }
        .navigationBarHidden(true)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    viewModel.centerOnUser()
                }
            }
        }
    }
}
