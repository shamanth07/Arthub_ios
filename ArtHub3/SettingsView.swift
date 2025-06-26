import SwiftUI
import FirebaseAuth
import Firebase

struct ChatParams: Identifiable, Equatable {
    let id: String // use chatId
    let chatId: String
    let userName: String
    let userRole: String
}

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("selectedLanguage") private var selectedLanguage = "English"
    @State private var showLanguagePicker = false
    @State private var showUserSelector = false
    @State private var selectedChatParams: ChatParams? = nil
    @State private var userRole: String = ""
    @State private var userEmail: String = ""
    @State private var userId: String = Auth.auth().currentUser?.uid ?? ""
    @State private var adminId: String = ""
    @State private var adminEmail: String = ""
    @State private var isRoleLoaded = false
    var currentUserId: String { Auth.auth().currentUser?.uid ?? "" }
    var currentUserRole: String // pass this from account page
    var currentUserName: String // pass this from account page
    let languages = ["English", "Spanish", "French", "German", "Chinese", "Japanese"]
    
    var body: some View {
        NavigationView {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
                Spacer()
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
            .padding()
            
                if isRoleLoaded {
            // Settings List
            VStack(spacing: 0) {
                // Dark Mode
                HStack {
                    Image(systemName: "moon.fill")
                        .foregroundColor(.black)
                    Text("Dark Mode")
                        .font(.body)
                        .foregroundColor(.black)
                    Spacer()
                    Toggle("", isOn: $isDarkMode)
                        .labelsHidden()
                }
                .padding()
                Divider()
                
                // Language
                Button(action: { showLanguagePicker = true }) {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.blue)
                        Text("Language")
                            .font(.body)
                            .foregroundColor(.black)
                        Spacer()
                        Text(selectedLanguage)
                            .foregroundColor(.gray)
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding()
                }
                Divider()
                
                // Live Chat Support
                        if userRole.lowercased() == "admin" {
                            NavigationLink(destination: LiveChatUserListView()) {
                                HStack {
                                    Image(systemName: "message.fill")
                                        .foregroundColor(.green)
                                    Text("Live Chat Support")
                                        .font(.body)
                                        .foregroundColor(.black)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                            }
                        } else {
                            NavigationLink(destination: LiveChatView(chatUserId: userId, chatUserEmail: adminEmail, chatUserRole: "admin")) {
                    HStack {
                        Image(systemName: "message.fill")
                            .foregroundColor(.green)
                        Text("Live Chat Support")
                            .font(.body)
                            .foregroundColor(.black)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding()
                            }
                }
            }
            .background(Color.white)
            .cornerRadius(12)
            .padding(.horizontal)
                } else {
                    ProgressView("Loading...")
                }
            Spacer()
        }
        .background(Color(.systemGray6).ignoresSafeArea())
        .sheet(isPresented: $showLanguagePicker) {
            NavigationView {
                List(languages, id: \.self) { language in
                    Button(action: {
                        selectedLanguage = language
                        showLanguagePicker = false
                    }) {
                        HStack {
                            Text(language)
                            Spacer()
                            if language == selectedLanguage {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                .navigationTitle("Select Language")
                .navigationBarItems(trailing: Button("Done") {
                    showLanguagePicker = false
                })
            }
        }
        .sheet(isPresented: $showUserSelector) {
            UserSelectorView(currentUserId: currentUserId, currentUserRole: currentUserRole) { otherUserId, otherUserName, otherUserRole in
                let chatId = [currentUserId, otherUserId].sorted().joined(separator: "_")
                selectedChatParams = ChatParams(id: chatId, chatId: chatId, userName: otherUserName, userRole: otherUserRole)
                showUserSelector = false
            }
        }
        .sheet(item: $selectedChatParams) { params in
            LiveChatView(
                    chatUserId: params.chatId,
                    chatUserEmail: params.userName,
                    chatUserRole: params.userRole
                )
            }
            .onAppear {
                fetchUserRole()
                fetchAdminInfo()
            }
        }
    }

    @ViewBuilder
    func destinationView() -> some View {
        if userRole.lowercased() == "admin" {
            LiveChatUserListView()
        } else {
            LiveChatView(chatUserId: userId, chatUserEmail: "admin", chatUserRole: "admin")
        }
    }

    func fetchUserRole() {
        let usersRef = Database.database().reference().child("users").child(userId)
        usersRef.observeSingleEvent(of: .value) { snap in
            if let dict = snap.value as? [String: Any], let role = dict["role"] as? String {
                self.userRole = role
                self.userEmail = dict["email"] as? String ?? ""
                self.isRoleLoaded = true
            } else {
                // Not found in users, check admin node
                let adminRef = Database.database().reference().child("admin").child(userId)
                adminRef.observeSingleEvent(of: .value) { adminSnap in
                    if let adminDict = adminSnap.value as? [String: Any], let role = adminDict["role"] as? String {
                        self.userRole = role
                        self.userEmail = adminDict["email"] as? String ?? ""
                    }
                    self.isRoleLoaded = true
                }
            }
        }
    }

    func fetchAdminInfo() {
        let adminRef = Database.database().reference().child("admin")
        adminRef.observeSingleEvent(of: .value) { snapshot in
            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let dict = snap.value as? [String: Any] {
                    self.adminId = snap.key
                    self.adminEmail = dict["email"] as? String ?? ""
                    break // Use the first admin found
                }
            }
        }
    }
}
