import SwiftUI
import Firebase

struct LiveChatUserListView: View {
    @State private var chatUsers: [ChatUser] = []
    @State private var isLoading = true
    @State private var currentUserId = Auth.auth().currentUser?.uid ?? ""
    @State private var currentUserRole = ""
    @State private var selectedChatUser: ChatUser? = nil
    @State private var showChat = false

    var body: some View {
        NavigationView {
            List(chatUsers) { user in
                Button(action: {
                    selectedChatUser = user
                    showChat = true
                }) {
                    HStack {
                        Image(systemName: "person.crop.circle")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.blue)
                        VStack(alignment: .leading) {
                            Text(user.email)
                                .font(.headline)
                            Text(user.role.capitalized)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                }
            }
            .navigationTitle("Live Chats")
            .onAppear(perform: fetchChatUsers)
            .sheet(isPresented: $showChat) {
                if let chatUser = selectedChatUser {
                    LiveChatView(chatUserId: chatUser.id, chatUserEmail: chatUser.email, chatUserRole: chatUser.role)
                }
            }
        }
    }

    func fetchChatUsers() {
        // Example: Fetch all users except the current user
        let usersRef = Database.database().reference().child("users")
        usersRef.observeSingleEvent(of: .value) { snapshot in
            var users: [ChatUser] = []
            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let dict = snap.value as? [String: Any],
                   let email = dict["email"] as? String,
                   let role = dict["role"] as? String {
                    let id = snap.key
                    if id != currentUserId {
                        users.append(ChatUser(id: id, email: email, role: role))
                    }
                }
            }
            self.chatUsers = users
            self.isLoading = false
        }
    }
}

struct ChatUser: Identifiable {
    let id: String
    let email: String
    let role: String
} 
