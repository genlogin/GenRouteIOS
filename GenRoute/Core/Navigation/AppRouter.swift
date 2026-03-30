import Foundation
import SwiftUI
import Combine

enum AppRoute {
    case splash
    case language
    case onboarding
    case home
}

class AppRouter: ObservableObject {
    @Published var currentRoute: AppRoute = .splash
    @AppStorage("hasFirstLaunched") var hasFirstLaunched: Bool = true
    
    func navigateAfterSplash() {
        if hasFirstLaunched {
            currentRoute = .language
        } else {
            currentRoute = .home
        }
    }
    
    func navigateToOnboarding() {
        currentRoute = .onboarding
    }
    
    func navigateToHome() {
        hasFirstLaunched = false
        currentRoute = .home
    }
}
