import SwiftUI

/// Animation dùng chung — **cùng thời lượng/curve** đã có trong app (không đổi hành vi hiển thị).
enum NativeMotion {
    /// `DirectionsScreenViewModel.followNavigationCamera`
    static let directionsMapCamera = Animation.linear(duration: 0.22)

    /// `DirectionsScreenViewModel.focusCameraOnStart`
    static let directionsFocusStart = Animation.easeInOut(duration: 0.45)

    /// `DirectionsScreenViewModel.resetMapHeadingToNorth`
    static let directionsNorthUp = Animation.easeInOut(duration: 0.35)

    /// La bàn trên `DirectionsScreen`
    static let directionsCompassRotation = Animation.linear(duration: 0.12)

    /// Mini map preview transition (xuất hiện / biến mất).
    static let miniMapSmooth = Animation.easeOut(duration: 0.22)
}
