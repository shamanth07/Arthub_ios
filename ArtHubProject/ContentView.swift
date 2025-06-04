import SwiftUI
import FirebaseDatabase
import PhotosUI
import FirebaseStorage

struct ContentView: View {
    @StateObject private var authVM = AuthViewModel()
    @State private var showSplash = true
    @State private var showSignUp = false
    @State private var showForgot = false
    @State private var selectedRole = "Visitor"
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        ZStack {
            if showSplash {
                SplashScreen()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showSplash = false }
                        }
                    }
            } else if authVM.user == nil {
                LoginView(authVM: authVM, showSignUp: $showSignUp, showForgot: $showForgot)
                    .sheet(isPresented: $showSignUp) {
                        RegisterView(authVM: authVM, isPresented: $showSignUp)
                    }
                    .sheet(isPresented: $showForgot) {
                        ForgotPasswordView(authVM: authVM)
                    }
            } else if authVM.user != nil && authVM.role.isEmpty {
                ProgressView("Loading...")
            } else if authVM.role.lowercased() == "admin" {
                AdminEventListView().environmentObject(authVM)
            } else {
                MainAppView(authVM: authVM)
            }
        }
        .onAppear {
            print("User: \(authVM.user?.email ?? "none"), Role: \(authVM.role)")
        }
    }
}

struct SplashScreen: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack {
                Image("arthub_logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 250, height: 250)
            }
        }
    }
}

struct LoginView: View {
    @ObservedObject var authVM: AuthViewModel
    @Binding var showSignUp: Bool
    @Binding var showForgot: Bool
    @State private var selectedRole = "Visitor"
    @State private var email = ""
    @State private var password = ""
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Image("arthub_logo")
                .resizable()
                .frame(width: 150, height: 150)
                .padding(.bottom, 8)
            Text("ARTHUB").font(.title2).fontWeight(.bold)
            Picker("Role", selection: $selectedRole) {
                Text("Visitor").tag("Visitor")
                Text("Artist").tag("Artist")
                Text("Admin").tag("Admin")
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 200)
            VStack(alignment: .leading, spacing: 8) {
                Text("Email").fontWeight(.semibold)
                TextField("example@email.com", text: $email)
                    .textFieldStyle(.roundedBorder)
                Text("Password").fontWeight(.semibold)
                HStack {
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                }
            }
            Button(action: {
                authVM.signIn(email: email, password: password, role: selectedRole) { _ in }
            }) {
                Text("Sign in")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .shadow(color: .red.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            if let error = authVM.errorMessage {
                Text(error).foregroundColor(.red).font(.footnote)
            }
            HStack {
                Button("Forgot Password?") { showForgot = true }
                    .font(.footnote)
                    .foregroundColor(.gray)
                Spacer()
                Button("Sign Up") { showSignUp = true }
                    .font(.footnote)
                    .foregroundColor(.red)
            }
            Spacer()
        }
        .padding()
    }
}

struct RegisterView: View {
    @ObservedObject var authVM: AuthViewModel
    @Binding var isPresented: Bool
    @State private var email = ""
    @State private var password = ""
    @State private var selectedRole = "Artist"
    @State private var agreed = false
    var body: some View {
        VStack(spacing: 24) {
            Image("arthub_logo")
                .resizable()
                .frame(width: 80, height: 80)
                .padding(.bottom, 8)
            Text("ARTHUB").font(.title2).fontWeight(.bold)
            Picker("Role", selection: $selectedRole) {
                Text("Artist").tag("Artist")
                Text("Visitor").tag("Visitor")
            }
            .pickerStyle(.menu)
            VStack(alignment: .leading, spacing: 8) {
                Text("Email").fontWeight(.semibold)
                TextField("Your email address", text: $email)
                    .textFieldStyle(.roundedBorder)
                Text("Password").fontWeight(.semibold)
                SecureField("Your password", text: $password)
                    .textFieldStyle(.roundedBorder)
            }
            HStack(alignment: .top) {
                Button(action: { agreed.toggle() }) {
                    Image(systemName: agreed ? "checkmark.square.fill" : "square")
                        .foregroundColor(.red)
                }
                Text("I agree to the ") +
                Text("Terms of Services").foregroundColor(.red) +
                Text(" and ") +
                Text("Privacy Policy.").foregroundColor(.red)
            }
            .font(.footnote)
            Button(action: {
                guard agreed else { return }
                authVM.signUp(email: email, password: password, role: selectedRole) { success in
                    if success { isPresented = false }
                }
            }) {
                Text("Sign Up")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(!agreed)
            if let error = authVM.errorMessage {
                Text(error).foregroundColor(.red).font(.footnote)
            }
            Spacer()
            HStack {
                Text("Have an Account?")
                Button("Sign In") { isPresented = false }
                    .foregroundColor(.red)
            }
            .font(.footnote)
        }
        .padding()
    }
}

struct ForgotPasswordView: View {
    @ObservedObject var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var email = ""
    @State private var message: String?
    var body: some View {
        VStack(spacing: 24) {
            Text("Reset Password").font(.headline)
            TextField("Enter your email", text: $email)
                .textFieldStyle(.roundedBorder)
            Button("Send Reset Link") {
                authVM.resetPassword(email: email) { success in
                    message = success ? "Check your email for a reset link." : (authVM.errorMessage ?? "Error")
                }
            }
            if let message = message {
                Text(message).foregroundColor(.blue)
            }
            Spacer()
            Button("Back") { dismiss() }
                .foregroundColor(.red)
        }
        .padding()
    }
}

struct MainAppView: View {
    @ObservedObject var authVM: AuthViewModel
    @State private var selectedTab = 0
    var body: some View {
        TabView(selection: $selectedTab) {
            ArtworkFeedView()
                .tabItem {
                    Image(systemName: "house")
                    Text("Feed")
                }.tag(0)
            ArtworkUploadView()
                .tabItem {
                    Image(systemName: "plus.square")
                    Text("Upload")
                }.tag(1)
            AccountView(authVM: authVM)
                .tabItem {
                    Image(systemName: "person")
                    Text("Account")
                }.tag(2)
        }
    }
}

struct Event: Identifiable {
    let id: String
    var title: String
    var description: String
    var date: Date
    var time: String
    var location: String
    var price: String
    var maxVisitors: Int
    var bannerImageUrl: String?
}

struct EventDetailsView: View {
    let event: Event
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Rectangle().fill(Color(.systemGray5)).frame(height: 160)
                    .overlay(Text("Banner Image"))
                Text(event.title).font(.title).bold()
                Text("Description : \(event.description)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Date : \(event.date.formatted(date: .long, time: .omitted))")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Time : \(event.time)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Location : \(event.location)")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("price : \(event.price)$")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Maximum visitors allowed : \(event.maxVisitors).")
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("confirm the event") {}
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
            }
            .padding()
        }
    }
}

struct AdminEventListView: View {
    @State private var events: [Event] = []
    @State private var showCreate = false
    @State private var selectedEvent: Event? = nil
    @State private var editingEvent: Event? = nil
    @State private var showEditSheet = false
    @State private var eventToDelete: Event? = nil
    @State private var showDeleteAlert = false
    @State private var showAccount = false
    @EnvironmentObject var authVM: AuthViewModel
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                HStack {
                    Button(action: { showAccount = true }) {
                        Image(systemName: "line.horizontal.3")
                            .font(.title2)
                    }
                    Spacer()
                    Text("Admin")
                        .font(.title)
                        .fontWeight(.semibold)
                    Spacer()
                    Button(action: {
                        print("Manual refresh triggered")
                        fetchEventsFromFirebase { loaded in
                            print("Events loaded on manual refresh: \(loaded.count)")
                            events = loaded
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                    }
                }
                .padding(.top)
                .sheet(isPresented: $showAccount) {
                    AdminAccountPage(
                        adminName: authVM.user?.email?.components(separatedBy: "@").first ?? "Admin",
                        adminEmail: authVM.user?.email ?? "admin@email.com",
                        onLogout: {
                            authVM.signOut()
                            showAccount = false
                        }
                    )
                    .environmentObject(authVM)
                }
                Button("Create Event") { showCreate = true }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
                Text("Created Events").font(.headline).padding(.top)
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(events) { event in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    if let urlStr = event.bannerImageUrl, let url = URL(string: urlStr), !urlStr.isEmpty {
                                        AsyncImage(url: url) { image in
                                            image.resizable().aspectRatio(contentMode: .fill)
                                        } placeholder: {
                                            Rectangle().fill(Color(.systemGray5))
                                        }
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    } else {
                                        Rectangle().fill(Color(.systemGray5))
                                            .frame(width: 40, height: 40)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    Text(event.title).font(.headline)
                                    Spacer()
                                    Button(action: { selectedEvent = event }) {
                                        Image(systemName: "chevron.right")
                                    }
                                }
                                Text("\(event.date.formatted(date: .long, time: .shortened)) - \(event.time)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                HStack {
                                    Button("Edit") {
                                        editingEvent = event
                                        showEditSheet = true
                                    }
                                    .buttonStyle(.bordered)
                                    Button(action: {
                                        eventToDelete = event
                                        showDeleteAlert = true
                                    }) {
                                        Image(systemName: "trash").foregroundColor(.red)
                                    }
                                }
                                Divider()
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding()
            .navigationTitle("")
            .sheet(isPresented: $showCreate) {
                EventCreationView(onCreate: { newEvent in
                    events.append(newEvent)
                    saveEventToFirebase(newEvent)
                })
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailsView(event: event)
            }
            .sheet(isPresented: $showEditSheet, onDismiss: {
                editingEvent = nil
            }) {
                if let event = editingEvent {
                    EditEventView(event: event) { updatedEvent in
                        if let idx = events.firstIndex(where: { $0.id == updatedEvent.id }) {
                            events[idx] = updatedEvent
                            updateEventInFirebase(updatedEvent)
                        }
                    }
                }
            }
            .alert(isPresented: $showDeleteAlert) {
                Alert(
                    title: Text("Delete Event"),
                    message: Text("Are you sure you want to delete this event?"),
                    primaryButton: .destructive(Text("Delete")) {
                        if let eventToDelete = eventToDelete {
                            events.removeAll { $0.id == eventToDelete.id }
                            deleteEventFromFirebase(eventToDelete)
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
            .onAppear {
                fetchEventsFromFirebase { loaded in
                    events = loaded
                }
            }
        }
    }
    func fetchEventsFromFirebase(completion: @escaping ([Event]) -> Void) {
        let ref = Database.database().reference()
        print("Fetching events from Firebase...")
        ref.child("events").observe(.value) { snapshot in
            print("Firebase snapshot received: \(snapshot.exists())")
            print("Number of children: \(snapshot.childrenCount)")
            
            var loaded: [Event] = []
            for child in snapshot.children {
                if let snap = child as? DataSnapshot {
                    print("Processing event with key: \(snap.key)")
                    print("Event data: \(snap.value ?? "nil")")
                    
                    if let dict = snap.value as? [String: Any],
                       let title = dict["title"] as? String,
                       let description = dict["description"] as? String,
                       let dateInterval = dict["date"] as? TimeInterval,
                       let time = dict["time"] as? String,
                       let location = dict["location"] as? String,
                       let price = dict["price"] as? String,
                       let maxVisitors = dict["maxVisitors"] as? Int {
                        
                        let event = Event(
                            id: snap.key,
                            title: title,
                            description: description,
                            date: Date(timeIntervalSince1970: dateInterval),
                            time: time,
                            location: location,
                            price: price,
                            maxVisitors: maxVisitors,
                            bannerImageUrl: dict["bannerImageUrl"] as? String
                        )
                        loaded.append(event)
                        print("Successfully loaded event: \(event.title)")
                    } else {
                        print("Failed to parse event data")
                    }
                }
            }
            print("Total events loaded: \(loaded.count)")
            DispatchQueue.main.async {
                completion(loaded)
            }
        }
    }
    func saveEventToFirebase(_ event: Event) {
        let ref = Database.database().reference()
        let eventDict: [String: Any] = [
            "title": event.title,
            "description": event.description,
            "date": event.date.timeIntervalSince1970,
            "time": event.time,
            "location": event.location,
            "price": event.price,
            "maxVisitors": event.maxVisitors,
            "bannerImageUrl": event.bannerImageUrl ?? ""
        ]
        print("Saving event to Firebase: \(eventDict)")
        
        if !event.id.isEmpty {
            ref.child("events").child(event.id).setValue(eventDict) { error, ref in
                if let error = error {
                    print("Error updating event: \(error)")
                } else {
                    print("Event updated successfully with ID: \(event.id)")
                }
            }
        } else {
            ref.child("events").childByAutoId().setValue(eventDict) { error, ref in
                if let error = error {
                    print("Error creating event: \(error)")
                } else {
                    print("Event created successfully with ID: \(ref.key ?? "unknown")")
                }
            }
        }
    }
    func updateEventInFirebase(_ event: Event) {
        saveEventToFirebase(event)
    }
    func deleteEventFromFirebase(_ event: Event) {
        let ref = Database.database().reference()
        ref.child("events").child(event.id).removeValue()
    }
}

struct EditEventView: View {
    @Environment(\.dismiss) var dismiss
    @State private var editedEvent: Event
    var onSave: (Event) -> Void
    @State private var bannerImage: UIImage? = nil
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var isUploading = false
    @State private var isViewReady = false
    
    private var minimumDate: Date {
        Calendar.current.startOfDay(for: Date())
    }
    
    init(event: Event, onSave: @escaping (Event) -> Void) {
        _editedEvent = State(initialValue: event)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isViewReady {
                    Form {
                        Section(header: Text("Event Image")) {
                            PhotosPicker(selection: $photoItem, matching: .images) {
                                if let image = bannerImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 120)
                                        .clipped()
                                } else if let urlStr = editedEvent.bannerImageUrl, let url = URL(string: urlStr), !urlStr.isEmpty {
                                    AsyncImage(url: url) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Rectangle().fill(Color(.systemGray5))
                                    }
                                    .frame(height: 120)
                                    .clipped()
                                } else {
                                    Rectangle()
                                        .fill(Color(.systemGray5))
                                        .frame(height: 120)
                                        .overlay(Text("Banner Image"))
                                }
                            }
                        }
                        
                        Section(header: Text("Event Details")) {
                            TextField("Title", text: $editedEvent.title)
                            TextField("Description", text: $editedEvent.description)
                            DatePicker("Date", selection: $editedEvent.date, in: minimumDate..., displayedComponents: .date)
                            TextField("Time", text: $editedEvent.time)
                            TextField("Location", text: $editedEvent.location)
                            TextField("Price", text: $editedEvent.price)
                            TextField("Maximum Visitors", value: $editedEvent.maxVisitors, formatter: NumberFormatter())
                        }
                    }
                } else {
                    ProgressView("Loading...")
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isUploading ? "Saving..." : "Save") {
                        if let image = bannerImage {
                            isUploading = true
                            uploadImageAndSaveEvent(image: image)
                        } else {
                            saveEvent(imageUrl: editedEvent.bannerImageUrl)
                        }
                    }
                    .disabled(isUploading)
                }
            }
            .onChange(of: photoItem) { newItem in
                if let newItem = newItem {
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            bannerImage = uiImage
                        }
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isViewReady = true
                }
            }
        }
    }
    
    func uploadImageAndSaveEvent(image: UIImage) {
        let storageRef = Storage.storage().reference().child("events/\(UUID().uuidString).jpg")
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        storageRef.putData(imageData) { metadata, error in
            if let error = error {
                print("Upload error: \(error)")
                isUploading = false
                return
            }
            
            storageRef.downloadURL { url, error in
                isUploading = false
                if let url = url {
                    saveEvent(imageUrl: url.absoluteString)
                }
            }
        }
    }
    
    func saveEvent(imageUrl: String?) {
        var updated = editedEvent
        updated.bannerImageUrl = imageUrl
        onSave(updated)
        dismiss()
    }
}

struct EventCreationView: View {
    var onCreate: (Event) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var date = Date()
    @State private var time = ""
    @State private var location = ""
    @State private var price = ""
    @State private var maxVisitors = ""
    @State private var bannerImage: UIImage? = nil
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var isUploading = false
    
    private var minimumDate: Date {
        Calendar.current.startOfDay(for: Date())
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Create Event").font(.headline)
            PhotosPicker(selection: $photoItem, matching: .images) {
                if let image = bannerImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 120)
                        .overlay(Text("Banner Image"))
                }
            }
            .onChange(of: photoItem) { newItem in
                if let newItem = newItem {
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            bannerImage = uiImage
                        }
                    }
                }
            }
            TextField("Title", text: $title).textFieldStyle(.roundedBorder)
            TextField("Description", text: $description).textFieldStyle(.roundedBorder)
            DatePicker("Date", selection: $date, in: minimumDate..., displayedComponents: .date)
            TextField("Time", text: $time).textFieldStyle(.roundedBorder)
            TextField("Location", text: $location).textFieldStyle(.roundedBorder)
            TextField("Price", text: $price).textFieldStyle(.roundedBorder)
            TextField("Maximum Visitors Allowed", text: $maxVisitors).textFieldStyle(.roundedBorder)
            Button(isUploading ? "Uploading..." : "Create") {
                if let image = bannerImage {
                    isUploading = true
                    uploadImageAndSaveEvent(image: image)
                } else {
                    saveEvent(imageUrl: nil)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray5))
            .cornerRadius(8)
            .disabled(isUploading)
            Spacer()
        }
        .padding()
    }
    func uploadImageAndSaveEvent(image: UIImage) {
        let storageRef = Storage.storage().reference().child("events/\(UUID().uuidString).jpg")
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        storageRef.putData(imageData) { metadata, error in
            if let error = error {
                print("Upload error: \(error)")
                isUploading = false
                return
            }
            storageRef.downloadURL { url, error in
                isUploading = false
                saveEvent(imageUrl: url?.absoluteString)
            }
        }
    }
    func saveEvent(imageUrl: String?) {
        let event = Event(
            id: "",
            title: title,
            description: description,
            date: date,
            time: time,
            location: location,
            price: price,
            maxVisitors: Int(maxVisitors) ?? 0,
            bannerImageUrl: imageUrl
        )
        onCreate(event)
        dismiss()
    }
}

struct AccountView: View {
    @ObservedObject var authVM: AuthViewModel
    @State private var showAdminEvents = false
    var body: some View {
        NavigationStack {
        VStack(spacing: 16) {
                Image("arthub_logo")
                    .resizable()
                    .frame(width: 60, height: 60)
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 80)
                    .overlay(Text("Image").foregroundColor(.gray))
                Text(authVM.user?.email ?? "User")
                    .font(.headline)
                Text("(") + Text(authVM.role.capitalized) + Text(")")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                Divider()
                if authVM.role.lowercased() == "admin" {
                    AccountMenuItem(icon: "person", label: "Profile")
                    Button(action: { showAdminEvents = true }) {
                        AccountMenuItem(icon: "calendar", label: "Create Event")
                    }
                    .sheet(isPresented: $showAdminEvents) {
                        AdminEventListView()
                    }
                    AccountMenuItem(icon: "doc", label: "Reports")
                    AccountMenuItem(icon: "gear", label: "Settings")
                } else if authVM.role.lowercased() == "artist" {
                    AccountMenuItem(icon: "person", label: "Profile")
                    AccountMenuItem(icon: "heart", label: "Likes")
                    AccountMenuItem(icon: "calendar", label: "Apply For Event")
                    AccountMenuItem(icon: "checkmark.circle", label: "Status")
                    AccountMenuItem(icon: "gear", label: "Settings")
                } else {
                    AccountMenuItem(icon: "person", label: "Profile")
                    AccountMenuItem(icon: "heart", label: "Likes")
                    AccountMenuItem(icon: "calendar", label: "Apply For Event")
                    AccountMenuItem(icon: "gear", label: "Settings")
                }
                Button("Logout") {
                    authVM.signOut()
                }
                .foregroundColor(.red)
                .padding(.top, 24)
                Spacer()
            }
            .padding()
        }
    }
}

struct AccountMenuItem: View {
    var icon: String
    var label: String
    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(label)
            Spacer()
        }
        .padding(.vertical, 8)
        Divider()
    }
}

struct Artwork: Identifiable {
    let id: String
    var title: String
    var artist: String
    var imageUrl: String
    var likes: Int
}

struct ArtworkFeedView: View {
    @State private var artworks: [Artwork] = []
    @State private var showUpload = false
    @State private var editingArtwork: Artwork? = nil
    @State private var showEditSheet = false
    @State private var artworkToDelete: Artwork? = nil
    @State private var showDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Image("arthub_logo")
                        .resizable()
                        .frame(width: 32, height: 32)
                    Text("Vincent Van Gogh")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "bell")
                }
                .padding(.horizontal)
                Button("Upload Artwork") {
                    showUpload = true
                }
                .buttonStyle(.bordered)
                .padding()
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(artworks) { art in
                            ArtworkCardView(
                                imageUrl: art.imageUrl,
                                title: art.title,
                                artist: art.artist,
                                likes: art.likes,
                                onEdit: {
                                    print("Edit button tapped for artwork: \(art.title)")
                                    editingArtwork = art
                                    showEditSheet = true
                                },
                                onDelete: {
                                    print("Delete button tapped for artwork: \(art.title)")
                                    artworkToDelete = art
                                    showDeleteAlert = true
                                }
                            )
                        }
                    }
                }
                .sheet(isPresented: $showUpload) {
                    ArtworkUploadView()
                }
                .sheet(isPresented: $showEditSheet, onDismiss: {
                    print("Edit sheet dismissed")
                    editingArtwork = nil
                }) {
                    if let artwork = editingArtwork {
                        EditArtworkView(artwork: artwork) { updatedArtwork in
                            print("Artwork updated: \(updatedArtwork.title)")
                            if let idx = artworks.firstIndex(where: { $0.id == updatedArtwork.id }) {
                                artworks[idx] = updatedArtwork
                                updateArtworkInFirebase(updatedArtwork)
                            }
                        }
                    }
                }
                .alert("Delete Artwork", isPresented: $showDeleteAlert) {
                    Button("Cancel", role: .cancel) {
                        print("Delete cancelled")
                        artworkToDelete = nil
                    }
                    Button("Delete", role: .destructive) {
                        if let artworkToDelete = artworkToDelete {
                            print("Deleting artwork: \(artworkToDelete.title)")
                            artworks.removeAll { $0.id == artworkToDelete.id }
                            deleteArtworkFromFirebase(artworkToDelete)
                            self.artworkToDelete = nil
                        }
                    }
                } message: {
                    Text("Are you sure you want to delete this artwork?")
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                print("ArtworkFeedView appeared")
                fetchArtworks()
            }
        }
    }
    
    func fetchArtworks() {
        print("Fetching artworks...")
        let ref = Database.database().reference().child("artworks")
        ref.observe(.value) { snapshot in
            print("Received snapshot with \(snapshot.childrenCount) artworks")
            var loaded: [Artwork] = []
            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let dict = snap.value as? [String: Any],
                   let title = dict["title"] as? String,
                   let imageUrl = dict["imageUrl"] as? String {
                    let artist = dict["artist"] as? String ?? "Unknown"
                    let likes = dict["likes"] as? Int ?? 0
                    loaded.append(Artwork(id: snap.key, title: title, artist: artist, imageUrl: imageUrl, likes: likes))
                }
            }
            print("Loaded \(loaded.count) artworks")
            DispatchQueue.main.async {
                self.artworks = loaded
            }
        }
    }
    
    func updateArtworkInFirebase(_ artwork: Artwork) {
        print("Updating artwork in Firebase: \(artwork.title)")
        let ref = Database.database().reference()
        let dict: [String: Any] = [
            "title": artwork.title,
            "artist": artwork.artist,
            "imageUrl": artwork.imageUrl,
            "likes": artwork.likes
        ]
        ref.child("artworks").child(artwork.id).setValue(dict) { error, ref in
            if let error = error {
                print("Error updating artwork: \(error)")
            } else {
                print("Artwork updated successfully")
            }
        }
    }
    
    func deleteArtworkFromFirebase(_ artwork: Artwork) {
        print("Deleting artwork from Firebase: \(artwork.title)")
        let ref = Database.database().reference()
        ref.child("artworks").child(artwork.id).removeValue { error, ref in
            if let error = error {
                print("Error deleting artwork: \(error)")
            } else {
                print("Artwork deleted successfully")
            }
        }
    }
}

struct ArtworkCardView: View {
    var imageUrl: String
    var title: String
    var artist: String
    var likes: Int
    var onEdit: () -> Void
    var onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let url = URL(string: imageUrl), !imageUrl.isEmpty {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(Color(.systemGray5))
                }
                .frame(height: 160)
                .clipped()
            } else {
                Rectangle().fill(Color(.systemGray5)).frame(height: 160)
            }
            HStack {
                VStack(alignment: .leading) {
                    Text(title).font(.headline).foregroundColor(.white)
                    Text(artist).font(.subheadline).foregroundColor(.white.opacity(0.8))
                }
                Spacer()
                HStack(spacing: 16) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.white)
                        Text("\(likes)").foregroundColor(.white)
                    }
                    
                    Menu {
                        Button(action: {
                            print("Edit menu item tapped")
                            onEdit()
                        }) {
                            Label("Edit", systemImage: "pencil")
                        }
                        Button(role: .destructive, action: {
                            print("Delete menu item tapped")
                            onDelete()
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
            }
            .padding()
            .background(Color.black.opacity(0.7))
        }
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct EditArtworkView: View {
    @Environment(\.dismiss) var dismiss
    @State private var editedArtwork: Artwork
    var onSave: (Artwork) -> Void
    @State private var image: UIImage? = nil
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var isUploading = false
    @State private var isViewReady = false
    
    init(artwork: Artwork, onSave: @escaping (Artwork) -> Void) {
        _editedArtwork = State(initialValue: artwork)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if isViewReady {
                    Form {
                        Section(header: Text("Artwork Image")) {
                            PhotosPicker(selection: $photoItem, matching: .images) {
                                if let image = image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 120)
                                        .clipped()
                                } else if let url = URL(string: editedArtwork.imageUrl), !editedArtwork.imageUrl.isEmpty {
                                    AsyncImage(url: url) { image in
                                        image.resizable().aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        Rectangle().fill(Color(.systemGray5))
                                    }
                                    .frame(height: 120)
                                    .clipped()
                                } else {
                                    Rectangle()
                                        .fill(Color(.systemGray5))
                                        .frame(height: 120)
                                        .overlay(Text("Artwork Image"))
                                }
                            }
                        }
                        
                        Section(header: Text("Artwork Details")) {
                            TextField("Title", text: $editedArtwork.title)
                            TextField("Artist", text: $editedArtwork.artist)
                        }
                    }
                } else {
                    ProgressView("Loading...")
                }
            }
            .navigationTitle("Edit Artwork")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isUploading ? "Saving..." : "Save") {
                        if let image = image {
                            isUploading = true
                            uploadImageAndSaveArtwork(image: image)
                        } else {
                            saveArtwork(imageUrl: editedArtwork.imageUrl)
                        }
                    }
                    .disabled(isUploading)
                }
            }
            .onChange(of: photoItem) { newItem in
                if let newItem = newItem {
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            image = uiImage
                        }
                    }
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isViewReady = true
                }
            }
        }
    }
    
    func uploadImageAndSaveArtwork(image: UIImage) {
        let storageRef = Storage.storage().reference().child("artworks/\(UUID().uuidString).jpg")
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        storageRef.putData(imageData) { metadata, error in
            if let error = error {
                print("Upload error: \(error)")
                isUploading = false
                return
            }
            
            storageRef.downloadURL { url, error in
                isUploading = false
                if let url = url {
                    saveArtwork(imageUrl: url.absoluteString)
                } else {
                    saveArtwork(imageUrl: editedArtwork.imageUrl)
                }
            }
        }
    }
    
    func saveArtwork(imageUrl: String) {
        var updated = editedArtwork
        updated.imageUrl = imageUrl
        onSave(updated)
        dismiss()
    }
}

struct ArtworkUploadView: View {
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var category = ""
    @State private var year = ""
    @State private var price = ""
    @State private var image: UIImage? = nil
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var isUploading = false
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                }
                Spacer()
                Text("Artwork Upload").font(.headline)
                Spacer()
            }
            .padding()
            PhotosPicker(selection: $photoItem, matching: .images) {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: 120, height: 120)
                        .overlay(Text("Image").foregroundColor(.gray))
                }
            }
            .onChange(of: photoItem) { newItem in
                if let newItem = newItem {
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            image = uiImage
                        }
                    }
                }
            }
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
            TextField("Description", text: $description)
                .textFieldStyle(.roundedBorder)
            TextField("Category", text: $category)
                .textFieldStyle(.roundedBorder)
            TextField("Year Created", text: $year)
                .textFieldStyle(.roundedBorder)
            TextField("Price", text: $price)
                .textFieldStyle(.roundedBorder)
            Button(isUploading ? "Uploading..." : "Save") {
                if let image = image {
                    isUploading = true
                    uploadImageAndSaveArtwork(image: image)
                }
            }
            .disabled(isUploading || image == nil)
            .buttonStyle(.bordered)
            .padding(.top)
            Spacer()
        }
        .padding()
    }
    
    func uploadImageAndSaveArtwork(image: UIImage) {
        let storageRef = Storage.storage().reference().child("artworks/\(UUID().uuidString).jpg")
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        storageRef.putData(imageData) { metadata, error in
            if let error = error {
                print("Upload error: \(error)")
                isUploading = false
                return
            }
            
            storageRef.downloadURL { url, error in
                isUploading = false
                if let url = url {
                    saveArtwork(imageUrl: url.absoluteString)
                } else {
                    saveArtwork(imageUrl: "")
                }
            }
        }
    }
    
    func saveArtwork(imageUrl: String) {
        let ref = Database.database().reference().child("artworks").childByAutoId()
        let dict: [String: Any] = [
            "title": title,
            "description": description,
            "category": category,
            "year": year,
            "price": price,
            "imageUrl": imageUrl,
            "artist": "Unknown",
            "likes": 0
        ]
        ref.setValue(dict) { error, ref in
            if let error = error {
                print("Error saving artwork: \(error)")
            } else {
                print("Artwork saved successfully")
                dismiss()
            }
        }
    }
}

struct AdminHomeView: View {
    var body: some View {
        VStack {
            Text("Welcome to the Admin Home Page!")
                .font(.largeTitle)
                .padding()
        }
    }
}

struct AdminAccountPage: View {
    var adminName: String
    var adminEmail: String
    var onLogout: (() -> Void)? = nil
    @Environment(\.dismiss) var dismiss
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image("arthub_logo")
                    .resizable()
                    .frame(width: 40, height: 40)
                Spacer()
                Text("Account")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.top)
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(width: 80, height: 80)
                .overlay(Text("Image").foregroundColor(.gray))
            Text("\(adminName)(Admin)")
                .font(.headline)
            AccountMenuItem(icon: "person.fill", label: "Profile")
            AccountMenuItem(icon: "calendar", label: "Create Event")
            AccountMenuItem(icon: "doc", label: "Reports")
            AccountMenuItem(icon: "gear", label: "Settings")
            Button("Logout") {
                onLogout?()
                dismiss()
            }
            .foregroundColor(.red)
            .padding(.top, 24)
            Spacer()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
