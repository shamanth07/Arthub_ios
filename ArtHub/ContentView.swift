//
//  ContentView.swift
//  ArtHub
//
//  Created by User on 2025-04-27.
//

import SwiftUI
import PhotosUI

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
                    // Logo
                    VStack(spacing: 8) {
                        Image("arthub_logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 200, height: 200)
                    }

                    // Role Picker
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

                    // Email Field
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

                    // Password Field
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

                    // Sign In Button
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

                    // Forgot Password & Sign Up (only for non-organizer roles)
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
                    SignUpView(onSignIn: { showSignUp = false })
                }
                .fullScreenCover(isPresented: $showHome) {
                    if selectedRole == .organizer {
                        AdminHomeView()
                    } else {
                        // Replace with your home/main view for other roles
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
                        Button("Send Reset Link") {
                            forgotConfirmation = true
                            showForgotPassword = false
                            forgotEmail = ""
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(.horizontal)
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
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var selectedRole: UserRole = .artist
    @State private var agreedToTerms: Bool = false
    var onSignIn: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            // Logo
            VStack(spacing: 8) {
                Image("arthub_logo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
            }

            // Role Picker (exclude organizer)
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

            // Email Field
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

            // Password Field
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

            // Terms and Privacy
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

            // Sign Up Button
            Button(action: {
                // TODO: Handle sign up logic
            }) {
                Text("Sign Up")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(agreedToTerms ? Color.black : Color.gray)
                    .cornerRadius(8)
                    .shadow(color: Color.red.opacity(0.1), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal, 32)
            .disabled(!agreedToTerms)

            // Sign In Navigation
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
            // Navigation Bar
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

            // Create Event Button
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

            // Event Image Picker
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

            // Event Name
            TextField("Event Name", text: $eventName)
                .font(.title2)
                .padding(8)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray, lineWidth: 1))
                .padding(.horizontal)

            // Description
            TextField("Description", text: $eventDescription)
                .padding(8)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray, lineWidth: 1))
                .padding(.horizontal)

            // Date and Time
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

            // Map Placeholder
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

            // Max Visitors
            TextField("Maximum Visitors Allowed", text: $maxVisitors)
                .keyboardType(.numberPad)
                .padding(8)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray, lineWidth: 1))
                .padding(.horizontal)

            // Create Button
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
            // Navigation Bar
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

            // Event Image Picker
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

            // Event Name
            TextField("Event Name", text: $event.title)
                .font(.title2)
                .padding(8)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray, lineWidth: 1))
                .padding(.horizontal)

            // Description
            TextField("Description", text: $event.description)
                .padding(8)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray, lineWidth: 1))
                .padding(.horizontal)

            // Date and Time
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

            // Map Placeholder
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

            // Max Visitors
            TextField("Maximum Visitors Allowed", text: $event.maxVisitors)
                .keyboardType(.numberPad)
                .padding(8)
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray, lineWidth: 1))
                .padding(.horizontal)

            // Save Button
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

// UserRole enum
enum UserRole: String, CaseIterable {
    case visitor = "Visitor"
    case artist = "Artist"
    case organizer = "Organizer"

    var displayName: String { rawValue }
}

#Preview {
    ContentView()
}
