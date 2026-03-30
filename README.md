# GenRoute (iOS)

GenRoute là app iOS (SwiftUI + MapKit) giúp bạn **lưu địa điểm yêu thích**, **tính lộ trình** giữa các điểm đã lưu và **điều hướng** (mô phỏng ở chế độ dev hoặc dùng GPS thật), sau đó **lưu lịch sử hành trình** và xem lại thống kê.

## Tính năng chính

- **Ride**
  - Lưu danh sách địa điểm yêu thích (SwiftData).
  - Đổi tên / xoá / sắp xếp lại địa điểm.
  - Mở màn **Directions** để tính route giữa 2 điểm (ưu tiên GPS hiện tại làm điểm bắt đầu; fallback sang 1 place đã lưu khác nếu chưa có GPS).
- **Directions**
  - Vẽ route bằng MapKit.
  - Điều hướng turn-by-turn (đọc `MKRoute.Step.instructions`).
  - Tuỳ chọn route: phương tiện + tránh cao tốc/thu phí/phà/đường xấu.
  - Dev mode có panel mô phỏng tốc độ.
- **Journeys**
  - Lưu “ảnh chụp” kết quả chuyến đi và hiển thị danh sách hành trình đã hoàn thành.
- **Đa ngôn ngữ**
  - App dùng **String Catalog**: `GenRoute/Resources/Localizable.xcstrings`.

## Yêu cầu

- **Xcode**: 26.x (project tạo bằng Xcode 26.x)
- **iOS Deployment Target**: 17.0

## Chạy project

1. Mở `GenRoute.xcodeproj` bằng Xcode.
2. Chọn scheme **GenRoute**.
3. Run trên iOS Simulator hoặc thiết bị thật.

## Mock location (GPX)

Repo có file GPX để giả lập vị trí trên Simulator:

- `GenRoute/Resources/MockLocation.gpx`

Trong Xcode: **Debug** → **Simulate Location** → chọn file GPX này.

## Cấu trúc thư mục

```
GenRoute/
  Core/
    Base/              # BaseViewModel, AppString
    Data/              # SwiftData container + repositories
    Directions/        # Routing, formatting, navigation helpers
    Location/          # Location services (one-shot + live)
    Navigation/        # AppRouter (splash → language → onboarding → home)
  Presentation/
    Splash/            # SplashScreen + ViewModel
    Language/          # LanguageScreen + ViewModel
    Onboarding/        # OnboardingScreen + ViewModel
    Home/              # TabView: Ride / Journeys / Settings
    PlaceEditor/       # Chọn vị trí trên map + search + lưu place
    Directions/        # DirectionsScreen + settings sheet
    TripResult/        # Màn kết quả chuyến đi (map + stats)
  Resources/
    Localizable.xcstrings
    MockLocation.gpx
Assets.xcassets/
GenRouteApp.swift
ContentView.swift
```

## Kiến trúc & luồng màn hình

- **Entry point**: `GenRouteApp` → `ContentView`
- **Routing đơn giản**: `AppRouter` quản lý `AppRoute`:
  - `splash` → `language` (lần đầu mở app) → `onboarding` → `home`
  - Lưu state lần đầu chạy bằng `@AppStorage("hasFirstLaunched")`

## Lưu trữ dữ liệu (SwiftData)

- Container dùng chung: `AppModelContainer.shared` (tránh tạo nhiều DB lệch nhau).
- Repository:
  - `PlacesRepository` (PlaceModel)
  - `JourneysRepository` (JourneyModel)

## Đa ngôn ngữ (i18n)

- String table chính: `GenRoute/Resources/Localizable.xcstrings`
- Trong SwiftUI:
  - Dùng `LocalizedStringKey` qua `AppString.*` cho UI text.
  - Dùng `String(localized:)` cho string ở layer ViewModel/formatting.

## Ghi chú

- Một số phần routing/avoid (ferry/poor-road) dùng heuristic vì MapKit không có flag đầy đủ cho mọi trường hợp.

