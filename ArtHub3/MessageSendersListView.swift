import SwiftUI
import FirebaseDatabase
import FirebaseAuth

struct MessageSender: Identifiable, Equatable {
    let id: String // userId
    let email: String
    let role: String
    let chatId: String
    let messageCount: Int
}

struct MessageSendersListView: View {
    let currentUserId: String = Auth.auth().currentUser?.uid ?? ""
    let currentUserRole: String
    let currentUserName: String
    @Environment(\.dismiss) private var dismiss
    @State private var senders: [MessageSender] = []
    @State private var isLoading = true
    @State private var selectedSender: MessageSender? = nil
    
    var body: some View {
        NavigationView {
            List(senders) { sender in
                Button(action: { selectedSender = sender }) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(sender.email)
                                .font(.headline)
                            Spacer()
                            if sender.messageCount > 0 {
                                Text("\(sender.messageCount)")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                                    .padding(5)
                                    .background(Circle().fill(Color.red))
                            }
                        }
                        Text("Role: \(sender.role)")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Users Who Messaged Me")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay(
                Group {
                    if isLoading {
                        ProgressView()
                    }
                }
            )
            .sheet(item: $selectedSender) { sender in
                LiveChatView(
                    chatUserId: sender.id,
                    chatUserEmail: sender.email,
                    chatUserRole: sender.role
                )
            }
        }
        .onAppear(perform: fetchSenders)
    }
    
    func fetchSenders() {
        isLoading = true
        let db = Database.database().reference()
        db.child("chats").observeSingleEvent(of: .value) { snapshot in
            var found: [MessageSender] = []
            let group = DispatchGroup()
            for child in snapshot.children {
                if let chatSnap = child as? DataSnapshot {
                    let chatId = chatSnap.key
                    let ids = chatId.components(separatedBy: "_")
                    guard ids.contains(currentUserId), ids.count == 2 else { continue }
                    let otherUserId = ids.first { $0 != currentUserId } ?? ""
                    // Find the other user's role from the users/admin node
                    var otherUserRole = ""
                    group.enter()
                    db.child("users").child(otherUserId).observeSingleEvent(of: .value) { userSnap in
                        if let userDict = userSnap.value as? [String: Any], let role = userDict["role"] as? String {
                            otherUserRole = role.lowercased()
                            processMessages(otherUserRole: otherUserRole)
                        } else {
                            db.child("admin").child(otherUserId).observeSingleEvent(of: .value) { adminSnap in
                                if let adminDict = adminSnap.value as? [String: Any], let role = adminDict["role"] as? String {
                                    otherUserRole = role.lowercased()
                                }
                                processMessages(otherUserRole: otherUserRole)
                            }
                        }
                    }
                    func processMessages(otherUserRole: String) {
                        let messagesSnap = chatSnap.childSnapshot(forPath: "messages")
                        var unreadCount = 0
                        for msgChild in messagesSnap.children {
                            if let msgSnap = msgChild as? DataSnapshot,
                               let dict = msgSnap.value as? [String: Any],
                               let senderId = dict["sender"] as? String,
                               senderId == otherUserRole,
                               let isRead = dict["isRead"] as? Bool,
                               !isRead {
                                unreadCount += 1
                            }
                        }
                        if unreadCount > 0 {
                            // Try users first for email
                            db.child("users").child(otherUserId).observeSingleEvent(of: .value) { userSnap in
                                if let userDict = userSnap.value as? [String: Any], let email = userDict["email"] as? String, let role = userDict["role"] as? String {
                                    found.append(MessageSender(id: otherUserId, email: email, role: role, chatId: chatId, messageCount: unreadCount))
                                    group.leave()
                                } else {
                                    // Try admin next
                                    db.child("admin").child(otherUserId).observeSingleEvent(of: .value) { adminSnap in
                                        if let adminDict = adminSnap.value as? [String: Any], let email = adminDict["email"] as? String, let role = adminDict["role"] as? String {
                                            found.append(MessageSender(id: otherUserId, email: email, role: role, chatId: chatId, messageCount: unreadCount))
                                            group.leave()
                                        } else {
                                            // Try visitors last
                                            db.child("visitors").child(otherUserId).observeSingleEvent(of: .value) { visitorSnap in
                                                if let visitorDict = visitorSnap.value as? [String: Any], let email = visitorDict["email"] as? String {
                                                    found.append(MessageSender(id: otherUserId, email: email, role: "visitor", chatId: chatId, messageCount: unreadCount))
                                                }
                                                group.leave()
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            group.leave()
                        }
                    }
                }
            }
            group.notify(queue: .main) {
                senders = found
                isLoading = false
            }
        }
    }
}
