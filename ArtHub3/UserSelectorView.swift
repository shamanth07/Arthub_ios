import SwiftUI
import FirebaseDatabase

struct UserSelectorView: View {
    var currentUserId: String
    var currentUserRole: String
    var onUserSelected: (String, String, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var users: [(id: String, name: String, role: String)] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationView {
            List(users, id: \.id) { user in
                Button(action: {
                    onUserSelected(user.id, user.name, user.role)
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: user.role.lowercased() == "admin" ? "person.crop.circle.badge.checkmark" : user.role.lowercased() == "artist" ? "paintbrush" : "person")
                            .foregroundColor(user.role.lowercased() == "admin" ? .purple : user.role.lowercased() == "artist" ? .orange : .blue)
                        Text(user.name)
                        Spacer()
                        Text(user.role.capitalized)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Select User to Chat")
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
        }
        .onAppear(perform: fetchUsers)
    }
    
    func fetchUsers() {
        isLoading = true
        var loaded: [(String, String, String)] = []
        let db = Database.database().reference()
        // Fetch admins
        db.child("admin").observeSingleEvent(of: .value) { snap in
            if let dict = snap.value as? [String: Any] {
                for (id, value) in dict {
                    if id != currentUserId, let v = value as? [String: Any], let email = v["email"] as? String, let role = v["role"] as? String {
                        loaded.append((id, email, role))
                    }
                }
            }
            // Fetch users (artists and visitors)
            db.child("users").observeSingleEvent(of: .value) { snap in
                if let dict = snap.value as? [String: Any] {
                    for (id, value) in dict {
                        if id != currentUserId, let v = value as? [String: Any], let email = v["email"] as? String, let role = v["role"] as? String {
                            loaded.append((id, email, role))
                        }
                    }
                }
                users = loaded
                isLoading = false
            }
        }
    }
}
