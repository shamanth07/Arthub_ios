import Foundation
import SwiftUI

class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var user: String? // Placeholder for user object

    func signIn(email: String, password: String, completion: @escaping (Bool) -> Void) {
        // TODO: Implement authentication logic
        completion(true)
    }

    func signOut() {
        user = nil
    }
} 