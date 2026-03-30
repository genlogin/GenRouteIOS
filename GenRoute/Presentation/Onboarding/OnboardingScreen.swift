import SwiftUI

struct OnboardingScreen: View {
    @StateObject var viewModel: OnboardingScreenViewModel
    
    var body: some View {
        ZStack {
            Color.orange.opacity(0.9).ignoresSafeArea()
            
            VStack(spacing: 30) {
                Image(systemName: "location.viewfinder")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150, height: 150)
                    .foregroundColor(.white)
                    .padding(.top, 80)
                
                Text(AppString.onboardingTitle)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text(AppString.onboardingDesc)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                Button(action: {
                    viewModel.finishOnboarding()
                }) {
                    Text(AppString.onboardingButton)
                        .font(.headline)
                        .foregroundColor(.orange)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 60)
            }
        }
    }
}
