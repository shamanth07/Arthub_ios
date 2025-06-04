import SwiftUI
import FirebaseAuth
import FirebaseDatabase

class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var role: String = "Visitor"
    
    private var dbRef = Database.database().reference()
    
    init() {
        try? Auth.auth().signOut()
        self.user = nil
        self.role = ""
        fetchUserRole()
    }
    
    func signIn(email: String, password: String, role: String, completion: @escaping (Bool) -> Void) {
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
                self?.user = result?.user
                guard let uid = result?.user.uid else {
                    self?.errorMessage = "User not found"
                    completion(false)
                    return
                }
                // First, check users node
                self?.dbRef.child("users").child(uid).observeSingleEvent(of: .value) { snapshot in
                    if let userData = snapshot.value as? [String: Any],
                       let userRole = userData["role"] as? String {
                        self?.role = userRole
                        if userRole.lowercased() == role.lowercased() {
                            completion(true)
                        } else {
                            self?.errorMessage = "Incorrect role for this account."
                            try? Auth.auth().signOut()
                            self?.user = nil
                            completion(false)
                        }
                    } else {
                        // If not found in users, check admin node
                        self?.dbRef.child("admin").child(uid).observeSingleEvent(of: .value) { adminSnap in
                            if let adminData = adminSnap.value as? [String: Any],
                               let adminRole = adminData["role"] as? String {
                                self?.role = adminRole
                                if adminRole.lowercased() == role.lowercased() {
                                    completion(true)
                                } else {
                                    self?.errorMessage = "Incorrect role for this account."
                                    try? Auth.auth().signOut()
                                    self?.user = nil
                                    completion(false)
                                }
                            } else {
                                self?.errorMessage = "User data not found"
                                try? Auth.auth().signOut()
                                self?.user = nil
                                completion(false)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func signUp(email: String, password: String, role: String, completion: @escaping (Bool) -> Void) {
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
                guard let uid = result?.user.uid else {
                    self?.errorMessage = "User creation failed."
                    completion(false)
                    return
                }
                let userDict: [String: Any] = ["email": email, "role": role]
                self?.dbRef.child("users").child(uid).setValue(userDict)
                self?.user = result?.user
                self?.role = role
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
                } else {
                    completion(true)
                }
            }
        }
    }
    
    func signOut() {
        try? Auth.auth().signOut()
        self.user = nil
        self.role = "Visitor"
    }
    
    func fetchUserRole(completion: (() -> Void)? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else {
            self.role = "Visitor"
            completion?()
            return
        }
        dbRef.child("users").child(uid).observeSingleEvent(of: .value) { snapshot in
            if let dict = snapshot.value as? [String: Any], let role = dict["role"] as? String {
                DispatchQueue.main.async {
                    self.role = role
                    completion?()
                }
            } else {
                DispatchQueue.main.async {
                    self.role = "Visitor"
                    completion?()
                }
            }
        }
    }
} 