import Foundation

class OnboardingScreenViewModel: BaseViewModel {
    private var onComplete: (() -> Void)?
    
    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }
    
    func finishOnboarding() {
        self.onComplete?()
    }
}
