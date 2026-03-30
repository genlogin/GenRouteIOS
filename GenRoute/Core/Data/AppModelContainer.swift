import Foundation
import SwiftData

/// Một `ModelContainer` dùng chung cho toàn app để tránh nhiều DB lệch nhau khi mỗi `PlacesRepository()` tạo container riêng.
enum AppModelContainer {
    static let shared: ModelContainer = {
        do {
            return try ModelContainer(for: PlaceModel.self, JourneyModel.self)
        } catch {
            fatalError("SwiftData ModelContainer failed: \(error.localizedDescription)")
        }
    }()
}
