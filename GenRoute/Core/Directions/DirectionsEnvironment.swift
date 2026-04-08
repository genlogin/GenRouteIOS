import Foundation

/// Cấu hình build cho màn chỉ đường. Đổi **một chỗ** khi test: `isDev = true` → panel tốc độ + giả lập GPS dọc tuyến.
enum DirectionsEnvironment {
    /// `true`: hiện panel dev (slider km/h) + nút Start chạy **giả lập** dọc polyline.  
    /// `false`: release — Start theo **vị trí thật** (CLLocation).
    static let isDev: Bool = true

    /// Valhalla base URL (Android đang gọi `POST /route` với `format=osrm`).
    /// Bạn có thể trỏ về Valhalla self-host để đảm bảo output giống Android/hardware.
    static let valhallaBaseURL: URL = URL(string: "https://valhalla1.openstreetmap.de")!
}
