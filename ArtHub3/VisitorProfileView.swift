import SwiftUI
import FirebaseAuth
import PhotosUI
import FirebaseDatabase
import FirebaseStorage

struct VisitorProfileView: View {
    @State private var username: String = Auth.auth().currentUser?.email?.components(separatedBy: "@").first ?? "Visitor"
    @State private var email: String = Auth.auth().currentUser?.email ?? ""
    @State private var profileImage: UIImage? = nil
    @State private var profileImageUrl: String? = nil
    @State private var showImagePicker = false
    @State private var showChangePassword = false
    @State private var newPassword = ""
    @State private var showPasswordAlert = false
    @State private var passwordChangeMessage = ""
    @State private var isEditing = false
    @State private var editedUsername = ""
    @State private var isSaving = false
    @State private var errorMessage: String? = nil
    @Environment(\.presentationMode) var presentationMode
    @State private var showChangePasswordSheet = false
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
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
                    if let image = profileImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else if let url = profileImageUrl, let imageUrl = URL(string: url) {
                        ImageLoaderView(imageUrl: imageUrl)
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle")
                            .resizable()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.orange)
                    }
                    Button(action: { showImagePicker = true }) {
                        Image(systemName: "pencil")
                            .foregroundColor(.black)
                            .padding(6)
                            .background(Color.white)
                            .clipShape(Circle())
                            .offset(x: 8, y: -8)
                    }
                }
                if isEditing {
                    TextField("Username", text: $editedUsername)
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                } else {
                    Text("\(username)(visitor)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .padding(.top, 4)
                }
                Button(isEditing ? (isSaving ? "Saving..." : "Save") : "Edit Profile") {
                    if isEditing {
                        saveProfile()
                    } else {
                        editedUsername = username
                        isEditing = true
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.top, 2)
                .disabled(isSaving)
                if let errorMessage = errorMessage {
                    Text(errorMessage).foregroundColor(.red).font(.caption)
                }
            }
            .padding(.bottom, 16)
            VStack(alignment: .leading, spacing: 16) {
                Text("Email:")
                    .font(.title3)
                    .fontWeight(.bold)
                Text(email)
                    .foregroundColor(.gray)
                    .padding(.bottom, 8)
                Divider()
                Button(action: { showChangePasswordSheet = true }) {
                    Text("Change Password")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
            }
            .padding(.horizontal)
            Spacer()
        }
        .background(Color(.systemGray6).ignoresSafeArea())
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $profileImage)
                .onDisappear {
                    if let image = profileImage, isEditing {
                        uploadProfileImage(image: image)
                    }
                }
        }
        .sheet(isPresented: $showChangePasswordSheet) {
            VStack(spacing: 24) {
                Text("Change Password")
                    .font(.title2)
                    .fontWeight(.bold)
                SecureField("New Password", text: $newPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                HStack {
                    Button("Cancel") {
                        showChangePasswordSheet = false
                        newPassword = ""
                    }
                    .foregroundColor(.red)
                    Spacer()
                    Button("Save") {
                        changePassword()
                        showChangePasswordSheet = false
                    }
                    .disabled(newPassword.isEmpty)
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .alert(isPresented: $showPasswordAlert) {
            Alert(title: Text("Password Change"), message: Text(passwordChangeMessage), dismissButton: .default(Text("OK")))
        }
        .onAppear(perform: fetchProfile)
    }
    
    func fetchProfile() {
        guard let user = Auth.auth().currentUser else { return }
        let uid = user.uid
        let ref = Database.database().reference().child("users").child(uid).child("profile")
        ref.observeSingleEvent(of: .value) { snapshot in
            if let dict = snapshot.value as? [String: Any] {
                self.username = dict["username"] as? String ?? user.email?.components(separatedBy: "@").first ?? "Visitor"
                self.email = dict["email"] as? String ?? user.email ?? ""
                self.profileImageUrl = dict["profileImageUrl"] as? String
            } else {
                self.username = user.email?.components(separatedBy: "@").first ?? "Visitor"
                self.email = user.email ?? ""
                self.profileImageUrl = nil
            }
        }
    }

    func saveProfile() {
        isSaving = true
        errorMessage = nil
        guard let user = Auth.auth().currentUser else {
            errorMessage = "Not logged in."
            isSaving = false
            return
        }
        let uid = user.uid
        let ref = Database.database().reference().child("users").child(uid).child("profile")
        let profileData: [String: Any] = [
            "username": editedUsername,
            "email": email,
            "profileImageUrl": profileImageUrl ?? ""
        ]
        ref.setValue(profileData) { error, _ in
            isSaving = false
            if let error = error {
                errorMessage = "Save error: \(error.localizedDescription)"
            } else {
                username = editedUsername
                isEditing = false
            }
        }
    }

    func uploadProfileImage(image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.8), let user = Auth.auth().currentUser else { return }
        let storageRef = Storage.storage().reference()
        let fileName = "profile_images/\(user.uid).jpg"
        let imageRef = storageRef.child(fileName)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        imageRef.putData(data, metadata: metadata) { metadata, error in
            if let error = error {
                errorMessage = "Image upload error: \(error.localizedDescription)"
                return
            }
            imageRef.downloadURL { url, error in
                if let url = url {
                    profileImageUrl = url.absoluteString
                }
            }
        }
    }
    
    func changePassword() {
        guard !newPassword.isEmpty else { return }
        Auth.auth().currentUser?.updatePassword(to: newPassword) { error in
            if let error = error {
                passwordChangeMessage = error.localizedDescription
            } else {
                passwordChangeMessage = "Password changed successfully."
            }
            showPasswordAlert = true
            newPassword = ""
        }
    }
}

struct ImageLoaderView: View {
    let imageUrl: URL
    var body: some View {
        ZStack {
            Color.gray.opacity(0.2)
            AsyncImage(url: imageUrl) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                ProgressView()
            }
        }
    }
}

// Simple UIKit image picker wrapper for SwiftUI
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.image = uiImage
            }
            picker.dismiss(animated: true)
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    VisitorProfileView()
}
