import Foundation

/// Cấu hình build cho màn chỉ đường. Đổi **một chỗ** khi test: `isDev = true` → panel tốc độ + giả lập GPS dọc tuyến.
enum DirectionsEnvironment {
    /// `true`: hiện panel dev (slider km/h) + nút Start chạy **giả lập** dọc polyline.  
    /// `false`: release — Start theo **vị trí thật** (CLLocation).
    static let isDev: Bool = true
}
