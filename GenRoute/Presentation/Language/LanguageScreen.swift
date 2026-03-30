import SwiftUI

struct LanguageScreen: View {
    @StateObject var viewModel: LanguageScreenViewModel
    
    var body: some View {
        ZStack {
            Color.teal.opacity(0.8).ignoresSafeArea()
            
            VStack(spacing: 40) {
                Text(AppString.languageSelect)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Button(action: {
                    viewModel.selectLanguageAndProceed()
                }) {
                    Text(AppString.languageEnglishContinue)
                        .font(.headline)
                        .foregroundColor(.teal)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
            }
        }
    }
}
