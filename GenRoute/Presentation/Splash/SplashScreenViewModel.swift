import Foundation

class SplashScreenViewModel: BaseViewModel {
    
    private var onFinish: (() -> Void)?
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }
    
    func startTimer() {
        // Wait 5 seconds as per requirement then transition
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.onFinish?()
        }
    }
}
