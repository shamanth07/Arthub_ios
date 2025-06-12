import SwiftUI

struct LoginView: View {
    var onSignUp: () -> Void
    var onLoginSuccess: (String) -> Void
    @State private var email = ""
    @State private var password = ""
    @State private var selectedRole = "Visitor"
    @State private var showForgotPasswordAlert = false
    @State private var forgotPasswordEmail = ""
    @State private var forgotPasswordMessage = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    @State private var navigateToHome = false
    @ObservedObject private var authVM = AuthViewModel()
    
    let roles = ["Visitor", "Artist", "Admin"]
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image("arthub_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
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
            
            TextField("Email", text: $email)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 16)
            SecureField("Password", text: $password)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 16)
            
            if showError || authVM.errorMessage != nil {
                Text(errorMessage.isEmpty ? (authVM.errorMessage ?? "") : errorMessage)
                    .foregroundColor(.red)
                    .padding(.horizontal, 16)
            }
            
            Button(action: {
                isLoading = true
                authVM.login(email: email, password: password) { success, error in
                    isLoading = false
                    if success, let actualRole = authVM.userRole {
                        if actualRole.lowercased() == selectedRole.lowercased() {
                            onLoginSuccess(actualRole)
                        } else {
                            errorMessage = "You are not registered as a \(selectedRole)."
                            showError = true
                        }
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
                    Text("Sign In")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(30)
                }
            }
            .padding(.horizontal, 16)
            
            HStack {
                Button(action: {
                    showForgotPasswordAlert = true
                }) {
                    Text("ForgotPassword..? ")
                        .foregroundColor(.gray)
                        .fontWeight(.semibold)
                }
                Spacer()
                Button(action: {
                    onSignUp()
                }) {
                    Text("Don't have an account? Sign up")
                        .foregroundColor(.pink)
                }
            }
            .padding(.horizontal, 16)
            Spacer()
        }
        .alert(isPresented: $showForgotPasswordAlert) {
            Alert(
                title: Text("Reset Password"),
                message: Text("A reset link will be sent to your email."),
                primaryButton: .default(Text("Send"), action: {
                    authVM.sendPasswordReset(email: email) { success, error in
                        forgotPasswordMessage = success ? "Reset link sent! Check your email." : (error ?? "Unknown error")
                        showError = !success
                    }
                }),
                secondaryButton: .cancel()
            )
        }
    }
}

#Preview {
    LoginView(onSignUp: {}, onLoginSuccess: { _ in })
}
