import SwiftUI
import FirebaseDatabase
import FirebaseAuth

struct ManageInvitationsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var invitations: [ArtistInvitation] = []
    @State private var isLoading = true
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedInvitation: ArtistInvitation?
    @State private var showInvitationDetail = false
    @State private var eventTitles: [String: String] = [:] // eventId: eventTitle
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    if isLoading {
                        ProgressView()
                    } else if invitations.isEmpty {
                        Text("No Invitations Found.")
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ForEach(invitations) { invitation in
                            InvitationCard(invitation: invitation, eventTitle: eventTitles[invitation.eventId] ?? invitation.eventId, onStatusChange: { status in
                                updateInvitationStatus(invitation: invitation, status: status)
                            })
                        }
                    }
                }
                .padding(.top)
            }
            .navigationTitle("Invitations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "line.horizontal.3")
                            .font(.title2)
                            .foregroundColor(.black)
                    }
                }
            }
            .alert("Invitation Update", isPresented: $showAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        }
        .onAppear {
            fetchEventTitlesAndInvitations()
        }
    }
    
    private func fetchEventTitlesAndInvitations() {
        isLoading = true
        let eventsRef = Database.database().reference().child("events")
        eventsRef.observeSingleEvent(of: .value) { snapshot in
            var titles: [String: String] = [:]
            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let dict = snap.value as? [String: Any],
                   let title = dict["title"] as? String {
                    titles[snap.key] = title
                }
            }
            self.eventTitles = titles
            fetchInvitations()
        }
    }
    
    private func fetchInvitations() {
        let ref = Database.database().reference().child("invitations")
        ref.observeSingleEvent(of: .value) { snapshot in
            var loaded: [ArtistInvitation] = []
            for eventChild in snapshot.children {
                if let eventSnap = eventChild as? DataSnapshot {
                    let eventId = eventSnap.key
                    for artistChild in eventSnap.children {
                        if let artistSnap = artistChild as? DataSnapshot,
                           let dict = artistSnap.value as? [String: Any],
                           let status = dict["status"] as? String {
                            let artistId = artistSnap.key
                            let artistName = dict["artistName"] as? String ?? ""
                            let artistEmail = dict["email"] as? String ?? ""
                            let appliedAt = dict["appliedAt"] as? Double ?? 0
                            let invitation = ArtistInvitation(
                                id: eventId + "_" + artistId,
                                artistId: artistId,
                                artistName: artistName,
                                artistEmail: artistEmail,
                                eventId: eventId,
                                eventTitle: eventTitles[eventId] ?? eventId,
                                eventDate: "",
                                status: status,
                                createdAt: Date(timeIntervalSince1970: appliedAt),
                                updatedAt: nil
                            )
                            loaded.append(invitation)
                        }
                    }
                }
            }
            DispatchQueue.main.async {
                self.invitations = loaded.sorted { $0.createdAt > $1.createdAt }
                self.isLoading = false
            }
        }
    }
    
    private func updateInvitationStatus(invitation: ArtistInvitation, status: String) {
        let ref = Database.database().reference().child("invitations").child(invitation.eventId).child(invitation.artistId)
        ref.updateChildValues(["status": status]) { error, _ in
            if let error = error {
                alertMessage = "Error updating invitation: \(error.localizedDescription)"
                showAlert = true
            } else {
                fetchEventTitlesAndInvitations()
            }
        }
    }
}

struct InvitationCard: View {
    let invitation: ArtistInvitation
    let eventTitle: String
    var onStatusChange: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Event: \(eventTitle)")
                .font(.headline)
                .fontWeight(.bold)
            Text("Artist: \(invitation.artistName)")
                .font(.subheadline)
            Text("Email: \(invitation.artistEmail)")
                .font(.subheadline)
            Text("Status: \(invitation.status.uppercased())")
                .font(.subheadline)
            HStack(spacing: 16) {
                if invitation.status.lowercased() == "pending" {
                    Button(action: { onStatusChange("accepted") }) {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Accept")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .cornerRadius(30)
                    }
                    Button(action: { onStatusChange("rejected") }) {
                        Text("Reject")
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.pink)
                            .cornerRadius(30)
                    }
                } else if invitation.status.lowercased() == "accepted" {
                    Text("Confirmed")
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .cornerRadius(30)
                } else if invitation.status.lowercased() == "rejected" {
                    Text("Rejected")
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(Color.pink)
                        .cornerRadius(30)
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(radius: 2)
        .padding(.horizontal)
        .padding(.bottom, 8)
    }
}

struct ArtistInvitation: Identifiable, Codable {
    var id: String
    var artistId: String
    var artistName: String
    var artistEmail: String
    var eventId: String
    var eventTitle: String
    var eventDate: String
    var status: String
    var createdAt: Date
    var updatedAt: Date?
}

#Preview {
    ManageInvitationsView()
} 
