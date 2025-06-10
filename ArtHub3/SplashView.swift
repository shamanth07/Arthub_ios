import SwiftUI

struct SplashView: View {
    var onFinish: () -> Void
    @State private var isActive = false
    
    var body: some View {
        VStack {
            Spacer()
            Image("arthub_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 200, height: 200)
            Spacer()
        }
        .background(Color.white)
        .ignoresSafeArea()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                onFinish()
            }
        }
    }
}

#Preview {
    SplashView(onFinish: {})
} 
