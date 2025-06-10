import SwiftUI

struct RegisterView: View {
    var onSignIn: () -> Void
    var onRegisterSuccess: () -> Void
    @State private var email = ""
    @State private var password = ""
    @State private var selectedRole = "Visitor"
    @State private var agreedToTerms = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var isLoading = false
    @ObservedObject private var authVM = AuthViewModel()
    
    let roles = ["Visitor", "Artist"]
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image("arthub_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
            Text("ARTHUB")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.black)
            
            Picker("Role", selection: $selectedRole) {
                ForEach(roles, id: \.self) { role in
                    Text(role)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Email")
                    .fontWeight(.semibold)
                TextField("Your email address", text: $email)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 16)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Password")
                    .fontWeight(.semibold)
                SecureField("Your password", text: $password)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(.horizontal, 16)
            
            HStack {
                Button(action: {
                    agreedToTerms.toggle()
                }) {
                    Image(systemName: agreedToTerms ? "checkmark.square" : "square")
                }
                Text("I agree to the ")
                + Text("Terms of Services and Privacy Policy.")
                    .foregroundColor(.red)
                    .fontWeight(.bold)
            }
            .padding(.horizontal, 16)
            
            if showError || authVM.errorMessage != nil {
                Text(errorMessage.isEmpty ? (authVM.errorMessage ?? "") : errorMessage)
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
            }
            
            Button(action: {
                isLoading = true
                authVM.register(email: email, password: password, role: selectedRole) { success, error in
                    isLoading = false
                    if success {
                        onRegisterSuccess()
                    } else {
                        errorMessage = error ?? "Unknown error"
                        showError = true
                    }
                }
            }) {
                if isLoading || authVM.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(30)
                } else {
                    Text("Sign Up")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(agreedToTerms ? Color.black : Color.gray)
                        .cornerRadius(30)
                }
            }
            .disabled(!agreedToTerms || email.isEmpty || password.isEmpty || isLoading || authVM.isLoading)
            .padding(.horizontal, 16)
            
            Button(action: {
                onSignIn()
            }) {
                Text("Have an Account? SignIn")
                    .foregroundColor(.red)
                    .fontWeight(.semibold)
            }
            .padding(.top, 8)
            Spacer()
        }
    }
}

#Preview {
    RegisterView(onSignIn: {}, onRegisterSuccess: {})
} 
