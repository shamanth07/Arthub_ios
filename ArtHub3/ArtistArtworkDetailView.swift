import SwiftUI
import Kingfisher
import FirebaseDatabase
import FirebaseAuth

struct ArtistArtworkDetailView: View {
    let artwork: Artwork
    @State private var artistName: String = ""
    @State private var artistRole: String = "artist"
    @State private var artistEmail: String = ""
    @State private var profileImageUrl: String? = nil
    @State private var instagram: String = "N/A"
    @State private var website: String = "N/A"
    @State private var isFavourited = false
    @State private var isCheckingFavorite = true
    // Add more social links as needed

    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 16) {
                // Artwork Image
                if let imageUrl = URL(string: artwork.imageUrl) {
                    KFImage(imageUrl)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .cornerRadius(12)
                        .clipped()
                        .padding(.top, 8)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                        .cornerRadius(12)
                        .padding(.top, 8)
                }
                // Optionally show artist profile image as avatar
                if let url = profileImageUrl, let imageUrl = URL(string: url) {
                    HStack {
                        Spacer()
                        KFImage(imageUrl)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        Spacer()
                    }
                }

                // Name and Role
                Text(artistName)
                    .font(.title)
                    .fontWeight(.bold)
                Text(artistRole)
                    .font(.subheadline)
                    .foregroundColor(.gray)

                // Email
                HStack {
                    Image(systemName: "envelope")
                    Text(artistEmail.isEmpty ? "N/A" : artistEmail)
                }
                .font(.body)
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

                // Instagram
                HStack {
                    Image(systemName: "camera")
                    VStack(alignment: .leading) {
                        Text("Instagram")
                        Text(instagram)
                            .foregroundColor(instagram == "N/A" ? .gray : .blue)
                            .onTapGesture {
                                if instagram != "N/A", let url = URL(string: instagram) {
                                    UIApplication.shared.open(url)
                                }
                            }
                    }
                }
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)

                // Website
                HStack {
                    Image(systemName: "creditcard")
                    VStack(alignment: .leading) {
                        Text("Website")
                        Text(website)
                            .foregroundColor(website == "N/A" ? .gray : .blue)
                            .onTapGesture {
                                if website != "N/A", let url = URL(string: website) {
                                    UIApplication.shared.open(url)
                                }
                            }
                    }
                }
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Text(artwork.title)
                        .font(.title)
                        .fontWeight(.bold)
                    Spacer()
                    Button(action: toggleFavourite) {
                        Image(systemName: isFavourited ? "heart.fill" : "heart")
                            .foregroundColor(isFavourited ? .red : .gray)
                            .font(.title2)
                    }
                    .disabled(isCheckingFavorite)
                }

                Spacer()
            }
            .padding()
        }
        .onAppear {
            fetchArtistDetails()
            checkIfFavourited()
        }
    }

    func fetchArtistDetails() {
        let ref = Database.database().reference().child("artists").child(artwork.artistId)
        ref.observeSingleEvent(of: .value) { snapshot in
            DispatchQueue.main.async {
                if let dict = snapshot.value as? [String: Any] {
                    artistName = dict["name"] as? String ?? "Unknown"
                    artistEmail = dict["email"] as? String ?? ""
                    profileImageUrl = dict["profileImageUrl"] as? String
                    if let socialLinks = dict["socialLinks"] as? [String: String] {
                        instagram = socialLinks["instagram"] ?? "N/A"
                        website = socialLinks["website"] ?? "N/A"
                        // Add more social links as needed
                    }
                } else {
                    artistName = "Unknown"
                    artistEmail = ""
                    profileImageUrl = nil
                    instagram = "N/A"
                    website = "N/A"
                }
            }
        }
    }

    func checkIfFavourited() {
        guard let user = Auth.auth().currentUser else { 
            isCheckingFavorite = false
            return 
        }
        
        isCheckingFavorite = true
        let userId = user.uid
        let ref = Database.database().reference().child("favourites").child(userId).child(artwork.artistId)
        
        // Set up a real-time listener for favorites
        ref.observe(.value) { snapshot in
            DispatchQueue.main.async {
            isFavourited = snapshot.exists()
                isCheckingFavorite = false
            }
        }
    }

    func toggleFavourite() {
        guard let user = Auth.auth().currentUser else { return }
        let userId = user.uid
        let artistId = artwork.artistId
        let favRef = Database.database().reference().child("favourites").child(userId).child(artistId)
        
        isCheckingFavorite = true
        
        if isFavourited {
            favRef.removeValue { error, _ in
                DispatchQueue.main.async {
                if error == nil {
                    isFavourited = false
                    }
                    isCheckingFavorite = false
                }
            }
        } else {
            favRef.setValue(true) { error, _ in
                DispatchQueue.main.async {
                if error == nil {
                    isFavourited = true
                    }
                    isCheckingFavorite = false
                }
            }
        }
    }
}

