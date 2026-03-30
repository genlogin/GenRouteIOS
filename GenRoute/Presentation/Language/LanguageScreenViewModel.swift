import Foundation

class LanguageScreenViewModel: BaseViewModel {
    private var onNext: (() -> Void)?
    
    init(onNext: @escaping () -> Void) {
        self.onNext = onNext
    }
    
    func selectLanguageAndProceed() {
        // In a real app, save selected language to AppStorage/UserDefaults here
        self.onNext?()
    }
}
