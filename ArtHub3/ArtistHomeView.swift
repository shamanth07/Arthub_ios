import SwiftUI

struct ArtistHomeView: View {
    var body: some View {
        VStack {
            Text("Welcome, Artist!")
                .font(.largeTitle)
                .padding()
            Text("This is the Artist Home Page.")
        }
    }
}

#Preview {
    ArtistHomeView()
} 