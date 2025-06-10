import SwiftUI

struct VisitorHomeView: View {
    var body: some View {
        VStack {
            Text("Welcome, Visitor!")
                .font(.largeTitle)
                .padding()
            Text("This is the Visitor Home Page.")
        }
    }
}

#Preview {
    VisitorHomeView()
} 