import SwiftUI
import Firebase

struct LiveChatView: View {
    let chatUserId: String
    let chatUserEmail: String
    let chatUserRole: String

    @State private var messages: [ChatMessage] = []
    @State private var newMessage = ""
    @State private var currentUserId = Auth.auth().currentUser?.uid ?? ""
    @State private var currentUserRole = ""
    @State private var isLoading = true

    var body: some View {
        VStack {
            Text("Chat with \(chatUserRole.capitalized) (\(chatUserEmail))")
                .font(.title3)
                .bold()
                .padding(.top)
            ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(messages) { msg in
                            HStack {
                                if msg.sender.lowercased() == "admin" {
                                    Spacer()
                                    Text(msg.message)
                                        .padding()
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(12)
                                } else {
                                    Text(msg.message)
                                        .padding()
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(12)
                                    Spacer()
                                }
                            }
                            .id(msg.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages) { _ in
                    if let last = messages.last {
                        withAnimation {
                            scrollProxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
            HStack {
                TextField("Type a message", text: $newMessage)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
        }
        .onAppear {
            fetchCurrentUserRole()
            fetchMessages()
        }
    }

    func fetchCurrentUserRole() {
        let usersRef = Database.database().reference().child("users").child(currentUserId)
        usersRef.observeSingleEvent(of: .value) { snap in
            if let dict = snap.value as? [String: Any], let role = dict["role"] as? String {
                self.currentUserRole = role.lowercased()
            } else {
                // Not found in users, check admin node
                let adminRef = Database.database().reference().child("admin").child(currentUserId)
                adminRef.observeSingleEvent(of: .value) { adminSnap in
                    if let adminDict = adminSnap.value as? [String: Any], let role = adminDict["role"] as? String {
                        self.currentUserRole = role.lowercased()
                    }
                }
            }
        }
    }

    func fetchMessages() {
        let ref = Database.database().reference().child("chats").child(chatUserId).child("messages")
        ref.observe(.value, with: { snapshot in
            var msgs: [ChatMessage] = []
            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let dict = snap.value as? [String: Any] {
                    let msg = ChatMessage(id: snap.key, data: dict)
                    msgs.append(msg)
                }
            }
            let validMsgs = msgs.filter { $0.timestamp > 0 }
            self.messages = validMsgs.sorted {
                if $0.timestamp == $1.timestamp {
                    return $0.id < $1.id
                }
                return $0.timestamp < $1.timestamp
            }
            self.isLoading = false
        }, withCancel: { error in
            print("Error fetching messages: \(error.localizedDescription)")
        })
    }

    func sendMessage() {
        guard !newMessage.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let ref = Database.database().reference().child("chats").child(chatUserId).child("messages").childByAutoId()
        let msgData: [String: Any] = [
            "message": newMessage,
            "sender": currentUserRole, // Send role, not UID
            "timestamp": ServerValue.timestamp()
        ]
        ref.setValue(msgData)
        newMessage = ""
    }
}
