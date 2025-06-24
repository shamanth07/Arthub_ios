import SwiftUI
import PhotosUI
import FirebaseAuth

struct AdminProfileView: View {
    var adminEmail: String
    var onBack: () -> Void
    @State private var showImagePicker = false
    @State private var selectedImage: PhotosPickerItem? = nil
    @State private var profileUIImage: UIImage? = nil
    @State private var showChangePassword = false
    @State private var newPassword = ""
    @State private var passwordChangeMessage = ""
    @State private var isChangingPassword = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "arrow.left.circle.fill")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundColor(.blue)
                }
                Spacer()
            }
            .padding([.top, .leading])
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    if let image = profileUIImage {
                        Image(uiImage: image)
                            .resizable()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .padding(.top, 8)
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.orange)
                            .padding(.top, 8)
                    }
                    PhotosPicker(selection: $selectedImage, matching: .images, photoLibrary: .shared()) {
                        Image(systemName: "pencil")
                            .foregroundColor(.black)
                            .padding(6)
                            .background(Color.white)
                            .clipShape(Circle())
                            .offset(x: 8, y: -8)
                    }
                    .onChange(of: selectedImage) { newItem in
                        if let newItem {
                            Task {
                                if let data = try? await newItem.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    profileUIImage = uiImage
                                    // Optionally upload to Firebase Storage here
                                }
                            }
                        }
                    }
                }
                Text("\(adminEmail)(Admin)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.top, 4)
            }
            .padding(.bottom, 24)
            VStack(alignment: .leading, spacing: 16) {
                Text("Email:")
                    .font(.title3)
                    .fontWeight(.bold)
                Text(adminEmail)
                    .foregroundColor(.gray)
                    .font(.title3)
                    .padding(.bottom, 8)
                Divider()
                Button(action: { showChangePassword.toggle() }) {
                    Text("Change Password")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                }
                if showChangePassword {
                    SecureField("New Password", text: $newPassword)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.vertical, 4)
                    Button(action: changePassword) {
                        if isChangingPassword {
                            ProgressView()
                        } else {
                            Text("Update Password")
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.top, 4)
                    if !passwordChangeMessage.isEmpty {
                        Text(passwordChangeMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                Divider()
                NavigationLink(destination: LiveChatUserListView()) {
                    Text("Live Chat")
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            Spacer()
        }
        .background(Color.gray.opacity(0.1).ignoresSafeArea())
    }
    
    func changePassword() {
        guard !newPassword.isEmpty else {
            passwordChangeMessage = "Password cannot be empty."
            return
        }
        isChangingPassword = true
        passwordChangeMessage = ""
        Auth.auth().currentUser?.updatePassword(to: newPassword) { error in
            isChangingPassword = false
            if let error = error {
                passwordChangeMessage = error.localizedDescription
            } else {
                passwordChangeMessage = "Password updated successfully."
                newPassword = ""
                showChangePassword = false
            }
        }
    }
}

#Preview {
    AdminProfileView(adminEmail: "abhishek991116@gmail.com", onBack: {})
}
