import Foundation
import FirebaseAuth
import FirebaseDatabase
import Combine

class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    @Published var userRole: String?
    
    private var dbRef: DatabaseReference = Database.database().reference()
    private var cancellables = Set<AnyCancellable>()
    
    func register(email: String, password: String, role: String, completion: @escaping (Bool, String?) -> Void) {
        isLoading = true
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    completion(false, error.localizedDescription)
                    return
                }
                guard let uid = result?.user.uid else {
                    completion(false, "No user ID found.")
                    return
                }
                let userData = ["email": email, "role": role]
                self?.dbRef.child("users").child(uid).setValue(userData) { error, _ in
                    if let error = error {
                        completion(false, error.localizedDescription)
                    } else {
                        // If artist, also create artist info under /artists/{uid}
                        if role.lowercased() == "artist" {
                            let artistData: [String: Any] = [
                                "email": email,
                                "bio": "",
                                "name": email.components(separatedBy: "@").first ?? "Artist",
                                "profileImageUrl": "",
                                "socialLinks": [
                                    "instagram": "",
                                    "website": ""
                                ]
                            ]
                            self?.dbRef.child("artists").child(uid).setValue(artistData)
                        }
                        completion(true, nil)
                    }
                }
            }
        }
    }
    
    func login(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        isLoading = true
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                if let error = error {
                    completion(false, error.localizedDescription)
                } else if let user = result?.user {
                    self?.user = user
                    self?.fetchUserRole(for: user.uid) { role in
                        self?.userRole = role
                        completion(true, nil)
                    }
                } else {
                    completion(false, "Unknown error")
                }
            }
        }
    }
    
    func fetchUserRole(for uid: String, completion: @escaping (String?) -> Void) {
        // Check /users first
        dbRef.child("users").child(uid).observeSingleEvent(of: .value) { snapshot in
            if let value = snapshot.value as? [String: Any], let role = value["role"] as? String {
                completion(role)
            } else {
                // If not found, check /admin
                self.dbRef.child("admin").child(uid).observeSingleEvent(of: .value) { adminSnapshot in
                    if let adminValue = adminSnapshot.value as? [String: Any], let adminRole = adminValue["role"] as? String {
                        completion(adminRole)
                    } else {
                        completion(nil)
                    }
                }
            }
        }
    }
    
    func sendPasswordReset(email: String, completion: @escaping (Bool, String?) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                completion(false, error.localizedDescription)
            } else {
                completion(true, nil)
            }
        }
    }
} 
