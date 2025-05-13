//
//  ContentView.swift
//  ArtHub
//
//  Created by User on 2025-04-27.
//

import SwiftUI
import PhotosUI
import FirebaseAuth
import FirebaseDatabase

class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    func signIn(email: String, password: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    completion(false)
                    return
                }
                
                completion(true)
            }
        }
    }
    
    func signUp(email: String, password: String, role: String = "Visitor", completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    completion(false)
                    return
                }
                
                if let uid = result?.user.uid {
                    let userDict: [String: Any] = [
                        "email": email,
                        "role": role
                    ]
                    Database.database().reference().child("users").child(uid).setValue(userDict)
                }
                
                completion(true)
            }
        }
    }
    
    func resetPassword(email: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil
        
        Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = error.localizedDescription
                    completion(false)
                    return
                }
                
                completion(true)
            }
        }
    }
    
    func signOut() throws {
        try Auth.auth().signOut()
    }
}

enum DataTab: String, CaseIterable {
    case events = "Events"
    case admins = "Admins"
    case users = "Users"
}

class DatabaseManager: ObservableObject {
    @Published var admins: [Admin] = []
    @Published var users: [User] = []
    @Published var events: [Event] = []
    private var ref: DatabaseReference!
    
    init() {
        ref = Database.database().reference()
    }
    
    func fetchAdmins() {
        ref.child("admin").observeSingleEvent(of: .value) { snapshot in
            var fetched: [Admin] = []
            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let dict = snap.value as? [String: Any],
                   let email = dict["email"] as? String,
                   let password = dict["password"] as? String,
                   let role = dict["role"] as? String {
                    fetched.append(Admin(email: email, password: password, role: role))
                }
            }
            DispatchQueue.main.async {
                self.admins = fetched
            }
        }
    }
    
    func fetchUsers() {
        ref.child("users").observeSingleEvent(of: .value) { snapshot in
            var fetched: [User] = []
            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let dict = snap.value as? [String: Any],
                   let email = dict["email"] as? String,
                   let password = dict["password"] as? String,
                   let role = dict["role"] as? String {
                    fetched.append(User(email: email, password: password, role: role))
                }
            }
            DispatchQueue.main.async {
                self.users = fetched
            }
        }
    }
    
    func fetchEvents() {
        ref.child("events").observeSingleEvent(of: .value) { snapshot in
            var fetched: [Event] = []
            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let dict = snap.value as? [String: Any],
                   let title = dict["title"] as? String,
                   let description = dict["description"] as? String,
                   let bannerImageUrl = dict["bannerImageUrl"] as? String,
                   let eventDate = dict["eventDate"] as? Double,
                   let eventId = dict["eventId"] as? String,
                   let maxArtists = dict["maxArtists"] as? Int,
                   let time = dict["time"] as? String {
                    fetched.append(Event(title: title, description: description, bannerImageUrl: bannerImageUrl, eventDate: eventDate, eventId: eventId, maxArtists: maxArtists, time: time))
                }
            }
            DispatchQueue.main.async {
                self.events = fetched
            }
        }
    }
    
    func addEvent(_ event: Event) {
        let eventDict: [String: Any] = [
            "title": event.title,
            "description": event.description,
            "bannerImageUrl": event.bannerImageUrl,
            "eventDate": event.eventDate,
            "eventId": event.eventId,
            "maxArtists": event.maxArtists,
            "time": event.time
        ]
        ref.child("events").child(event.eventId).setValue(eventDict)
    }
    
    func addUser(_ user: User) {
        let userDict: [String: Any] = [
            "email": user.email,
            "password": user.password,
            "role": user.role
        ]
        ref.child("users").childByAutoId().setValue(userDict)
    }
}

struct Admin: Identifiable {
    let id = UUID()
    let email: String
    let password: String
    let role: String
}

struct User: Identifiable {
    let id = UUID()
    let email: String
    let password: String
    let role: String
}

struct Event: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let bannerImageUrl: String
    let eventDate: Double
    let eventId: String
    let maxArtists: Int
    let time: String
}

struct SplashScreen: View {
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            VStack(spacing: 16) {
                Image("arthub_logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 300, height: 300)
            }
        }
    }
}

struct ContentView: View {
    @StateObject private var authVM = AuthViewModel()
    @StateObject private var dbManager = DatabaseManager()
    @State private var selectedTab: DataTab = .events
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isPasswordVisible: Bool = false
    @State private var selectedRole: UserRole = .visitor
    @State private var showHome = false
    @State private var showSignUp = false
    @State private var showSplash = true
    @State private var showForgotPassword = false
    @State private var forgotEmail: String = ""
    @State private var forgotConfirmation: Bool = false

    var body: some View {
        ZStack {
            if showSplash {
                SplashScreen()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation {
                                showSplash = false
                            }
                        }
                    }
            } else {
                VStack(spacing: 32) {
                    Spacer()
                    VStack(spacing: 8) {
                        Image("arthub_logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 200, height: 200)
                    }
                    HStack {
                        Spacer()
                        Picker("Role", selection: $selectedRole) {
                            ForEach(UserRole.allCases, id: \..self) { role in
                                Text(role.displayName).tag(role)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 140)
                    }
                    .padding(.horizontal, 32)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Email")
                            .font(.subheadline).bold()
                        TextField("example@email.com", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                    }
                    .padding(.horizontal, 32)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Password")
                            .font(.subheadline).bold()
                        HStack {
                            if isPasswordVisible {
                                TextField("Password", text: $password)
                            } else {
                                SecureField("Password", text: $password)
                            }
                            Button(action: { isPasswordVisible.toggle() }) {
                                Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                    }
                    .padding(.horizontal, 32)
                    Button(action: {
                        authVM.signIn(email: email, password: password) { success in
                            if success {
                                showHome = true
                            }
                        }
                    }) {
                        if authVM.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.black)
                                .cornerRadius(8)
                        } else {
                            Text("Sign in")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.black)
                                .cornerRadius(8)
                                .shadow(color: Color.red.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                    }
                    .padding(.horizontal, 32)
                    if let error = authVM.errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.footnote)
                            .padding(.horizontal, 32)
                    }
                    if selectedRole != .organizer {
                        HStack {
                            Button(action: {
                                showForgotPassword = true
                            }) {
                                Text("Forgot Password?")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Button(action: {
                                showSignUp = true
                            }) {
                                Text("Sign Up")
                                    .font(.footnote)
                                    .foregroundColor(.red)
                                    .bold()
                            }
                        }
                        .padding(.horizontal, 32)
                    } else {
                        HStack {
                            Button(action: {
                                showForgotPassword = true
                            }) {
                                Text("Forgot Password?")
                                    .font(.footnote)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 32)
                    }
                    Spacer()
                }
                .background(Color.white.ignoresSafeArea())
                .fullScreenCover(isPresented: $showSignUp) {
                    SignUpView(authVM: authVM, onSignIn: { showSignUp = false })
                }
                .fullScreenCover(isPresented: $showHome) {
                    if selectedRole == .organizer {
                        AdminHomeView()
                    } else {
                        Text("Welcome!")
                    }
                }
                .sheet(isPresented: $showForgotPassword) {
                    VStack(spacing: 24) {
                        Text("Reset Password")
                            .font(.headline)
                        TextField("Enter your email", text: $forgotEmail)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .padding(.horizontal)
                        if let error = authVM.errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.footnote)
                        }
                        Button(authVM.isLoading ? "Sending..." : "Send Reset Link") {
                            authVM.resetPassword(email: forgotEmail) { success in
                                if success {
                                    forgotConfirmation = true
                                    showForgotPassword = false
                                    forgotEmail = ""
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(.horizontal)
                        .disabled(authVM.isLoading)
                        Button("Cancel") {
                            showForgotPassword = false
                        }
                        .foregroundColor(.red)
                    }
                    .padding()
                    .presentationDetents([.medium])
                }
                .alert(isPresented: $forgotConfirmation) {
                    Alert(title: Text("Reset Link Sent"), message: Text("If an account exists for that email, a reset link will be sent."), dismissButton: .default(Text("OK")))
                }
            }
        }
    }
}

struct SignUpView: View {
    @ObservedObject var authVM: AuthViewModel
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var selectedRole: UserRole = .artist
    @State private var agreedToTerms: Bool = false
    var onSignIn: (() -> Void)? = nil
    @State private var showSuccess: Bool = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
          
            VStack(spacing: 8) {
                Image("arthub_logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
            }

        
            HStack {
                Spacer()
                Picker("Role", selection: $selectedRole) {
                    ForEach(UserRole.allCases.filter { $0 != .organizer }, id: \..self) { role in
                        Text(role.displayName).tag(role)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 140)
            }
            .padding(.horizontal, 32)

          
            VStack(alignment: .leading, spacing: 4) {
                Text("Email")
                    .font(.subheadline).bold()
                TextField("Your email address", text: $email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
            }
            .padding(.horizontal, 32)

    
            VStack(alignment: .leading, spacing: 4) {
                Text("Password")
                    .font(.subheadline).bold()
                SecureField("Your password", text: $password)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 4)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
            }
            .padding(.horizontal, 32)

    
            HStack(alignment: .top) {
                Button(action: { agreedToTerms.toggle() }) {
                    Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                        .foregroundColor(.red)
                }
                .buttonStyle(PlainButtonStyle())
                Text("I agree to the ") +
                Text("Terms of Services").foregroundColor(.red).bold() +
                Text(" and ") +
                Text("Privacy Policy.").foregroundColor(.red).bold()
            }
            .font(.footnote)
            .padding(.horizontal, 32)


            if let error = authVM.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.footnote)
                    .padding(.horizontal, 32)
            }

        
            Button(action: {
                authVM.signUp(email: email, password: password, role: selectedRole.rawValue) { success in
                    if success {
                        showSuccess = true
                    }
                }
            }) {
                if authVM.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(8)
                } else {
                    Text("Sign Up")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(agreedToTerms ? Color.black : Color.gray)
                        .cornerRadius(8)
                        .shadow(color: Color.red.opacity(0.1), radius: 4, x: 0, y: 2)
                }
            }
            .padding(.horizontal, 32)
            .disabled(!agreedToTerms || authVM.isLoading)
            .alert(isPresented: $showSuccess) {
                Alert(title: Text("Sign Up Successful"), message: Text("You can now sign in with your new account."), dismissButton: .default(Text("OK"), action: {
                    onSignIn?()
                }))
            }

    
            HStack {
                Text("Have an Account?")
                    .font(.footnote)
                    .foregroundColor(.gray)
                Button(action: {
                    onSignIn?()
                }) {
                    Text("Sign In")
                        .font(.footnote)
                        .foregroundColor(.red)
                        .bold()
                }
            }
            .padding(.horizontal, 32)
            Spacer()
        }
        .background(Color.white.ignoresSafeArea())
    }
}

struct AdminHomeView: View {
    struct Event: Identifiable {
        let id: UUID
        var title: String
        var date: String
        var time: String
        var image: UIImage?
        var description: String
        var maxVisitors: String
    }

    @State private var events: [Event] = [
        Event(id: UUID(), title: "Moder Art Export Aug 15", date: "2025 - 16:00", time: "", image: nil, description: "", maxVisitors: ""),
        Event(id: UUID(), title: "Photography Exhibit Sep 4", date: "2025 - 17:00", time: "", image: nil, description: "", maxVisitors: "")
    ]
    @State private var showCreateEvent = false
    @State private var editingEvent: Event? = nil
    @State private var eventToDelete: Event? = nil
    @State private var showDeleteAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
        
            HStack {
                Image(systemName: "line.horizontal.3")
                    .font(.title2)
                    .padding(.leading)
                Spacer()
                Text("Organizer")
                    .font(.title)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.top)


            Button(action: {
                showCreateEvent = true
            }) {
                Text("Create Event")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray, lineWidth: 1)
                    )
            }
            .padding(.horizontal)
            .sheet(isPresented: $showCreateEvent) {
                CreateEventView { newEvent in
                    events.insert(newEvent, at: 0)
                }
            }
            .sheet(item: $editingEvent) { event in
                EditEventView(event: event) { updatedEvent in
                    if let idx = events.firstIndex(where: { $0.id == updatedEvent.id }) {
                        events[idx] = updatedEvent
                    }
                }
            }

            Text("Created Events")
                .font(.subheadline)
                .padding(.horizontal)

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(events) { event in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                if let image = event.image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                Text(event.title)
                                    .font(.headline)
                                Spacer()
                                Button(action: {
                                    eventToDelete = event
                                    showDeleteAlert = true
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .padding(.trailing, 4)
                                Button(action: {
                                    editingEvent = event
                                }) {
                                    Text("Edit")
                                        .font(.subheadline)
                                        .frame(width: 80, height: 32)
                                        .background(Color(.systemGray5))
                                        .cornerRadius(4)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 4)
                                                .stroke(Color.gray, lineWidth: 1)
                                        )
                                }
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.gray)
                            }
                            Text(event.date)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            Divider()
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .alert(isPresented: $showDeleteAlert) {
                Alert(
                    title: Text("Delete Event"),
                    message: Text("Are you sure you want to delete this event?"),
                    primaryButton: .destructive(Text("Delete")) {
                        if let event = eventToDelete {
                            events.removeAll { $0.id == event.id }
                        }
                        eventToDelete = nil
                    },
                    secondaryButton: .cancel {
                        eventToDelete = nil
                    }
                )
            }
            Spacer()
        }
    }
}

struct CreateEventView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var eventName: String = ""
    @State private var eventDescription: String = ""
    @State private var eventDate: Date = Date()
    @State private var eventTime: String = ""
    @State private var maxVisitors: String = ""
    @State private var showImagePicker = false
    @State private var eventImage: UIImage? = nil
    @State private var photoItem: PhotosPickerItem? = nil

    var onCreate: ((AdminHomeView.Event) -> Void)?

    var isFormValid: Bool {
        eventImage != nil &&
        !eventName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !eventDescription.trimmingCharacters(in: .whitespaces).isEmpty &&
        !eventTime.trimmingCharacters(in: .whitespaces).isEmpty &&
        !maxVisitors.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 16) {
            // Navigation Bar
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.black)
                }
                Spacer()
                Text("Create Event")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)


            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                if let eventImage = eventImage {
                    Image(uiImage: eventImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 120)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        )
                }
            }
            .onChange(of: photoItem) { newItem in
                if let newItem = newItem {
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            eventImage = uiImage
                        }
                    }
                }
            }
            .cornerRadius(4)
            .padding(.horizontal)

    
            TextField("Event Name", text: $eventName)
                .font(.title2)
                .padding(8)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray, lineWidth: 1))
                .padding(.horizontal)

          
            TextField("Description", text: $eventDescription)
                .padding(8)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray, lineWidth: 1))
                .padding(.horizontal)

        
            HStack(spacing: 8) {
                DatePicker("", selection: $eventDate, displayedComponents: .date)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                TextField("18:00", text: $eventTime)
                    .keyboardType(.numbersAndPunctuation)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray, lineWidth: 1))
            }
            .padding(.horizontal)


            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 100)
                .overlay(
                    Image(systemName: "mappin.and.ellipse")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                )
                .cornerRadius(4)
                .padding(.horizontal)

     
            TextField("Maximum Visitors Allowed", text: $maxVisitors)
                .keyboardType(.numberPad)
                .padding(8)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray, lineWidth: 1))
                .padding(.horizontal)

    
            Button(action: {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                let dateString = formatter.string(from: eventDate)
                let newEvent = AdminHomeView.Event(
                    id: UUID(),
                    title: eventName.isEmpty ? "Untitled Event" : eventName,
                    date: dateString,
                    time: eventTime,
                    image: eventImage,
                    description: eventDescription,
                    maxVisitors: maxVisitors
                )
                let eventDict: [String: Any] = [
                    "title": newEvent.title,
                    "description": newEvent.description,
                    "bannerImageUrl": "",
                    "eventDate": Date().timeIntervalSince1970,
                    "eventId": newEvent.id.uuidString,
                    "maxArtists": Int(newEvent.maxVisitors) ?? 0,
                    "time": newEvent.time
                ]
                Database.database().reference().child("events").child(newEvent.id.uuidString).setValue(eventDict)
                onCreate?(newEvent)
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Create")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isFormValid ? Color(.systemGray5) : Color(.systemGray4))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray, lineWidth: 1)
                    )
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .disabled(!isFormValid)

            Spacer()
        }
    }
}

struct EditEventView: View {
    @Environment(\.presentationMode) var presentationMode
    @State var event: AdminHomeView.Event
    @State private var photoItem: PhotosPickerItem? = nil
    var onSave: ((AdminHomeView.Event) -> Void)?

    var isFormValid: Bool {
        event.image != nil &&
        !event.title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !event.description.trimmingCharacters(in: .whitespaces).isEmpty &&
        !event.time.trimmingCharacters(in: .whitespaces).isEmpty &&
        !event.maxVisitors.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 16) {
        
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.black)
                }
                Spacer()
                Text("Edit Event")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)

     
            PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                if let eventImage = event.image {
                    Image(uiImage: eventImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 120)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 120)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        )
                }
            }
            .onChange(of: photoItem) { newItem in
                if let newItem = newItem {
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            event.image = uiImage
                        }
                    }
                }
            }
            .cornerRadius(4)
            .padding(.horizontal)

      
            TextField("Event Name", text: $event.title)
                .font(.title2)
                .padding(8)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray, lineWidth: 1))
                .padding(.horizontal)

            TextField("Description", text: $event.description)
                .padding(8)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray, lineWidth: 1))
                .padding(.horizontal)

        
            HStack(spacing: 8) {
                TextField("Date", text: $event.date)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray, lineWidth: 1))
                TextField("18:00", text: $event.time)
                    .keyboardType(.numbersAndPunctuation)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray, lineWidth: 1))
            }
            .padding(.horizontal)

        
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(height: 100)
                .overlay(
                    Image(systemName: "mappin.and.ellipse")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                )
                .cornerRadius(4)
                .padding(.horizontal)

           
            TextField("Maximum Visitors Allowed", text: $event.maxVisitors)
                .keyboardType(.numberPad)
                .padding(8)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray, lineWidth: 1))
                .padding(.horizontal)

          
            Button(action: {
                onSave?(event)
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Save")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
        .padding()
                    .background(isFormValid ? Color(.systemGray5) : Color(.systemGray4))
                    .cornerRadius(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray, lineWidth: 1)
                    )
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .disabled(!isFormValid)

            Spacer()
        }
    }
}


enum UserRole: String, CaseIterable {
    case visitor = "Visitor"
    case artist = "Artist"
    case organizer = "Organizer"

    var displayName: String { rawValue }
}

#Preview {
    ContentView()
}
