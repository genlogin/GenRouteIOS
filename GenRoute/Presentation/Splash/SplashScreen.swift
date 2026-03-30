import SwiftUI

struct SplashScreen: View {
    @StateObject var viewModel: SplashScreenViewModel
    
    var body: some View {
        ZStack {
            Color.blue.ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "map.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .foregroundColor(.white)
                
                Text(AppString.splashTitle)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                    .padding(.top, 30)
            }
        }
        .onAppear {
            viewModel.startTimer()
        }
    }
}
