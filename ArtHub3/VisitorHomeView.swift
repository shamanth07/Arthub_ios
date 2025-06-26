import SwiftUI
import FirebaseDatabase
import Kingfisher
import FirebaseAuth
import Stripe
import StripePaymentSheet

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
    @State private var showAccount = false
    @State private var selectedEvent: Event? = nil
    @State private var showEventDetail = false
    @State private var showSettings = false
    @State private var showFavourites = false
    @State private var showingCommentsForArtwork: Artwork? = nil
    @State private var comments: [ArtworkComment] = []
    @State private var newComment: String = ""
    @State private var isCommentsSheetPresented = false
    @State private var showMessagesList = false
    @State private var hasUnreadMessages = false
    @State private var unreadMessageCount = 0
    @State private var showEventCommentsSheet = false
    var onLogout: () -> Void = {}
    @State private var activeSheet: VisitorSheet? = nil
    
    enum VisitorSheet: Identifiable, Equatable {
        case account, settings, artworkDetail, eventDetail, favourites, comments(Artwork)
        var id: String {
            switch self {
            case .account: return "account"
            case .settings: return "settings"
            case .artworkDetail: return "artworkDetail"
            case .eventDetail: return "eventDetail"
            case .favourites: return "favourites"
            case .comments(let artwork): return "comments_\(artwork.id)"
            }
        }
        static func == (lhs: VisitorSheet, rhs: VisitorSheet) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    var visitorUsername: String {
        Auth.auth().currentUser?.email?.components(separatedBy: "@").first ?? "Visitor"
    }
    
    var body: some View {
        NavigationView {
        VStack(spacing: 0) {
            // Top Bar
            HStack {
                Button(action: { activeSheet = .account }) {
                    Image(systemName: "line.horizontal.3")
                        .font(.title)
                        .foregroundColor(.black)
                }
                Button(action: { fetchFeed() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title)
                        .foregroundColor(.blue)
                        .padding(.leading, 8)
                }
                Spacer()
                Text("ARTHUB")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                Spacer()
                Button(action: { showMessagesList = true }) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell.fill")
                            .font(.title2)
                            .foregroundColor(.black)
                        if unreadMessageCount > 0 {
                            Text("\(unreadMessageCount)")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .padding(5)
                                .background(Circle().fill(Color.red))
                                .offset(x: 8, y: -8)
                        }
                    }
                }
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
                            VisitorArtworkCard(
                                artwork: artwork,
                                onCardTap: {
                                    selectedArtwork = artwork
                                    DispatchQueue.main.async {
                                        activeSheet = .artworkDetail
                                    }
                                },
                                onShowComments: {
                                    showingCommentsForArtwork = artwork
                                    fetchComments(for: artwork)
                                    activeSheet = .comments(artwork)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 8)
                }
            } else {
                ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(events) { event in
                                NavigationLink(
                                    destination: VisitorEventDetailView(event: event)
                                ) {
                                    VisitorEventCard(
                                        event: event,
                                        onCardTap: {}, // Not needed
                                        onShowComments: {
                                selectedEvent = event
                                            showEventCommentsSheet = true
                                        }
                                    )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Color(.systemGray6).ignoresSafeArea())
        .onAppear(perform: fetchFeed)
        .onAppear {
            fetchFeed()
            observeUnreadMessages()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .account:
                VisitorAccountView(
                    onLogout: {
                        do {
                            try Auth.auth().signOut()
                            onLogout()
                        } catch {
                            print("Logout error: \(error.localizedDescription)")
                        }
                        activeSheet = nil
                    },
                    onBack: { activeSheet = nil },
                    onShowSettings: { activeSheet = .settings }
                )
            case .settings:
                SettingsView(
                    currentUserRole: "visitor",
                    currentUserName: visitorUsername
                )
            case .artworkDetail:
                if let artwork = selectedArtwork {
                    ArtistArtworkDetailView(artwork: artwork)
                }
            case .eventDetail:
                if let event = selectedEvent {
                        VisitorEventDetailView(event: event)
                }
            case .favourites:
                FavouritesView()
            case .comments(let artwork):
                CommentsSheet(
                    artworkId: artwork.id,
                    comments: $comments,
                    newComment: $newComment,
                    onSend: { addComment(for: artwork) }
                )
            }
        }
        .sheet(isPresented: $showMessagesList) {
            MessageSendersListView(
                currentUserRole: "visitor",
                currentUserName: visitorUsername
            )
            }
            .sheet(isPresented: $showEventCommentsSheet) {
                if let event = selectedEvent {
                    EventCommentsSheet(eventId: event.id, isVisitor: true)
                }
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
    
    func fetchComments(for artwork: Artwork) {
        comments = [] // Clear existing comments
        let commentsRef = Database.database().reference().child("artworkInteractions").child(artwork.id).child("comments")
        commentsRef.observeSingleEvent(of: .value) { snapshot in
            let loaded = self.parseComments(snapshot: snapshot)
            DispatchQueue.main.async {
                self.comments = loaded.sorted { $0.timestamp < $1.timestamp }
            }
        }
    }
    
    // Recursive function to parse comments and their replies
    private func parseComments(snapshot: DataSnapshot, parentId: String? = nil) -> [ArtworkComment] {
        var result: [ArtworkComment] = []
        for child in snapshot.children {
            if let snap = child as? DataSnapshot,
               let dict = snap.value as? [String: Any] {
                // Support both 'comment' and 'text' for the main text
                let mainText = dict["comment"] as? String ?? dict["text"] as? String
                let timestamp = dict["timestamp"] as? Double
                let userId = dict["userId"] as? String
                if let mainText = mainText, let timestamp = timestamp, let userId = userId {
                var replies: [ArtworkComment] = []
                let repliesSnap = snap.childSnapshot(forPath: "replies")
                if repliesSnap.exists() {
                    replies = parseComments(snapshot: repliesSnap, parentId: snap.key)
                }
                let commentObj = ArtworkComment(
                    id: snap.key,
                        comment: mainText,
                    timestamp: timestamp,
                    userId: userId,
                    parentId: parentId,
                    replies: replies
                )
                result.append(commentObj)
                }
            }
        }
        return result
    }
    
    func addComment(for artwork: Artwork) {
        guard let user = Auth.auth().currentUser, !newComment.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let userId = user.uid

        let commentsRef = Database.database().reference().child("artworkInteractions").child(artwork.id).child("comments").childByAutoId()

        let commentData: [String: Any] = [
            "comment": newComment,
            "timestamp": ServerValue.timestamp(),
            "userId": userId
        ]
        
        commentsRef.setValue(commentData) { error, _ in
            if error == nil {
                // Then, increment the comment count in the artwork using a transaction
                let artworkRef = Database.database().reference().child("artworks").child(artwork.id)
                artworkRef.runTransactionBlock({ (currentData: MutableData) -> TransactionResult in
                    if var post = currentData.value as? [String : AnyObject] {
                        var comments = post["comments"] as? Int ?? 0
                        comments += 1
                        post["comments"] = comments as AnyObject?
                        currentData.value = post
                    }
                    return TransactionResult.success(withValue: currentData)
                }) { (error, committed, snapshot) in
                    if let error = error {
                        print("Error updating comment count: \(error.localizedDescription)")
                    } else if committed {
                        DispatchQueue.main.async {
                            self.newComment = ""
                            self.fetchComments(for: artwork)
                            // Optionally update local artwork model
                            if let snapshot = snapshot,
                               let dict = snapshot.value as? [String: Any],
                               let index = self.artworks.firstIndex(where: { $0.id == artwork.id }) {
                                let updatedComments = dict["comments"] as? Int ?? artwork.comments + 1
                                let updatedArtwork = Artwork(
                                    id: artwork.id, artistId: artwork.artistId, title: artwork.title,
                                    description: artwork.description, category: artwork.category,
                                    year: artwork.year, price: artwork.price, imageUrl: artwork.imageUrl,
                                    likes: artwork.likes, comments: updatedComments
                                )
                                self.artworks[index] = updatedArtwork
                            }
                        }
                    }
                }
            }
        }
    }
    
    func observeUnreadMessages() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let db = Database.database().reference()
        db.child("chats").observe(.value) { snapshot in
            var count = 0
            let group = DispatchGroup()
            
            for child in snapshot.children {
                if let chatSnap = child as? DataSnapshot {
                    let chatId = chatSnap.key
                    let ids = chatId.components(separatedBy: "_")
                    guard ids.contains(userId), ids.count == 2 else { continue }
                    let otherUserId = ids.first { $0 != userId } ?? ""
                    
                    group.enter()
                    // Try users first
                    db.child("users").child(otherUserId).observeSingleEvent(of: .value) { userSnap in
                        if let userDict = userSnap.value as? [String: Any], let role = userDict["role"] as? String {
                            let otherUserRole = role.lowercased()
                            let messagesSnap = chatSnap.childSnapshot(forPath: "messages")
                            for msgChild in messagesSnap.children {
                                if let msgSnap = msgChild as? DataSnapshot,
                                   let dict = msgSnap.value as? [String: Any],
                                   let senderId = dict["sender"] as? String,
                                   senderId == otherUserRole,
                                   let isRead = dict["isRead"] as? Bool,
                                   !isRead {
                                    count += 1
                                }
                            }
                        } else {
                            // Try admin if not found in users
                            db.child("admin").child(otherUserId).observeSingleEvent(of: .value) { adminSnap in
                                if let adminDict = adminSnap.value as? [String: Any], let role = adminDict["role"] as? String {
                                    let otherUserRole = role.lowercased()
                                    let messagesSnap = chatSnap.childSnapshot(forPath: "messages")
                                    for msgChild in messagesSnap.children {
                                        if let msgSnap = msgChild as? DataSnapshot,
                                           let dict = msgSnap.value as? [String: Any],
                                           let senderId = dict["sender"] as? String,
                                           senderId == otherUserRole,
                                           let isRead = dict["isRead"] as? Bool,
                                           !isRead {
                                            count += 1
                                        }
                                    }
                                }
                            }
                        }
                        group.leave()
                    }
                }
            }
            
            group.notify(queue: .main) {
                unreadMessageCount = count
            }
        }
    }
}

struct VisitorArtworkCard: View {
    let artwork: Artwork
    let onCardTap: () -> Void
    let onShowComments: () -> Void
    @State private var artistName: String = ""
    @State private var isLoading = true
    @State private var isFavourited = false
    @State private var likesCount: Int = 0
    @State private var commentsCount: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Artwork Image and Title Section
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
                .contentShape(Rectangle())
                .onTapGesture {
                    onCardTap()
                }
                
                Text(artwork.title)
                    .font(.headline)
                    .foregroundColor(.black)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onCardTap()
                    }
            }
            
            // Artist Name
            if isLoading {
                Text("By: ...")
                    .font(.subheadline)
                    .fontWeight(.bold)
            } else {
                Text("By: \(artistName)")
                    .font(.subheadline)
                    .fontWeight(.bold)
            }
            
            // Interaction Buttons
            HStack(spacing: 16) {
                // Like Button
                HStack(spacing: 4) {
                    Image(systemName: isFavourited ? "heart.fill" : "heart")
                        .foregroundColor(.red)
                    Text("\(likesCount)")
                        .foregroundColor(.black)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    handleLike()
                }
                
                // Comment Button
                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .foregroundColor(.black)
                    Text("\(commentsCount)")
                        .foregroundColor(.black)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onShowComments()
                }
            }
            .font(.subheadline)
            .padding(.top, 4)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 2)
        .padding(.horizontal)
        .onAppear {
            fetchArtistName()
            fetchLikesAndFavourited()
            fetchCommentsCount()
        }
    }
    
    func fetchArtistName() {
        let ref = Database.database().reference().child("artists").child(artwork.artistId)
        ref.observeSingleEvent(of: .value) { snapshot in
            DispatchQueue.main.async {
                if let dict = snapshot.value as? [String: Any],
                   let name = dict["name"] as? String,
                   !name.trimmingCharacters(in: .whitespaces).isEmpty {
                    artistName = name
                } else {
                    artistName = "Unknown Artist"
                }
                isLoading = false
            }
        }
    }
    
    func fetchLikesAndFavourited() {
        guard let user = Auth.auth().currentUser else { return }
        let userId = user.uid
        let likesRef = Database.database().reference().child("artworkInteractions").child(artwork.id).child("likes")
        likesRef.observeSingleEvent(of: .value) { snapshot in
            likesCount = Int(snapshot.childrenCount)
            isFavourited = snapshot.hasChild(userId)
        }
    }
    
    func fetchCommentsCount() {
        let commentsRef = Database.database().reference().child("artworkInteractions").child(artwork.id).child("comments")
        commentsRef.observe(.value) { snapshot in
            // Only count top-level comments (not replies)
            commentsCount = Int(snapshot.childrenCount)
        }
    }
    
    func handleLike() {
        guard let user = Auth.auth().currentUser else { return }
        let userId = user.uid
        let likesRef = Database.database().reference().child("artworkInteractions").child(artwork.id).child("likes").child(userId)
        if isFavourited {
            likesRef.removeValue { error, _ in
                if error == nil {
                    isFavourited = false
                    likesCount -= 1
                }
            }
        } else {
            likesRef.setValue(true) { error, _ in
                if error == nil {
                    isFavourited = true
                    likesCount += 1
                }
            }
        }
    }
}

struct VisitorEventCard: View {
    let event: Event
    let onCardTap: () -> Void
    let onShowComments: () -> Void
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
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
            .contentShape(Rectangle())
            Button(action: onShowComments) {
                HStack(spacing: 4) {
                    Image(systemName: "bubble.right")
                        .foregroundColor(.blue)
                    Text("Comment")
                        .foregroundColor(.blue)
                }
                .padding(8)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(radius: 1)
            }
            .padding([.bottom, .trailing], 16)
        }
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
    @State private var isFavourited = false
    @State private var likesCount: Int = 0
    
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
                HStack {
                    Text(artwork.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    Spacer()
                    Button(action: toggleFavourite) {
                        Image(systemName: isFavourited ? "heart.fill" : "heart")
                            .foregroundColor(isFavourited ? .red : .gray)
                            .font(.title2)
                    }
                }
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
        .onAppear {
            fetchArtistProfile()
            checkIfFavourited()
        }
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
    func checkIfFavourited() {
        guard let user = Auth.auth().currentUser else { return }
        let userId = user.uid
        let ref = Database.database().reference().child("favourites").child(userId).child(artwork.id)
        ref.observeSingleEvent(of: .value) { snapshot in
            isFavourited = snapshot.exists()
        }
    }
    func toggleFavourite() {
        guard let user = Auth.auth().currentUser else { return }
        let userId = user.uid
        let ref = Database.database().reference().child("favourites").child(userId).child(artwork.id)
        if isFavourited {
            ref.removeValue { error, _ in
                if error == nil {
                    isFavourited = false
                }
            }
        } else {
            ref.setValue(true) { error, _ in
                if error == nil {
                    isFavourited = true
                }
            }
        }
    }
}

struct VisitorAccountView: View {
    var onLogout: () -> Void
    var onBack: () -> Void
    var onShowSettings: () -> Void
    @State private var username: String = Auth.auth().currentUser?.email?.components(separatedBy: "@").first ?? "Visitor"
    @State private var showProfile = false
    @State private var showFavourites = false
    @State private var showBookingHistory = false
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.left.circle.fill")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundColor(.blue)
                }
                Spacer()
            }
            .padding([.top, .leading])
            VStack(spacing: 8) {
                Image(systemName: "person.crop.circle")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.orange)
                    .padding(.top, 8)
                Text("\(username)(visitor)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.top, 4)
            }
            .padding(.bottom, 16)
            VStack(spacing: 0) {
                Button(action: { showProfile = true }) {
                    VisitorAccountRow(icon: "person.crop.circle", label: "Profile")
                }
                Divider()
                Button(action: { showFavourites = true }) {
                    VisitorAccountRow(icon: "heart", label: "Favourites", iconColor: .red)
                }
                Divider()
                Button(action: { showBookingHistory = true }) {
                    VisitorAccountRow(icon: "house.fill", label: "Booking History", iconColor: .red)
                }
                Divider()
                Button(action: { onShowSettings() }) {
                    VisitorAccountRow(icon: "gearshape", label: "Settings", iconColor: .gray)
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom, 24)
            Spacer()
            Button(action: onLogout) {
                Text("Logout")
                    .foregroundColor(.white)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(30)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .background(Color.white.ignoresSafeArea())
        .sheet(isPresented: $showProfile) {
            VisitorProfileView()
        }
        .sheet(isPresented: $showFavourites) {
            FavouritesView()
        }
        .sheet(isPresented: $showBookingHistory) {
            BookingHistoryView()
        }
    }
}

struct VisitorAccountRow: View {
    var icon: String
    var label: String
    var iconColor: Color = .blue
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)
            Text(label)
                .font(.headline)
                .foregroundColor(.black)
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
    }
}

// Helper view to present PaymentSheet
struct PaymentSheetView: UIViewControllerRepresentable {
    let paymentSheet: PaymentSheet
    let onCompletion: (PaymentSheetResult) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        DispatchQueue.main.async {
            paymentSheet.present(from: controller) { result in
                onCompletion(result)
            }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

// Helper function to fetch PaymentIntent client secret from backend
func fetchPaymentIntentClientSecret(amount: Int, completion: @escaping (String?) -> Void) {
    guard let url = URL(string: "https://05f0-174-95-185-63.ngrok-free.app/create-payment-intent") else  {
        completion(nil)
        return
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    let body = ["amount": amount]
    request.httpBody = try? JSONSerialization.data(withJSONObject: body)
    URLSession.shared.dataTask(with: request) { data, response, error in
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let clientSecret = json["clientSecret"] as? String else {
            completion(nil)
            return
        }
        completion(clientSecret)
    }.resume()
}

struct VisitorEventDetailView: View {
    let event: Event
    @State private var ticketCount: Int = 1
    @State private var isInterested: Bool = false
    @State private var interestCount: Int = 0
    @State private var isLoadingInterest = true
    @State private var featuredArtists: [FeaturedArtist] = []
    @State private var artistLikes: [String: Bool] = [:] // artistId: liked
    @State private var artistLikeCounts: [String: Int] = [:] // artistId: count
    @State private var isLoadingArtists = true
    @State private var paymentError: String? = nil
    @State private var isBooking = false
    @State private var showBookingSuccess = false
    @State private var bookingMessage = ""
    @State private var rsvpCount: Int = 0
    var subtotal: Double { Double(ticketCount) * event.ticketPrice }
    var tax: Double { subtotal * 0.18 }
    var total: Double { subtotal + tax }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ZStack(alignment: .topTrailing) {
                    Color.gray.opacity(0.2)
                    KFImage(URL(string: event.bannerImageUrl))
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                }
                .frame(height: 180)
                .cornerRadius(8)
                .clipped()
                Text(event.title)
                    .font(.system(size: 32, weight: .bold))
                Text("Location: \(event.location)")
                    .font(.title3)
                Text("Date: \(event.eventDate, formatter: dateFormatter) at \(event.time)")
                    .font(.title3)
                Text(event.description)
                    .font(.body)
                    .padding(.top, 4)
                    Text("Tickets:")
                HStack(spacing: 16) {
                    Button(action: { if ticketCount > 1 { ticketCount -= 1 } }) {
                        Image(systemName: "minus.circle").font(.title2)
                    }
                    Text("\(ticketCount)").font(.title2)
                    Button(action: { ticketCount += 1 }) {
                        Image(systemName: "plus.circle").font(.title2)
                    }
                }
                .padding(.vertical, 4)
                // Interested Button
                Button(action: toggleInterest) {
                    Text(isInterested ? "✔️ Marked as Interested" : "Interested")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isInterested ? Color.green : Color(#colorLiteral(red: 0.2, green: 0.7, blue: 0.3, alpha: 1)))
                        .cornerRadius(30)
                    }
                .disabled(isLoadingInterest)
                Text("Interested Count: \(interestCount)")
                    .foregroundColor(.purple)
                Text(String(format: "SubTotal: $%.2f", subtotal))
                Text(String(format: "Tax (18%%): $%.2f", tax))
                Text(String(format: "Total: $%.2f", total))
                // Book Now Button
                Button(action: {
                    let amountInCents = Int(total * 100)
                    paymentError = nil
                    fetchPaymentIntentClientSecret(amount: amountInCents) { clientSecret in
                        if let clientSecret = clientSecret {
                            DispatchQueue.main.async {
                                let config = PaymentSheet.Configuration()
                                let paymentSheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: config)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                       let rootVC = windowScene.windows.first?.rootViewController {
                                        paymentSheet.present(from: rootVC) { result in
                                            switch result {
                                            case .completed:
                                                // Save booking to Firebase
                                                saveBooking()
                                            case .canceled:
                                                paymentError = "Payment was canceled."
                                            case .failed(let error):
                                                paymentError = error.localizedDescription
                                            }
                                        }
                                    }
                                }
                            }
                    } else {
                            DispatchQueue.main.async {
                                paymentError = "Failed to create payment. Please try again."
                            }
                        }
                    }
                }) {
                        Text("Book Now")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(30)
                    }
                if let error = paymentError {
                    Text(error).foregroundColor(.red)
                }
                // Featured Artists Section
                Text("Featured Artists")
                    .font(.title3)
                    .fontWeight(.bold)
                .padding(.top, 16)
                if isLoadingArtists {
                    ProgressView()
                } else if featuredArtists.isEmpty {
                    Text("No featured artists yet.").foregroundColor(.gray)
                } else {
                    ForEach(featuredArtists) { artist in
            HStack {
                            Image(systemName: "person.crop.circle")
                            .resizable()
                                .frame(width: 40, height: 40)
                                .background(Color(#colorLiteral(red: 0.9, green: 1, blue: 1, alpha: 1)))
                                .clipShape(Circle())
                            VStack(alignment: .leading) {
                                Text(artist.name)
                                    .font(.headline)
                                Text("Likes: \(artistLikeCounts[artist.id] ?? 0)")
                                    .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                            Button(action: { toggleArtistLike(artistId: artist.id) }) {
                                Image(systemName: artistLikes[artist.id] == true ? "heart.fill" : "heart")
                                    .foregroundColor(.red)
                                    .font(.title2)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .padding()
        }
        .alert(isPresented: $showBookingSuccess) {
            Alert(
                title: Text("Success"),
                message: Text(bookingMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            fetchInterestState()
            fetchInterestCount()
            fetchFeaturedArtists()
        }
    }
    // --- Interest Logic ---
    func toggleInterest() {
        guard let user = Auth.auth().currentUser else { return }
        let userId = user.uid
        let eventTitle = event.title
        let eventInterestRef = Database.database().reference().child("eventinterest").child(eventTitle).child(userId)
        let interestCountRef = Database.database().reference().child("interestcount").child(eventTitle).child("interested")
        if isInterested {
            // Remove interest
            eventInterestRef.removeValue { _, _ in
                isInterested = false
                // Decrement count
                interestCountRef.runTransactionBlock({ currentData in
                    let count = (currentData.value as? Int) ?? 0
                    currentData.value = max(0, count - 1)
                    return TransactionResult.success(withValue: currentData)
                }, andCompletionBlock: { error, _, _ in
                    if error == nil { fetchInterestCount() }
                })
            }
        } else {
            // Add interest
            eventInterestRef.setValue(["interested": true]) { _, _ in
                isInterested = true
                // Increment count
                interestCountRef.runTransactionBlock({ currentData in
                    let count = (currentData.value as? Int) ?? 0
                    currentData.value = count + 1
                    return TransactionResult.success(withValue: currentData)
                }, andCompletionBlock: { error, _, _ in
                    if error == nil { fetchInterestCount() }
                })
            }
        }
    }
    func fetchInterestState() {
        guard let user = Auth.auth().currentUser else { return }
        let userId = user.uid
        let eventTitle = event.title
        let eventInterestRef = Database.database().reference().child("eventinterest").child(eventTitle).child(userId)
        isLoadingInterest = true
        eventInterestRef.observeSingleEvent(of: .value) { snapshot in
            if let dict = snapshot.value as? [String: Any], dict["interested"] as? Bool == true {
                isInterested = true
            } else {
                isInterested = false
            }
            isLoadingInterest = false
        }
    }
    func fetchInterestCount() {
        let eventTitle = event.title
        let interestCountRef = Database.database().reference().child("interestcount").child(eventTitle).child("interested")
        interestCountRef.observeSingleEvent(of: .value) { snapshot in
            if let count = snapshot.value as? Int {
                interestCount = count
            } else {
                interestCount = 0
            }
        }
    }
    // --- Featured Artists Logic ---
    struct FeaturedArtist: Identifiable {
        let id: String // artistId
        let name: String
    }
    func fetchFeaturedArtists() {
        isLoadingArtists = true
        let invitationsRef = Database.database().reference().child("invitations").child(event.id)
        invitationsRef.observeSingleEvent(of: .value) { snapshot in
            var artists: [FeaturedArtist] = []
            var likeStates: [String: Bool] = [:]
            var likeCounts: [String: Int] = [:]
            let group = DispatchGroup()
            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let dict = snap.value as? [String: Any],
                   let status = dict["status"] as? String, status.lowercased() == "accepted" {
                    let artistId = snap.key
                    let artistName = dict["artistName"] as? String ?? "Artist"
                    artists.append(FeaturedArtist(id: artistId, name: artistName))
                    // Fetch like state and count
                    group.enter()
                    fetchArtistLikeStateAndCount(artistId: artistId) { liked, count in
                        likeStates[artistId] = liked
                        likeCounts[artistId] = count
                        group.leave()
                    }
                }
            }
            group.notify(queue: .main) {
                self.featuredArtists = artists
                self.artistLikes = likeStates
                self.artistLikeCounts = likeCounts
                self.isLoadingArtists = false
            }
        }
    }
    func fetchArtistLikeStateAndCount(artistId: String, completion: @escaping (Bool, Int) -> Void) {
        guard let user = Auth.auth().currentUser else { completion(false, 0); return }
        let userId = user.uid
        let likesRef = Database.database().reference().child("artistLikesInEvents").child(event.id).child(artistId)
        let countRef = Database.database().reference().child("artistlikescount").child(event.id).child(artistId)
        likesRef.observeSingleEvent(of: .value) { snapshot in
            let liked = snapshot.hasChild(userId)
            countRef.observeSingleEvent(of: .value) { countSnap in
                let count = countSnap.value as? Int ?? 0
                completion(liked, count)
            }
        }
    }
    func toggleArtistLike(artistId: String) {
        guard let user = Auth.auth().currentUser else { return }
        let userId = user.uid
        let likesRef = Database.database().reference().child("artistLikesInEvents").child(event.id).child(artistId).child(userId)
        let countRef = Database.database().reference().child("artistlikescount").child(event.id).child(artistId)
        let currentlyLiked = artistLikes[artistId] == true
        if currentlyLiked {
            likesRef.removeValue { _, _ in
                // Decrement count
                countRef.runTransactionBlock({ currentData in
                    let count = (currentData.value as? Int) ?? 0
                    currentData.value = max(0, count - 1)
                    return TransactionResult.success(withValue: currentData)
                }, andCompletionBlock: { _, _, _ in
                    fetchFeaturedArtists()
                })
            }
        } else {
            likesRef.setValue(true) { _, _ in
                // Increment count
                countRef.runTransactionBlock({ currentData in
                    let count = (currentData.value as? Int) ?? 0
                    currentData.value = count + 1
                    return TransactionResult.success(withValue: currentData)
                }, andCompletionBlock: { _, _, _ in
                    fetchFeaturedArtists()
                })
            }
        }
    }
    func saveBooking() {
        guard let user = Auth.auth().currentUser else { return }
        let userId = user.uid
        let ref = Database.database().reference().child("bookings").childByAutoId()
        let rsvpRef = Database.database().reference().child("rsvp").child(event.title).child(userId)
        let rsvpCountRef = Database.database().reference().child("rsvpcount").child(event.title)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let timestamp = dateFormatter.string(from: Date())
        
        let bookingData: [String: Any] = [
            "userId": userId,
            "event": [
                "title": event.title,
                "description": event.description,
                "imageUrl": event.bannerImageUrl,
                "location": event.location,
                "date": event.eventDate.formatted(date: .long, time: .omitted),
                "time": event.time,
                "ticketPrice": event.ticketPrice
            ],
            "bookingTimestamp": timestamp,
            "ticketsBooked": ticketCount,
            "subtotal": subtotal,
            "tax": tax,
            "total": total
        ]
        
        // Save booking
        ref.setValue(bookingData) { error, _ in
            if let error = error {
                DispatchQueue.main.async {
                    self.paymentError = "Error saving booking: \(error.localizedDescription)"
                }
                return
            }
            
            // Update RSVP
            rsvpRef.child("tickets").setValue(ticketCount)
            rsvpRef.child("timestamp").setValue(ServerValue.timestamp())
            
            // Update RSVP count
            rsvpCountRef.child("attending").runTransactionBlock({ currentData in
                var count = (currentData.value as? Int) ?? 0
                count += ticketCount
                currentData.value = count
                    return TransactionResult.success(withValue: currentData)
            })
            
            DispatchQueue.main.async {
                self.showBookingSuccess = true
                self.bookingMessage = "Booking confirmed! You can view your booking in the Booking History."
            }
        }
    }
}

struct FavouriteArtist: Identifiable {
    let id: String // artistId
    let name: String
    let bio: String
    let email: String
    let profileImageUrl: String
}

struct FavouritesView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var favouriteArtists: [FavouriteArtist] = []
    @State private var isLoading = true
    var body: some View {
        VStack {
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "arrow.left")
                        .font(.title2)
                        .foregroundColor(.black)
                }
                Spacer()
                Text("My Favourites")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button(action: fetchFavourites) {
                    Image(systemName: "arrow.clockwise")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if favouriteArtists.isEmpty {
                Spacer()
                Text("No favourites yet.").foregroundColor(.gray)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(favouriteArtists) { artist in
                            VStack(alignment: .leading, spacing: 8) {
                                if let url = URL(string: artist.profileImageUrl), !artist.profileImageUrl.isEmpty {
                                    KFImage(url)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                } else {
                                    Image(systemName: "person.crop.square")
                                        .resizable()
                                        .frame(width: 100, height: 100)
                                        .foregroundColor(.gray)
                                }
                                Text(artist.name)
                                    .font(.headline)
                                Text(artist.bio)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Text(artist.email)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear(perform: fetchFavourites)
        .background(Color(.systemGray6).ignoresSafeArea())
    }
    func fetchFavourites() {
        guard let user = Auth.auth().currentUser else { return }
        let userId = user.uid
        let favRef = Database.database().reference().child("favourites").child(userId)
        favRef.observeSingleEvent(of: .value) { snapshot in
            var artistIds: [String] = []
            for child in snapshot.children {
                if let snap = child as? DataSnapshot, snap.value as? Bool == true {
                    artistIds.append(snap.key)
                }
            }
            if artistIds.isEmpty {
                self.favouriteArtists = []
                self.isLoading = false
                return
            }
            // Fetch artist profiles
            let artistsRef = Database.database().reference().child("artists")
            var loaded: [FavouriteArtist] = []
            let group = DispatchGroup()
            for artistId in artistIds {
                group.enter()
                artistsRef.child(artistId).observeSingleEvent(of: .value) { snap in
                    if let dict = snap.value as? [String: Any] {
                        let name = dict["name"] as? String ?? ""
                        let bio = dict["bio"] as? String ?? ""
                        let email = dict["email"] as? String ?? ""
                        let profileImageUrl = dict["profileImageUrl"] as? String ?? ""
                        let artist = FavouriteArtist(id: artistId, name: name, bio: bio, email: email, profileImageUrl: profileImageUrl)
                        loaded.append(artist)
                    }
                    group.leave()
                    }
                }
            group.notify(queue: .main) {
                self.favouriteArtists = loaded
                self.isLoading = false
            }
        }
    }
}

struct BookingHistoryView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var bookings: [Booking] = []
    @State private var isLoading = true
    var body: some View {
        VStack {
            HStack {
                Spacer()
                Text("Booking History")
                    .font(.system(size: 32, weight: .bold))
                    .padding(.top, 8)
                Spacer()
            }
            .padding(.bottom, 8)
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if bookings.isEmpty {
                Spacer()
                Text("No bookings yet.").foregroundColor(.gray)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 24) {
                        ForEach(bookings) { booking in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(booking.event.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                HStack(spacing: 8) {
                                    Image(systemName: "mappin.and.ellipse")
                                        .foregroundColor(.red)
                                Text(booking.event.location)
                                    .font(.subheadline)
                                }
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.red)
                                Text("\(booking.event.date) at \(booking.event.time)")
                                    .font(.subheadline)
                                }
                                Text("Tickets: \(booking.ticketsBooked)")
                                    .font(.body)
                                Text(String(format: "Subtotal: ₹%.2f", booking.subtotal))
                                    .font(.body)
                                Text(String(format: "Tax: ₹%.2f", booking.tax))
                                    .font(.body)
                                Text(String(format: "Total: ₹%.2f", booking.total))
                                    .font(.body)
                                Text("Booked on: \(booking.bookingTimestamp)")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                HStack {
                                    Spacer()
                                Button(action: { cancelBooking(booking) }) {
                                    Text("cancel Booking")
                                        .foregroundColor(.white)
                                            .font(.headline)
                                            .padding(.horizontal, 32)
                                            .padding(.vertical, 12)
                                        .background(Color.pink)
                                            .cornerRadius(30)
                                }
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(16)
                            .shadow(radius: 2)
                        }
                    }
                    .padding()
                }
            }
        }
        .onAppear(perform: fetchBookings)
        .background(Color(.systemGray6).ignoresSafeArea())
    }
    func fetchBookings() {
        guard let user = Auth.auth().currentUser else { return }
        let userId = user.uid
        let ref = Database.database().reference().child("bookings")
        ref.observeSingleEvent(of: .value) { snapshot in
            var loaded: [Booking] = []
            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let dict = snap.value as? [String: Any],
                   let eventDict = dict["event"] as? [String: Any],
                   let title = eventDict["title"] as? String,
                   let description = eventDict["description"] as? String,
                   let location = eventDict["location"] as? String,
                   let date = eventDict["date"] as? String,
                   let time = eventDict["time"] as? String,
                   let ticketPrice = eventDict["ticketPrice"] as? Double,
                   let bookingUserId = dict["userId"] as? String,
                   bookingUserId == userId {
                    // Handle bannerImageUrl or imageUrl
                    let imageUrl = eventDict["bannerImageUrl"] as? String ?? eventDict["imageUrl"] as? String ?? ""
                    // Handle bookingTimestamp as string or timestamp
                    var bookingTimestamp = ""
                    if let ts = dict["bookingTimestamp"] as? String {
                        bookingTimestamp = ts
                    } else if let ts = dict["bookingTimestamp"] as? Double {
                        let date = Date(timeIntervalSince1970: ts / 1000)
                        let formatter = DateFormatter()
                        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                        bookingTimestamp = formatter.string(from: date)
                    }
                    let subtotal = dict["subtotal"] as? Double ?? 0.0
                    let tax = dict["tax"] as? Double ?? 0.0
                    let total = dict["total"] as? Double ?? 0.0
                    let ticketsBooked = dict["ticketsBooked"] as? Int ?? 0
                    let event = BookingEvent(title: title, description: description, imageUrl: imageUrl, location: location, date: date, time: time, ticketPrice: ticketPrice)
                    let booking = Booking(id: snap.key, bookingTimestamp: bookingTimestamp, event: event, subtotal: subtotal, tax: tax, total: total, ticketsBooked: ticketsBooked, userId: bookingUserId)
                    loaded.append(booking)
                }
            }
            bookings = loaded.sorted { $0.bookingTimestamp > $1.bookingTimestamp }
            isLoading = false
        }
    }
    func cancelBooking(_ booking: Booking) {
        let ref = Database.database().reference().child("bookings").child(booking.id)
        let rsvpRef = Database.database().reference().child("rsvp").child(booking.event.title).child(booking.userId).child("tickets")
        let rsvpCountRef = Database.database().reference().child("rsvpcount").child(booking.event.title).child("attending")
        // First, fetch current tickets
        rsvpRef.observeSingleEvent(of: .value) { snapshot in
            let currentTickets = snapshot.value as? Int ?? 0
            let newTickets = max(0, currentTickets - booking.ticketsBooked)
            if newTickets == 0 {
                // Remove RSVP entry
                rsvpRef.parent?.removeValue()
            } else {
                rsvpRef.setValue(newTickets)
            }
            // Decrement RSVP count
            rsvpCountRef.runTransactionBlock({ currentData in
                let count = (currentData.value as? Int) ?? 0
                currentData.value = max(0, count - booking.ticketsBooked)
                return TransactionResult.success(withValue: currentData)
            }, andCompletionBlock: { _, _, _ in
                // Remove booking after RSVP update
        ref.removeValue { error, _ in
            if error == nil {
                fetchBookings()
            }
                }
            })
        }
    }
}

struct Booking: Identifiable {
    let id: String
    let bookingTimestamp: String
    let event: BookingEvent
    let subtotal: Double
    let tax: Double
    let total: Double
    let ticketsBooked: Int
    let userId: String
}

struct BookingEvent {
    let title: String
    let description: String
    let imageUrl: String
    let location: String
    let date: String
    let time: String
    let ticketPrice: Double
}

struct ArtworkComment: Identifiable, Equatable {
    let id: String
    let comment: String
    let timestamp: Double
    let userId: String
    var userName: String? = nil
    var profileImageUrl: String? = nil
    var parentId: String? = nil // nil for top-level comments, set for replies
    var replies: [ArtworkComment] = [] // Nested replies
    static func == (lhs: ArtworkComment, rhs: ArtworkComment) -> Bool {
        lhs.id == rhs.id && lhs.comment == rhs.comment && lhs.timestamp == rhs.timestamp && lhs.userId == rhs.userId && lhs.userName == rhs.userName && lhs.profileImageUrl == rhs.profileImageUrl && lhs.parentId == rhs.parentId && lhs.replies == rhs.replies
    }
}

struct CommentsSheet: View {
    let artworkId: String
    @Binding var comments: [ArtworkComment]
    @Binding var newComment: String
    var onSend: () -> Void
    @State private var userNames: [String: String] = [:]
    @State private var userProfileImages: [String: String] = [:]
    @State private var isLoading: Bool = true
    @State private var replyingTo: ArtworkComment? = nil
    @State private var replyText: String = ""
    @State private var currentUserId: String = Auth.auth().currentUser?.uid ?? ""
    @State private var isArtist: Bool = false
    @State private var artistId: String = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(comments) { comment in
                                CommentThreadView(
                                    comment: comment,
                                    userNames: userNames,
                                    userProfileImages: userProfileImages,
                                    onReply: { replyingTo = $0 },
                                    isArtist: isArtist
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                Divider()
                if let replying = replyingTo, isArtist {
                    HStack {
                        Text("Replying to: ")
                        Text(userNames[replying.userId] ?? "User")
                            .fontWeight(.bold)
                        Spacer()
                        Button("Cancel") { replyingTo = nil; replyText = "" }
                    }
                    .padding(.horizontal)
                    HStack {
                        TextField("Write a reply...", text: $replyText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button(action: { sendReply() }) {
                            Image(systemName: "arrowshape.turn.up.left.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                } else if !isArtist {
                    HStack {
                        TextField("Add a comment", text: $newComment)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button(action: onSend) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            fetchUserNamesAndPhotos()
            fetchArtistId()
        }
        .onChange(of: comments) { _ in fetchUserNamesAndPhotos() }
    }
    
    func fetchUserNamesAndPhotos() {
        isLoading = true
        let ids = Set(comments.flatMap { [$0.userId] + $0.replies.map { $0.userId } })
        var loadedCount = 0
        let totalToLoad = ids.count
        if totalToLoad == 0 {
            isLoading = false
            return
        }
        for userId in ids {
            if userNames[userId] != nil && userProfileImages[userId] != nil {
                loadedCount += 1
                if loadedCount == totalToLoad { isLoading = false }
                continue
            }
            let userRef = Database.database().reference().child("users").child(userId)
            userRef.observeSingleEvent(of: .value) { snapshot in
                if let dict = snapshot.value as? [String: Any] {
                    if let name = dict["name"] as? String, !name.isEmpty {
                        userNames[userId] = name
                    } else if let email = dict["email"] as? String, !email.isEmpty {
                        userNames[userId] = email
                    }
                    if let profileImageUrl = dict["profileImageUrl"] as? String, !profileImageUrl.isEmpty {
                        userProfileImages[userId] = profileImageUrl
                    }
                }
                loadedCount += 1
                if loadedCount == totalToLoad {
                    isLoading = false
                }
            }
        }
    }
    
    func fetchArtistId() {
        // Fetch the artistId for this artwork
        let artworkRef = Database.database().reference().child("artworks").child(artworkId)
        artworkRef.observeSingleEvent(of: .value) { snapshot in
            if let dict = snapshot.value as? [String: Any], let aid = dict["artistId"] as? String {
                self.artistId = aid
                self.isArtist = (aid == currentUserId)
            }
        }
    }
    
    func sendReply() {
        guard let parent = replyingTo, !replyText.trimmingCharacters(in: .whitespaces).isEmpty, let user = Auth.auth().currentUser, isArtist else { return }
        let userId = user.uid
        let replyRef = Database.database().reference().child("artworkInteractions").child(artworkId).child("comments").child(parent.id).child("replies").childByAutoId()
        let replyData: [String: Any] = [
            "comment": replyText,
            "timestamp": ServerValue.timestamp(),
            "userId": userId
        ]
        replyRef.setValue(replyData) { error, _ in
            if error == nil {
                replyText = ""
                replyingTo = nil
            }
        }
    }
}

struct CommentThreadView: View {
    let comment: ArtworkComment
    let userNames: [String: String]
    let userProfileImages: [String: String]
    var onReply: (ArtworkComment) -> Void
    var isArtist: Bool
    var depth: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                if let urlString = userProfileImages[comment.userId], let url = URL(string: urlString), !urlString.isEmpty {
                    KFImage(url)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundColor(.gray)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(comment.comment)
                        .font(.body)
                    HStack(spacing: 8) {
                        Text(userNames[comment.userId] ?? "Unknown User")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(Date(timeIntervalSince1970: comment.timestamp / 1000), style: .date)
                            .font(.caption2)
                            .foregroundColor(.gray)
                        if isArtist {
                        Button(action: { onReply(comment) }) {
                            Text("Reply")
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .padding(.leading, CGFloat(depth) * 24)
            ForEach(comment.replies) { reply in
                CommentThreadView(
                    comment: reply,
                    userNames: userNames,
                    userProfileImages: userProfileImages,
                    onReply: onReply,
                    isArtist: isArtist,
                    depth: depth + 1
                )
            }
        }
    }
}

private let dateFormatter: DateFormatter = {
    let df = DateFormatter()
    df.dateFormat = "yyyy-MM-dd"
    return df
}()

#Preview {
    VisitorHomeView()
} 
