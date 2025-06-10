import SwiftUI

struct AdminHomeView: View {
    var body: some View {
        VStack {
            Text("Welcome, Admin!")
                .font(.largeTitle)
                .padding()
            Text("This is the Admin Home Page.")
        }
    }
}

#Preview {
    AdminHomeView()
} 