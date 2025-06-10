import SwiftUI

struct AdminAccountView: View {
    var adminEmail: String
    var onBack: () -> Void
    var onLogout: () -> Void
    @State private var showProfile = false
    
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
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.orange)
                    .padding(.top, 8)
                Text("\(adminEmail)(Admin)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .padding(.top, 4)
            }
            .padding(.bottom, 16)
            
            VStack(spacing: 0) {
                Button(action: { showProfile = true }) {
                    AccountRow(icon: "person.crop.circle", label: "Profile")
                }
                Divider()
                AccountRow(icon: "pencil", label: "Create Event")
                Divider()
                AccountRow(icon: "person.2.badge.gearshape", label: "Manage Invitations")
                Divider()
                AccountRow(icon: "chart.bar", label: "Reports")
                Divider()
                AccountRow(icon: "gearshape", label: "Settings")
            }
            .background(Color.white)
            .cornerRadius(12)
            .padding(.horizontal)
            .padding(.bottom, 24)
            Spacer()
            Button(action: onLogout) {
                Text("Logout")
                    .foregroundColor(.white)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .cornerRadius(30)
            }
            .padding(.horizontal)
            .padding(.bottom, 16)
        }
        .background(Color.white.ignoresSafeArea())
        .fullScreenCover(isPresented: $showProfile) {
            AdminProfileView(adminEmail: adminEmail, onBack: { showProfile = false })
        }
    }
}

struct AccountRow: View {
    var icon: String
    var label: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            Text(label)
                .font(.headline)
                .foregroundColor(.black)
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
    }
}

#Preview {
    AdminAccountView(adminEmail: "abhishek991116", onBack: {}, onLogout: {})
} 