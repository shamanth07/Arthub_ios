import SwiftUI
import FirebaseDatabase
import Kingfisher

struct VisitorHomeView: View {
    enum FeedType: String, CaseIterable, Identifiable {
        case artworks = "Artworks"
        case events = "Events"
        var id: String { rawValue }
    }
    @State private var feedType: FeedType = .artworks
    @State private var searchText: String = ""
    @State private var artworks: [Artwork] = []
    @State private var events: [Event] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var selectedArtwork: Artwork? = nil
    @State private var showArtworkDetail = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack {
                Button(action: { /* open sidebar if needed */ }) {
                    Image(systemName: "line.horizontal.3")
                        .font(.title)
                        .foregroundColor(.black)
                }
                Spacer()
                Text("ARTHUB")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                Spacer()
                Image(systemName: "bell.fill")
                    .font(.title2)
                    .foregroundColor(.black)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            // Dropdown and Search
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.black)
                    TextField(feedType == .artworks ? "Search artworks..." : "Search events...", text: $searchText)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                Spacer()
                Menu {
                    ForEach(FeedType.allCases) { type in
                        Button(type.rawValue) { feedType = type; searchText = ""; fetchFeed() }
                    }
                } label: {
                    HStack {
                        Text(feedType.rawValue)
                        Image(systemName: "chevron.down")
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            // Feed
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if let errorMessage = errorMessage {
                Spacer()
                Text(errorMessage).foregroundColor(.red)
                Spacer()
            } else if feedType == .artworks {
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(filteredArtworks) { artwork in
                            Button(action: {
                                selectedArtwork = artwork
                                showArtworkDetail = true
                            }) {
                                VisitorArtworkCard(artwork: artwork)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 8)
                }
            } else {
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(filteredEvents) { event in
                            VisitorEventCard(event: event)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Color(.systemGray6).ignoresSafeArea())
        .onAppear(perform: fetchFeed)
        .sheet(isPresented: $showArtworkDetail) {
            if let artwork = selectedArtwork {
                VisitorArtworkDetailView(artwork: artwork, onClose: { showArtworkDetail = false })
            }
        }
    }
    
    var filteredArtworks: [Artwork] {
        if searchText.isEmpty { return artworks }
        return artworks.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.artistId.localizedCaseInsensitiveContains(searchText)
        }
    }
    var filteredEvents: [Event] {
        if searchText.isEmpty { return events }
        return events.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.location.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    func fetchFeed() {
        isLoading = true
        errorMessage = nil
        if feedType == .artworks {
            let ref = Database.database().reference().child("artworks")
            ref.observeSingleEvent(of: .value) { snapshot in
                var fetched: [Artwork] = []
                for child in snapshot.children {
                    if let snap = child as? DataSnapshot,
                       let dict = snap.value as? [String: Any],
                       let id = dict["id"] as? String,
                       let title = dict["title"] as? String,
                       let description = dict["description"] as? String,
                       let category = dict["category"] as? String,
                       let year = dict["year"] as? String,
                       let price = dict["price"] as? String,
                       let imageUrl = dict["imageUrl"] as? String,
                       let artistId = dict["artistId"] as? String {
                        let likes = dict["likes"] as? Int ?? 0
                        let comments = dict["comments"] as? Int ?? 0
                        let artwork = Artwork(id: id, artistId: artistId, title: title, description: description, category: category, year: year, price: price, imageUrl: imageUrl, likes: likes, comments: comments)
                        fetched.append(artwork)
                    }
                }
                DispatchQueue.main.async {
                    self.artworks = fetched
                    self.isLoading = false
                }
            }
        } else {
            let ref = Database.database().reference().child("events")
            ref.observeSingleEvent(of: .value) { snapshot in
                var fetched: [Event] = []
                for child in snapshot.children {
                    if let snap = child as? DataSnapshot,
                       let dict = snap.value as? [String: Any],
                       let title = dict["title"] as? String,
                       let description = dict["description"] as? String,
                       let eventDateMillis = dict["eventDate"] as? Double,
                       let time = dict["time"] as? String,
                       let location = dict["location"] as? String,
                       let latitude = dict["latitude"] as? Double,
                       let longitude = dict["longitude"] as? Double,
                       let maxArtists = dict["maxArtists"] as? Int,
                       let ticketPrice = dict["ticketPrice"] as? Double,
                       let bannerImageUrl = dict["bannerImageUrl"] as? String {
                        let eventDate = Date(timeIntervalSince1970: eventDateMillis / 1000)
                        let event = Event(
                            id: snap.key,
                            title: title,
                            description: description,
                            eventDate: eventDate,
                            time: time,
                            location: location,
                            latitude: latitude,
                            longitude: longitude,
                            maxArtists: maxArtists,
                            ticketPrice: ticketPrice,
                            bannerImageUrl: bannerImageUrl
                        )
                        fetched.append(event)
                    }
                }
                DispatchQueue.main.async {
                    self.events = fetched
                    self.isLoading = false
                }
            }
        }
    }
}

struct VisitorArtworkCard: View {
    let artwork: Artwork
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Color.gray.opacity(0.2)
                KFImage(URL(string: artwork.imageUrl))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            .frame(height: 200)
            .cornerRadius(12)
            .clipped()
            Text(artwork.title)
                .font(.headline)
            Text("By: \(artwork.artistId)")
                .font(.subheadline)
                .fontWeight(.bold)
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "heart")
                        .foregroundColor(.red)
                    Text("\(artwork.likes)")
                }
                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                    Text("\(artwork.comments)")
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
}

struct VisitorEventCard: View {
    let event: Event
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Color.gray.opacity(0.2)
                KFImage(URL(string: event.bannerImageUrl))
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            }
            .frame(height: 200)
            .cornerRadius(12)
            .clipped()
            Text(event.title)
                .font(.headline)
            Text(event.description)
                .font(.subheadline)
                .foregroundColor(.gray)
            HStack(spacing: 16) {
                Image(systemName: "calendar")
                Text(event.eventDate, style: .date)
                Image(systemName: "clock")
                Text(event.time)
            }
            .font(.subheadline)
            Text(event.location)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
}

struct VisitorArtworkDetailView: View {
    let artwork: Artwork
    var onClose: () -> Void
    @State private var artistName: String = "Unknown"
    @State private var description: String = ""
    @State private var instagram: String = "N/A"
    @State private var website: String = "N/A"
    @State private var isLoading = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    Color.gray.opacity(0.2)
                    KFImage(URL(string: artwork.imageUrl))
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                .frame(height: 200)
                .cornerRadius(8)
                .clipped()
                Text(artwork.title)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(artistName)
                    .font(.headline)
                    .foregroundColor(.gray)
                Text(description)
                    .font(.body)
                Group {
                    Text("Instagram:")
                        .fontWeight(.bold)
                    Text(instagram)
                        .foregroundColor(.gray)
                    Text("Website:")
                        .fontWeight(.bold)
                    Text(website)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .padding()
        }
        .background(Color(.systemGray6).ignoresSafeArea())
        .onAppear(perform: fetchArtistProfile)
        .overlay(
            HStack {
                Spacer()
                VStack {
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .frame(width: 32, height: 32)
                            .foregroundColor(.gray)
                            .padding()
                    }
                    Spacer()
                }
            }
        )
    }
    func fetchArtistProfile() {
        isLoading = true
        let ref = Database.database().reference().child("artists").child(artwork.artistId).child("profile")
        ref.observeSingleEvent(of: .value) { snapshot in
            if let dict = snapshot.value as? [String: Any] {
                artistName = dict["username"] as? String ?? artwork.artistId
                description = artwork.description
                instagram = dict["socialLink1"] as? String ?? "N/A"
                website = dict["socialLink2"] as? String ?? "N/A"
            } else {
                artistName = artwork.artistId
                description = artwork.description
                instagram = "N/A"
                website = "N/A"
            }
            isLoading = false
        }
    }
}

#Preview {
    VisitorHomeView()
} 