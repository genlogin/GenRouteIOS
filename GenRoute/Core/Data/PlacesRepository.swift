import Foundation
import SwiftData

protocol PlacesRepositoryProtocol {
    func fetchPlaces() -> [PlaceModel]
    func fetchPlace(byId id: UUID) -> PlaceModel?
    /// `false` nếu không insert được (lỗi SwiftData).
    @discardableResult
    func addPlace(_ place: PlaceModel) -> Bool
    func deletePlace(_ place: PlaceModel)
    func updatePlaceName(_ place: PlaceModel, newName: String)
}

final class PlacesRepository: PlacesRepositoryProtocol {
    private let context: ModelContext

    /// Dùng `mainContext` của container để insert/fetch cùng luồng với SwiftUI (tránh `ModelContext(container)` mới lệch dữ liệu).
    init() {
        context = AppModelContainer.shared.mainContext
    }

    init(context: ModelContext) {
        self.context = context
    }

    func fetchPlaces() -> [PlaceModel] {
        let descriptor = FetchDescriptor<PlaceModel>(sortBy: [SortDescriptor(\.timestamp, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func fetchPlace(byId id: UUID) -> PlaceModel? {
        let predicate = #Predicate<PlaceModel> { $0.id == id }
        var descriptor = FetchDescriptor<PlaceModel>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func addPlace(_ place: PlaceModel) -> Bool {
        context.insert(place)
        do {
            try context.save()
            return true
        } catch {
            assertionFailure("SwiftData save failed: \(error.localizedDescription)")
            return false
        }
    }

    func deletePlace(_ place: PlaceModel) {
        context.delete(place)
        try? context.save()
    }

    func updatePlaceName(_ place: PlaceModel, newName: String) {
        place.name = newName
        try? context.save()
    }
}
