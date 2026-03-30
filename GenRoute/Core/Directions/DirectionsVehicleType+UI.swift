import Foundation

extension DirectionsVehicleType {
    /// SF Symbol cho tóm tắt tuyến và picker (đồng bộ với lựa chọn người dùng).
    var routeSummarySystemImage: String {
        switch self {
        case .bicycle:
            return "bicycle"
        case .motorcycle:
            return "motorcycle"
        }
    }
}
