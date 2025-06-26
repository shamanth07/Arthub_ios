import SwiftUI
import FirebaseDatabase
import FirebaseAuth
import PhotosUI
import FirebaseStorage
import Kingfisher
import UserNotifications

struct Artwork: Identifiable, Equatable {
    let id: String
    let artistId: String
    let title: String
    let description: String
    let category: String
    let year: String
    let price: String
    let imageUrl: String
    let likes: Int
    let comments: Int
}

struct ArtistHomeView: View {
    @State private var artworks: [Artwork] = []
    @State private var isLoading = true
    @State private var showUploadArtwork = false
    @State private var errorMessage: String? = nil
    @State private var selectedArtwork: Artwork? = nil
    @State private var showEditArtwork = false
    @State private var showDeleteAlert = false
    @State private var artworkToDelete: Artwork? = nil
    @State private var showAccount = false
    @State private var showProfile = false
    @State private var showApplyForEvent = false
    @State private var showStatus = false
    @State private var showSettings = false
    @State private var showMessagesList = false
    @State private var hasUnreadMessages = false
    @State private var unreadMessageCount = 0
    @State private var lastInvitationStatuses: [String: String] = [:]
    var onLogout: () -> Void
    
    var artistUsername: String {
        Auth.auth().currentUser?.email?.components(separatedBy: "@").first ?? "Artist"
    }
    
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Button(action: { showAccount = true }) {
                        Image(systemName: "line.horizontal.3")
                            .font(.title)
                            .foregroundColor(.black)
                    }
                    Button(action: { fetchArtworks() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title)
                            .foregroundColor(.blue)
                            .padding(.leading, 8)
                    }
                    Spacer()
                    Text("Artist Home")
                        .font(.title2)
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
                
                Button(action: { showUploadArtwork = true }) {
                    Text("Upload ArtWork")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(30)
                        .font(.headline)
                }
                .padding([.horizontal, .top])
                
                Button("Test Notification") {
                    showStatusNotification(status: "accepted", eventName: "Test Event")
                }
                .padding()
                
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let errorMessage = errorMessage {
                    Spacer()
                    Text(errorMessage).foregroundColor(.red)
                    Spacer()
                } else if artworks.isEmpty {
                    Spacer()
                    Text("No artworks found.").foregroundColor(.gray)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            ForEach(artworks) { artwork in
                                ZStack(alignment: .topTrailing) {
                                    ArtistArtworkCard(
                                        artwork: artwork,
                                        onEdit: {
                                            selectedArtwork = artwork
                                            showEditArtwork = true
                                        }
                                    )
                                    Button(action: {
                                        artworkToDelete = artwork
                                        showDeleteAlert = true
                                    }) {
                                        Image(systemName: "trash")
                                            .foregroundColor(.red)
                                            .padding(12)
                                            .background(Color.white.opacity(0.8))
                                            .clipShape(Circle())
                                            .shadow(radius: 2)
                                    }
                                    .padding([.top, .trailing], 8)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                Spacer(minLength: 0)
            }
            .onAppear(perform: fetchArtworks)
            .sheet(isPresented: $showUploadArtwork, onDismiss: fetchArtworks) {
                UploadArtworkView(onUploadSuccess: {
                    showUploadArtwork = false
                    fetchArtworks()
                })
            }
            .sheet(isPresented: $showEditArtwork, onDismiss: fetchArtworks) {
                if let selectedArtwork = selectedArtwork {
                    EditArtworkView(artwork: selectedArtwork, onSave: fetchArtworks)
                }
            }
            .alert("Delete Artwork?", isPresented: $showDeleteAlert, presenting: artworkToDelete) { artwork in
                Button("Delete", role: .destructive) {
                    deleteArtwork(artwork)
                }
                Button("Cancel", role: .cancel) {}
            } message: { artwork in
                Text("Are you sure you want to delete \(artwork.title)? This cannot be undone.")
            }
            .sheet(isPresented: $showAccount) {
                ArtistAccountView(
                    onLogout: {
                        do {
                            try Auth.auth().signOut()
                            onLogout()
                        } catch {
                            print("Logout error: \(error.localizedDescription)")
                        }
                        showAccount = false
                    },
                    onBack: { showAccount = false },
                    onProfile: {
                        showProfile = true
                        showAccount = false
                    }
                )
            }
            .sheet(isPresented: $showProfile) {
                ArtistProfileView(onBack: { showProfile = false })
            }
            .sheet(isPresented: $showApplyForEvent) {
                ApplyForEventView(onClose: { showApplyForEvent = false })
            }
            .sheet(isPresented: $showStatus) {
                ArtistStatusView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(
                    currentUserRole: "artist",
                    currentUserName: artistUsername
                )
            }
            .sheet(isPresented: $showMessagesList) {
                MessageSendersListView(
                    currentUserRole: "artist",
                    currentUserName: artistUsername
                )
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .onAppear {
            fetchArtworks()
            requestNotificationPermission()
            if let user = Auth.auth().currentUser {
                print("Calling checkInvitationStatusOnce for artist: \(user.uid)")
                checkInvitationStatusOnce(artistId: user.uid)
            }
            observeUnreadMessages()
            observeInvitationStatusChanges()
        }
    }
    
    func fetchArtworks() {
        isLoading = true
        errorMessage = nil
        guard let user = Auth.auth().currentUser else {
            errorMessage = "Not logged in."
            isLoading = false
            return
        }
        let artistId = user.uid
        print("DEBUG: Fetching artworks for artist: \(artistId)")
        let ref = Database.database().reference().child("artists").child(artistId).child("artworks")
        ref.observeSingleEvent(of: .value) { snapshot in
            var fetched: [Artwork] = []
            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let dict = snap.value as? [String: Any] {
                    print("DEBUG: Processing artwork with data: \(dict)")
                    if let id = dict["id"] as? String,
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
                        print("DEBUG: Created artwork object: \(artwork.title) with ID: \(artwork.id)")
                        fetched.append(artwork)
                    } else {
                        print("DEBUG: Failed to create artwork object from data: \(dict)")
                    }
                }
            }
            DispatchQueue.main.async {
                self.artworks = fetched
                self.isLoading = false
                print("DEBUG: Loaded \(fetched.count) artworks")
            }
        }
    }
    
    func deleteArtwork(_ artwork: Artwork) {
        guard let user = Auth.auth().currentUser else { return }
        let artistId = user.uid
        let dbRef = Database.database().reference()
        // Remove from /artists/{artistId}/artworks
        dbRef.child("artists").child(artistId).child("artworks").child(artwork.id).removeValue { error, _ in
            if let error = error {
                print("Delete error: \(error.localizedDescription)")
            } else {
                // Remove from /artworks
                dbRef.child("artworks").child(artwork.id).removeValue { error, _ in
                    if let error = error {
                        print("Delete error: \(error.localizedDescription)")
                    } else {
                        fetchArtworks()
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
                            print("[DEBUG] Found other user in users node: role=\(otherUserRole)")
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
                            group.leave()
                        } else {
                            // Try admin if not found in users
                            db.child("admin").child(otherUserId).observeSingleEvent(of: .value) { adminSnap in
                                if let adminDict = adminSnap.value as? [String: Any], let role = adminDict["role"] as? String {
                                    let otherUserRole = role.lowercased()
                                    print("[DEBUG] Found other user in admin node: role=\(otherUserRole)")
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
                                    group.leave()
                                } else {
                                    // Try visitors last
                                    db.child("visitors").child(otherUserId).observeSingleEvent(of: .value) { visitorSnap in
                                        if let visitorDict = visitorSnap.value as? [String: Any], let role = visitorDict["role"] as? String {
                                            let otherUserRole = role.lowercased()
                                            print("[DEBUG] Found other user in visitors node: role=\(otherUserRole)")
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
                                            group.leave()
                                        } else {
                                            print("[DEBUG] Other user not found in users, admin, or visitors node.")
                                            group.leave()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            group.notify(queue: .main) {
                unreadMessageCount = count
            }
        }
    }

    // --- Notification Permission ---
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("Notification permission granted")
            } else {
                print("Notification permission denied")
            }
        }
    }

    // --- Invitation Status Check ---
    func checkInvitationStatusOnce(artistId: String) {
        print("Checking invitation status for artist: \(artistId)")
        let invitationsRef = Database.database().reference().child("invitations")
        let eventsRef = Database.database().reference().child("events")
        let userDefaults = UserDefaults.standard

        invitationsRef.observeSingleEvent(of: .value) { snapshot in
            for child in snapshot.children {
                guard let eventSnap = child as? DataSnapshot else { continue }
                let eventId = eventSnap.key
                if eventSnap.hasChild(artistId) {
                    let artistInvite = eventSnap.childSnapshot(forPath: artistId)
                    let status = artistInvite.childSnapshot(forPath: "status").value as? String ?? ""
                    let lastStatusKey = "invitation_status_\(eventId)"
                    let lastStatus = userDefaults.string(forKey: lastStatusKey) ?? ""
                    print("Found status: \(status) for event: \(eventId), lastStatus: \(lastStatus)")
                    if !status.isEmpty && status != lastStatus {
                        userDefaults.set(status, forKey: lastStatusKey)
                        // Fetch event name
                        eventsRef.child(eventId).child("title").observeSingleEvent(of: .value) { eventTitleSnap in
                            let eventName = eventTitleSnap.value as? String
                            print("Triggering notification for status: \(status), event: \(eventName ?? "")")
                            showStatusNotification(status: status, eventName: eventName)
                        }
                    }
                }
            }
        }
    }

    func showStatusNotification(status: String, eventName: String?) {
        print("showStatusNotification called with status: \(status), eventName: \(eventName ?? "nil")")
        let content = UNMutableNotificationContent()
        content.title = "Event Application Update"
        if status == "accepted" {
            content.body = "Congratulations! You were accepted to the event" + (eventName != nil ? ": \(eventName!)" : "")
        } else if status == "rejected" {
            content.body = "Sorry, your application was rejected." + (eventName != nil ? ": \(eventName!)" : "")
        } else {
            print("Status is neither accepted nor rejected, skipping notification.")
            return
        }
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: { error in
            if let error = error {
                print("Failed to schedule notification: \(error.localizedDescription)")
            } else {
                print("Notification scheduled successfully.")
            }
        })
    }

    func observeInvitationStatusChanges() {
        guard let user = Auth.auth().currentUser else { return }
        let artistId = user.uid
        let invitationsRef = Database.database().reference().child("invitations")
        invitationsRef.observe(.value) { snapshot in
            var newStatuses: [String: String] = [:]
            for eventChild in snapshot.children {
                if let eventSnap = eventChild as? DataSnapshot {
                    let eventId = eventSnap.key
                    let artistSnap = eventSnap.childSnapshot(forPath: artistId)
                    if artistSnap.exists(),
                       let dict = artistSnap.value as? [String: Any],
                       let status = dict["status"] as? String {
                        newStatuses[eventId] = status
                        let lastStatus = lastInvitationStatuses[eventId]
                        if lastStatus != nil && lastStatus != status {
                            // Only notify if status changed
                            if status.lowercased() == "accepted" {
                                showStatusNotification(status: "accepted", eventName: eventId)
                            } else if status.lowercased() == "rejected" {
                                showStatusNotification(status: "rejected", eventName: eventId)
                            }
                        }
                    }
                }
            }
            lastInvitationStatuses = newStatuses
        }
    }
}

struct ArtistAccountView: View {
    var onLogout: () -> Void
    var onBack: () -> Void
    var onProfile: () -> Void
    @State private var username: String = Auth.auth().currentUser?.email ?? "Artist"
    @State private var showApplyForEvent = false
    @State private var showStatus = false
    @State private var showSettings = false
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
                Text("\(username)(artist)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.top, 4)
            }
            .padding(.bottom, 16)
            VStack(spacing: 0) {
                Button(action: onProfile) {
                    ArtistAccountRow(icon: "person.crop.circle", label: "Profile")
                }
                Divider()
                Button(action: { showApplyForEvent = true }) {
                    ArtistAccountRow(icon: "ticket", label: "Apply For Event")
                }
                Divider()
                Button(action: { showStatus = true }) {
                    ArtistAccountRow(icon: "sparkle", label: "Status")
                }
                Divider()
                Button(action: { showSettings = true }) {
                    ArtistAccountRow(icon: "gearshape", label: "Settings")
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
        .sheet(isPresented: $showApplyForEvent) {
            ApplyForEventView(onClose: { showApplyForEvent = false })
        }
        .sheet(isPresented: $showStatus) {
            ArtistStatusView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                currentUserRole: "artist",
                currentUserName: username
            )
        }
    }
}

struct ArtistAccountRow: View {
    var icon: String
    var label: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
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

struct ArtistProfileView: View {
    var onBack: () -> Void
    @State private var profileImage: UIImage? = nil
    @State private var profileImageUrl: String? = nil
    @State private var username: String = ""
    @State private var email: String = ""
    @State private var bio: String = ""
    @State private var socialLink1: String = ""
    @State private var socialLink2: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var isEditing = false
    @State private var isSaving = false
    @State private var showChangePassword = false
    @State private var newPassword = ""
    @State private var passwordChangeMessage = ""
    @State private var isChangingPassword = false
    @State private var selectedImage: PhotosPickerItem? = nil
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    Button(action: onBack) {
                        Image(systemName: "arrow.left.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.blue)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        PhotosPicker(selection: $selectedImage, matching: .images) {
                            if let image = profileImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .frame(width: 60, height: 80)
                                    .cornerRadius(8)
                            } else if let url = profileImageUrl, let imageUrl = URL(string: url) {
                                ZStack {
                                    Color.gray.opacity(0.2)
                                    KFImage(imageUrl)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                }
                                .frame(width: 60, height: 80)
                                .cornerRadius(8)
                            } else {
                                Rectangle()
                                    .fill(Color.yellow.opacity(0.5))
                                    .frame(width: 60, height: 80)
                                    .cornerRadius(8)
                            }
                        }
                        .onChange(of: selectedImage) { newItem in
                            if let newItem {
                                Task {
                                    if let data = try? await newItem.loadTransferable(type: Data.self),
                                       let uiImage = UIImage(data: data) {
                                        profileImage = uiImage
                                        uploadProfileImage(data: data)
                                    }
                                }
                            }
                        }
                        if isEditing {
                            TextField("Username", text: $username)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .contextMenu {
                                    Button("Copy") { UIPasteboard.general.string = username }
                                    Button("Paste") { if let string = UIPasteboard.general.string { username = string } }
                                }
                        } else {
                            Text("\(username)\n(Artist)")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                    }
                    Spacer()
                    if isEditing {
                        Button(action: saveProfile) {
                            if isSaving {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 10)
                                    .background(Color.black)
                                    .cornerRadius(30)
                            } else {
                                Text("Save")
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 10)
                                    .background(Color.black)
                                    .cornerRadius(30)
                            }
                        }
                    } else {
                        Button(action: { isEditing = true }) {
                            Text("Edit Profile")
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 10)
                                .background(Color.black)
                                .cornerRadius(30)
                        }
                    }
                }
                .padding(.top, 8)
                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                } else if let errorMessage = errorMessage {
                    Text(errorMessage).foregroundColor(.red)
                } else {
                    Group {
                        Text("Email").font(.title3).fontWeight(.bold)
                        if isEditing {
                            TextField("Email", text: $email)
                                .foregroundColor(.gray)
                                .contextMenu {
                                    Button("Copy") { UIPasteboard.general.string = email }
                                    Button("Paste") { if let string = UIPasteboard.general.string { email = string } }
                                }
                        } else {
                            Text(email).foregroundColor(.gray)
                        }
                        Divider()
                        Text("Bio").font(.title3).fontWeight(.bold)
                        if isEditing {
                            TextField("Bio", text: $bio)
                                .foregroundColor(.gray)
                                .contextMenu {
                                    Button("Copy") { UIPasteboard.general.string = bio }
                                    Button("Paste") { if let string = UIPasteboard.general.string { bio = string } }
                                }
                        } else {
                            Text(bio).foregroundColor(.gray)
                        }
                        Divider()
                        Text("Social Links").font(.title3).fontWeight(.bold)
                        if isEditing {
                            TextField("Social Link 1", text: $socialLink1)
                                .foregroundColor(.gray)
                                .contextMenu {
                                    Button("Copy") { UIPasteboard.general.string = socialLink1 }
                                    Button("Paste") { if let string = UIPasteboard.general.string { socialLink1 = string } }
                                }
                            TextField("Social Link 2", text: $socialLink2)
                                .foregroundColor(.gray)
                                .contextMenu {
                                    Button("Copy") { UIPasteboard.general.string = socialLink2 }
                                    Button("Paste") { if let string = UIPasteboard.general.string { socialLink2 = string } }
                                }
                        } else {
                            Text(socialLink1).foregroundColor(.gray)
                            Text(socialLink2).foregroundColor(.gray)
                        }
                        Divider()
                        HStack {
                            Text("Change Password").font(.title3).fontWeight(.bold)
                            Spacer()
                            Button(action: { showChangePassword.toggle() }) {
                                Image(systemName: showChangePassword ? "chevron.up" : "chevron.down")
                            }
                        }
                        if showChangePassword {
                            SecureField("New Password", text: $newPassword)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding(.vertical, 4)
                            Button(action: changePassword) {
                                if isChangingPassword {
                                    ProgressView()
                                } else {
                                    Text("Update Password")
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.blue)
                                        .cornerRadius(8)
                                }
                            }
                            .padding(.top, 4)
                            if !passwordChangeMessage.isEmpty {
                                Text(passwordChangeMessage)
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                        }
                        Divider()
                    }
                    .padding(.horizontal, 4)
                }
            }
            .padding()
        }
        .background(Color(.systemGray6).ignoresSafeArea())
        .onAppear(perform: fetchProfile)
    }
    
    func fetchProfile() {
        isLoading = true
        errorMessage = nil
        guard let user = Auth.auth().currentUser else {
            errorMessage = "Not logged in."
            isLoading = false
            return
        }
        let uid = user.uid
        let ref = Database.database().reference().child("artists").child(uid)
        ref.observeSingleEvent(of: .value) { snapshot in
            if let dict = snapshot.value as? [String: Any] {
                self.username = dict["name"] as? String ?? user.email?.components(separatedBy: "@").first ?? "Artist"
                self.email = dict["email"] as? String ?? user.email ?? ""
                self.bio = dict["bio"] as? String ?? ""
                if let socialLinks = dict["socialLinks"] as? [String: Any] {
                    self.socialLink1 = socialLinks["instagram"] as? String ?? ""
                    self.socialLink2 = socialLinks["website"] as? String ?? ""
                } else {
                    self.socialLink1 = ""
                    self.socialLink2 = ""
                }
                self.profileImageUrl = dict["profileImageUrl"] as? String
            } else {
                self.username = user.email?.components(separatedBy: "@").first ?? "Artist"
                self.email = user.email ?? ""
                self.bio = ""
                self.socialLink1 = ""
                self.socialLink2 = ""
                self.profileImageUrl = nil
            }
            self.isLoading = false
        }
    }
    
    func saveProfile() {
        isSaving = true
        errorMessage = nil
        guard let user = Auth.auth().currentUser else {
            errorMessage = "Not logged in."
            isSaving = false
            return
        }
        let uid = user.uid
        let ref = Database.database().reference().child("artists").child(uid)
        let artistData: [String: Any] = [
            "name": username,
            "email": email,
            "bio": bio,
            "profileImageUrl": profileImageUrl ?? "",
            "socialLinks": [
                "instagram": socialLink1,
                "website": socialLink2
            ]
        ]
        ref.updateChildValues(artistData) { error, _ in
            isSaving = false
            if let error = error {
                errorMessage = "Save error: \(error.localizedDescription)"
            } else {
                isEditing = false
            }
        }
    }
    
    func uploadProfileImage(data: Data) {
        let storageRef = Storage.storage().reference()
        let fileName = "profile_images/\(UUID().uuidString).jpg"
        let imageRef = storageRef.child(fileName)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        imageRef.putData(data, metadata: metadata) { metadata, error in
            if let error = error {
                errorMessage = "Image upload error: \(error.localizedDescription)"
                return
            }
            imageRef.downloadURL { url, error in
                if let url = url {
                    profileImageUrl = url.absoluteString
                }
            }
        }
    }
    
    func changePassword() {
        guard !newPassword.isEmpty else {
            passwordChangeMessage = "Password cannot be empty."
            return
        }
        isChangingPassword = true
        passwordChangeMessage = ""
        Auth.auth().currentUser?.updatePassword(to: newPassword) { error in
            isChangingPassword = false
            if let error = error {
                passwordChangeMessage = error.localizedDescription
            } else {
                passwordChangeMessage = "Password updated successfully."
                newPassword = ""
                showChangePassword = false
            }
        }
    }
}

struct ArtistNameView: View {
    let artistId: String
    @State private var artistName: String = ""
    @State private var isLoading = true
    var body: some View {
        if isLoading {
            Text("By: ...")
                .font(.subheadline)
                .foregroundColor(.gray)
        } else {
            Text("By: \(artistName)")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
    
    func fetchArtistName() {
        let ref = Database.database().reference().child("artists").child(artistId)
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
    
    init(artistId: String) {
        self.artistId = artistId
        fetchArtistName()
    }
}

struct ArtistArtworkCard: View {
    let artwork: Artwork
    let onEdit: () -> Void
    @State private var likesCount: Int = 0
    @State private var comments: [ArtworkComment] = []
    @State private var showComments = false
    @State private var newComment: String = ""
    @State private var commentsCount: Int = 0
    @State private var showError = false
    @State private var errorMessage = ""
    
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
            .contentShape(Rectangle())
            .onTapGesture { onEdit() }

            Text(artwork.title)
                .font(.headline)
                .fontWeight(.bold)
                .contentShape(Rectangle())
                .onTapGesture { onEdit() }

            ArtistNameView(artistId: artwork.artistId)

            HStack(spacing: 20) {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    Text("\(likesCount)")
                        .foregroundColor(.black)
                }
                Button(action: {
                    showComments = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.right")
                            .foregroundColor(.blue)
                        Text("\(commentsCount)")
                            .foregroundColor(.black)
                    }
                }
                .buttonStyle(BorderlessButtonStyle())
                .contentShape(Rectangle())
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
            fetchLikes()
            fetchComments()
        }
        .sheet(isPresented: $showComments) {
            CommentsSheet(artworkId: artwork.id, comments: $comments, newComment: $newComment, onSend: addComment)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func initializeArtworkInteractions(completion: @escaping (Bool) -> Void) {
        let dbRef = Database.database().reference()
        let interactionsRef = dbRef.child("artworkInteractions").child(artwork.id)
        
        print("DEBUG: Checking interactions for artwork: \(artwork.title)")
        interactionsRef.observeSingleEvent(of: .value) { snapshot in
            print("DEBUG: Snapshot exists for \(artwork.title): \(snapshot.exists())")
            if !snapshot.exists() {
                print("DEBUG: Initializing interactions for \(artwork.title)")
                // Initialize the node with empty likes and comments
                let initialData: [String: Any] = [
                    "likes": [:],
                    "comments": [:]
                ]
                interactionsRef.setValue(initialData) { error, _ in
                    if let error = error {
                        print("DEBUG: Error initializing interactions for \(artwork.title): \(error.localizedDescription)")
                        completion(false)
                    } else {
                        print("DEBUG: Successfully initialized interactions for \(artwork.title)")
                        completion(true)
                    }
                }
            } else {
                print("DEBUG: Interactions already exist for \(artwork.title)")
                completion(true)
            }
        }
    }
    
    func fetchLikes() {
        let likesRef = Database.database().reference().child("artworkInteractions").child(artwork.id).child("likes")
        likesRef.observe(.value) { snapshot in
            likesCount = Int(snapshot.childrenCount)
            print("DEBUG: Fetched likes for \(artwork.title): \(likesCount)")
        }
    }
    
    func fetchComments() {
        let commentsRef = Database.database().reference().child("artworkInteractions").child(artwork.id).child("comments")
        commentsRef.observe(.value) { snapshot in
            let loaded = parseComments(snapshot: snapshot)
            comments = loaded.sorted { $0.timestamp < $1.timestamp }
            commentsCount = loaded.count
            print("DEBUG: Fetched comments for \(artwork.title): \(commentsCount)")
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
    
    func addComment() {
        guard let user = Auth.auth().currentUser, !newComment.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let userId = user.uid
        let commentId = UUID().uuidString
        let timestamp = Date().timeIntervalSince1970 * 1000
        let commentData: [String: Any] = [
            "comment": newComment,
            "timestamp": timestamp,
            "userId": userId
        ]
        let commentsRef = Database.database().reference().child("artworkInteractions").child(artwork.id).child("comments").child(commentId)
        commentsRef.setValue(commentData) { error, _ in
            if error == nil {
                newComment = ""
                commentsCount += 1
                print("DEBUG: Successfully added comment to \(artwork.title)")
            } else {
                errorMessage = "Failed to add comment. Please try again."
                showError = true
                print("DEBUG: Error adding comment to \(artwork.title): \(error?.localizedDescription ?? "unknown error")")
            }
        }
    }
}

#Preview {
    ArtistHomeView(onLogout: {})
} 
