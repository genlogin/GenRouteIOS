import SwiftUI

struct ContentView: View {
    @StateObject private var router = AppRouter()
    
    var body: some View {
        Group {
            switch router.currentRoute {
            case .splash:
                SplashScreen(viewModel: SplashScreenViewModel(onFinish: {
                    withAnimation {
                        router.navigateAfterSplash()
                    }
                }))
                .transition(.opacity)
            case .language:
                LanguageScreen(viewModel: LanguageScreenViewModel(onNext: {
                    withAnimation {
                        router.navigateToOnboarding()
                    }
                }))
                .transition(.move(edge: .trailing))
            case .onboarding:
                OnboardingScreen(viewModel: OnboardingScreenViewModel(onComplete: {
                    withAnimation {
                        router.navigateToHome()
                    }
                }))
                .transition(.move(edge: .trailing))
            case .home:
                HomeScreen(viewModel: HomeScreenViewModel())
                .transition(.opacity)
            }
        }
    }
}

#Preview {
    ContentView()
}
