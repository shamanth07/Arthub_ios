import SwiftUI
import FirebaseDatabase
import FirebaseAuth
import PhotosUI
import FirebaseStorage
import Kingfisher

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
    @State private var artworkToDelete: Artwork? = nil
    @State private var showDeleteConfirmation = false
    @State private var showAccount = false
    @State private var showProfile = false
    var onLogout: () -> Void
    
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
                        VStack(spacing: 16) {
                            ForEach(artworks) { artwork in
                                VStack(alignment: .leading, spacing: 8) {
                                    ZStack(alignment: .topTrailing) {
                                        Button(action: {
                                            selectedArtwork = artwork
                                            showEditArtwork = true
                                        }) {
                                            VStack(alignment: .leading, spacing: 0) {
                                                ZStack {
                                                    Color.gray.opacity(0.2)
                                                    KFImage(URL(string: artwork.imageUrl))
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                }
                                                .frame(height: 200)
                                                .cornerRadius(12)
                                                .clipped()
                                            }
                                        }
                                        Button(action: {
                                            artworkToDelete = artwork
                                            showDeleteConfirmation = true
                                        }) {
                                            Image(systemName: "trash")
                                                .foregroundColor(.black)
                                                .padding(8)
                                                .background(Color.white.opacity(0.8))
                                                .clipShape(Circle())
                                                .padding([.top, .trailing], 8)
                                        }
                                    }
                                    Text(artwork.title)
                                        .font(.headline)
                                        .fontWeight(.bold)
                                    ArtistNameView(artistId: artwork.artistId)
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(radius: 2)
                                .padding(.horizontal)
                            }
                        }
                        .padding(.top, 8)
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
                if let artwork = selectedArtwork {
                    EditArtworkView(artwork: artwork, onSave: {
                        showEditArtwork = false
                        selectedArtwork = nil
                        fetchArtworks()
                    })
                }
            }
            .alert(isPresented: $showDeleteConfirmation) {
                Alert(
                    title: Text("Delete Artwork"),
                    message: Text("Are you sure you want to delete this artwork?"),
                    primaryButton: .destructive(Text("Delete"), action: {
                        if let artwork = artworkToDelete {
                            deleteArtwork(artwork)
                            artworkToDelete = nil
                        }
                    }),
                    secondaryButton: .cancel({ artworkToDelete = nil })
                )
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
        }
        .navigationViewStyle(StackNavigationViewStyle())
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
        let ref = Database.database().reference().child("artists").child(artistId).child("artworks")
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
}

struct UploadArtworkView: View {
    var onUploadSuccess: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var category = ""
    @State private var year = ""
    @State private var price = ""
    @State private var selectedImage: PhotosPickerItem? = nil
    @State private var artworkUIImage: UIImage? = nil
    @State private var imageUrl: String = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.blue)
                }
                Spacer()
            }
            .padding(.top, 8)
            
            PhotosPicker(selection: $selectedImage, matching: .images) {
                ZStack {
                    if let image = artworkUIImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipped()
                            .cornerRadius(8)
                    } else {
                        Rectangle()
                            .fill(Color.gray)
                            .frame(height: 200)
                            .cornerRadius(8)
                    }
                }
            }
            .onChange(of: selectedImage) { newItem in
                if let newItem {
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            artworkUIImage = uiImage
                            uploadArtworkImage(data: data)
                        }
                    }
                }
            }
            
            Group {
                TextField("Title", text: $title)
                Divider()
                TextField("Description", text: $description)
                Divider()
                TextField("Category (e.g., Painting)", text: $category)
                Divider()
                TextField("Year Created", text: $year)
                Divider()
                TextField("Price (optional)", text: $price)
                Divider()
            }
            .padding(.horizontal, 4)
            .foregroundColor(.gray)
            
            if showError {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
            
            Button(action: uploadArtwork) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(30)
                } else {
                    Text("Upload Artwork")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(30)
                }
            }
            .padding(.top, 8)
            .disabled(isLoading)
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6).ignoresSafeArea())
    }
    
    private func uploadArtworkImage(data: Data) {
        let storageRef = Storage.storage().reference()
        let fileName = "artwork_images/\(UUID().uuidString).jpg"
        let imageRef = storageRef.child(fileName)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        imageRef.putData(data, metadata: metadata) { metadata, error in
            if let error = error {
                errorMessage = "Image upload error: \(error.localizedDescription)"
                showError = true
                return
            }
            imageRef.downloadURL { url, error in
                if let url = url {
                    imageUrl = url.absoluteString
                }
            }
        }
    }
    
    private func uploadArtwork() {
        guard !title.isEmpty, !description.isEmpty, !category.isEmpty, !year.isEmpty, !imageUrl.isEmpty else {
            errorMessage = "Please fill all required fields and select an image."
            showError = true
            return
        }
        isLoading = true
        showError = false
        guard let user = Auth.auth().currentUser else {
            errorMessage = "Not logged in."
            showError = true
            isLoading = false
            return
        }
        let artistId = user.uid
        let dbRef = Database.database().reference()
        let artworkId = UUID().uuidString
        let artworkData: [String: Any] = [
            "id": artworkId,
            "artistId": artistId,
            "title": title,
            "description": description,
            "category": category,
            "year": year,
            "price": price,
            "imageUrl": imageUrl,
            "likes": 0,
            "comments": 0
        ]
        // Store under /artists/{artistId}/artworks
        dbRef.child("artists").child(artistId).child("artworks").child(artworkId).setValue(artworkData) { error, _ in
            if let error = error {
                errorMessage = "Upload error: \(error.localizedDescription)"
                showError = true
                isLoading = false
                return
            }
            // Store under /artworks
            dbRef.child("artworks").child(artworkId).setValue(artworkData) { error, _ in
                isLoading = false
                if let error = error {
                    errorMessage = "Upload error: \(error.localizedDescription)"
                    showError = true
                } else {
                    onUploadSuccess()
                    dismiss()
                }
            }
        }
    }
}

// EditArtworkView for editing an artwork
struct EditArtworkView: View {
    var artwork: Artwork
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var description: String
    @State private var category: String
    @State private var year: String
    @State private var price: String
    @State private var imageUrl: String
    @State private var selectedImage: PhotosPickerItem? = nil
    @State private var artworkUIImage: UIImage? = nil
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    
    init(artwork: Artwork, onSave: @escaping () -> Void) {
        self.artwork = artwork
        self.onSave = onSave
        _title = State(initialValue: artwork.title)
        _description = State(initialValue: artwork.description)
        _category = State(initialValue: artwork.category)
        _year = State(initialValue: artwork.year)
        _price = State(initialValue: artwork.price)
        _imageUrl = State(initialValue: artwork.imageUrl)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "arrow.left.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.blue)
                }
                Spacer()
            }
            .padding(.top, 8)
            PhotosPicker(selection: $selectedImage, matching: .images) {
                ZStack {
                    if let image = artworkUIImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 200)
                            .clipped()
                            .cornerRadius(8)
                    } else if let url = URL(string: imageUrl) {
                        ZStack {
                            Color.gray.opacity(0.2)
                            KFImage(url)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        }
                        .frame(height: 200)
                        .clipped()
                        .cornerRadius(8)
                    } else {
                        Rectangle()
                            .fill(Color.gray)
                            .frame(height: 200)
                            .cornerRadius(8)
                    }
                }
            }
            .onChange(of: selectedImage) { newItem in
                if let newItem {
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            artworkUIImage = uiImage
                            uploadArtworkImage(data: data)
                        }
                    }
                }
            }
            Group {
                TextField("Title", text: $title)
                Divider()
                TextField("Description", text: $description)
                Divider()
                TextField("Category (e.g., Painting)", text: $category)
                Divider()
                TextField("Year Created", text: $year)
                Divider()
                TextField("Price (optional)", text: $price)
                Divider()
            }
            .padding(.horizontal, 4)
            .foregroundColor(.gray)
            if showError {
                Text(errorMessage)
                    .foregroundColor(.red)
            }
            Button(action: saveArtwork) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(30)
                } else {
                    Text("Save")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(30)
                }
            }
            .padding(.top, 8)
            .disabled(isLoading)
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6).ignoresSafeArea())
    }
    private func uploadArtworkImage(data: Data) {
        let storageRef = Storage.storage().reference()
        let fileName = "artwork_images/\(UUID().uuidString).jpg"
        let imageRef = storageRef.child(fileName)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        imageRef.putData(data, metadata: metadata) { metadata, error in
            if let error = error {
                errorMessage = "Image upload error: \(error.localizedDescription)"
                showError = true
                return
            }
            imageRef.downloadURL { url, error in
                if let url = url {
                    imageUrl = url.absoluteString
                }
            }
        }
    }
    private func saveArtwork() {
        guard !title.isEmpty, !description.isEmpty, !category.isEmpty, !year.isEmpty, !imageUrl.isEmpty else {
            errorMessage = "Please fill all required fields and select an image."
            showError = true
            return
        }
        isLoading = true
        showError = false
        guard let user = Auth.auth().currentUser else {
            errorMessage = "Not logged in."
            showError = true
            isLoading = false
            return
        }
        let artistId = user.uid
        let dbRef = Database.database().reference()
        let artworkId = artwork.id
        let artworkData: [String: Any] = [
            "id": artworkId,
            "artistId": artistId,
            "title": title,
            "description": description,
            "category": category,
            "year": year,
            "price": price,
            "imageUrl": imageUrl,
            "likes": artwork.likes,
            "comments": artwork.comments
        ]
        dbRef.child("artists").child(artistId).child("artworks").child(artworkId).setValue(artworkData) { error, _ in
            if let error = error {
                errorMessage = "Save error: \(error.localizedDescription)"
                showError = true
                isLoading = false
                return
            }
            dbRef.child("artworks").child(artworkId).setValue(artworkData) { error, _ in
                isLoading = false
                if let error = error {
                    errorMessage = "Save error: \(error.localizedDescription)"
                    showError = true
                } else {
                    onSave()
                    dismiss()
                }
            }
        }
    }
}

struct ArtistAccountView: View {
    var onLogout: () -> Void
    var onBack: () -> Void
    var onProfile: () -> Void
    @State private var username: String = Auth.auth().currentUser?.email ?? "Artist"
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
                ArtistAccountRow(icon: "heart", label: "Favourites")
                Divider()
                ArtistAccountRow(icon: "ticket", label: "Apply For Event")
                Divider()
                ArtistAccountRow(icon: "sparkle", label: "Status")
                Divider()
                ArtistAccountRow(icon: "gearshape", label: "Settings")
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
        let ref = Database.database().reference().child("artists").child(uid).child("profile")
        ref.observeSingleEvent(of: .value) { snapshot in
            if let dict = snapshot.value as? [String: Any] {
                self.username = dict["username"] as? String ?? user.email?.components(separatedBy: "@").first ?? "Artist"
                self.email = dict["email"] as? String ?? user.email ?? ""
                self.bio = dict["bio"] as? String ?? ""
                self.socialLink1 = dict["socialLink1"] as? String ?? ""
                self.socialLink2 = dict["socialLink2"] as? String ?? ""
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
        let ref = Database.database().reference().child("artists").child(uid).child("profile")
        let profileData: [String: Any] = [
            "username": username,
            "email": email,
            "bio": bio,
            "socialLink1": socialLink1,
            "socialLink2": socialLink2,
            "profileImageUrl": profileImageUrl ?? ""
        ]
        ref.setValue(profileData) { error, _ in
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
        let ref = Database.database().reference().child("artists").child(artistId).child("profile")
        ref.observeSingleEvent(of: .value) { snapshot in
            DispatchQueue.main.async {
                if let dict = snapshot.value as? [String: Any],
                   let name = dict["username"] as? String,
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

#Preview {
    ArtistHomeView(onLogout: {})
}
