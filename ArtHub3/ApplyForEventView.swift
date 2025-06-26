import SwiftUI
import FirebaseDatabase
import FirebaseAuth
import Kingfisher

struct ApplyForEventView: View {
    var onClose: () -> Void
    @State private var events: [Event] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var appliedEventIds: Set<String> = []
    @State private var showSuccess = false
    @State private var successMessage = ""
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "arrow.left.circle.fill")
                            .resizable()
                            .frame(width: 32, height: 32)
                            .foregroundColor(.blue)
                    }
                    Spacer()
                    Text("Upcoming Events")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.trailing, 32)
                    Spacer()
                }
                .padding(.top)
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let errorMessage = errorMessage {
                    Spacer()
                    Text(errorMessage).foregroundColor(.red)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(events) { event in
                                VStack(alignment: .leading, spacing: 8) {
                                    ZStack {
                                        Color.gray.opacity(0.2)
                                        KFImage(URL(string: event.bannerImageUrl))
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    }
                                    .frame(height: 180)
                                    .cornerRadius(8)
                                    .clipped()
                                    Text(event.title)
                                        .font(.headline)
                                    Text(event.eventDate, style: .date) + Text(" - ") + Text(event.time)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    Button(action: { applyToEvent(event) }) {
                                        Text(appliedEventIds.contains(event.id) ? "Applied" : "Apply")
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 32)
                                            .padding(.vertical, 10)
                                            .background(appliedEventIds.contains(event.id) ? Color.gray : Color.blue)
                                            .cornerRadius(30)
                                    }
                                    .disabled(appliedEventIds.contains(event.id))
                                }
                                .padding()
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(radius: 2)
                                .padding(.horizontal)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .onAppear(perform: fetchEvents)
            .alert(isPresented: $showSuccess) {
                Alert(title: Text("Success"), message: Text(successMessage), dismissButton: .default(Text("OK")))
            }
        }
    }
    func fetchEvents() {
        isLoading = true
        errorMessage = nil
        let ref = Database.database().reference().child("events")
        ref.observeSingleEvent(of: .value) { snapshot in
            var fetched: [Event] = []
            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let dict = snap.value as? [String: Any],
                   let title = dict["title"] as? String,
                   let description = dict["description"] as? String,
                   let eventDateMillis = dict["eventDate"] as? Double,
                   let time = dict["time"] as? String,
                   let location = dict["location"] as? String,
                   let latitude = dict["latitude"] as? Double,
                   let longitude = dict["longitude"] as? Double,
                   let maxArtists = dict["maxArtists"] as? Int,
                   let ticketPrice = dict["ticketPrice"] as? Double,
                   let bannerImageUrl = dict["bannerImageUrl"] as? String {
                    let eventDate = Date(timeIntervalSince1970: eventDateMillis / 1000)
                    let event = Event(
                        id: snap.key,
                        title: title,
                        description: description,
                        eventDate: eventDate,
                        time: time,
                        location: location,
                        latitude: latitude,
                        longitude: longitude,
                        maxArtists: maxArtists,
                        ticketPrice: ticketPrice,
                        bannerImageUrl: bannerImageUrl
                    )
                    fetched.append(event)
                }
            }
            DispatchQueue.main.async {
                self.events = fetched
                self.isLoading = false
                fetchAppliedEvents()
            }
        }
    }
    func fetchAppliedEvents() {
        guard let user = Auth.auth().currentUser else { return }
        let artistId = user.uid
        let ref = Database.database().reference().child("invitations")
        ref.observeSingleEvent(of: .value) { snapshot in
            var applied: Set<String> = []
            for eventChild in snapshot.children {
                if let eventSnap = eventChild as? DataSnapshot {
                    if eventSnap.hasChild(artistId) {
                        applied.insert(eventSnap.key)
                    }
                }
            }
            DispatchQueue.main.async {
                self.appliedEventIds = applied
            }
        }
    }
    func applyToEvent(_ event: Event) {
        guard let user = Auth.auth().currentUser else { return }
        let artistId = user.uid
        let artistName = user.email?.components(separatedBy: "@").first ?? "Artist"
        let email = user.email ?? ""
        let ref = Database.database().reference().child("invitations").child(event.id).child(artistId)
        let data: [String: Any] = [
            "artistName": artistName,
            "email": email,
            "status": "pending",
            "appliedAt": Int(Date().timeIntervalSince1970)
        ]
        ref.setValue(data) { error, _ in
            if let error = error {
                errorMessage = error.localizedDescription
            } else {
                appliedEventIds.insert(event.id)
                successMessage = "Applied to event successfully!"
                showSuccess = true
                onClose()
            }
        }
    }
}

