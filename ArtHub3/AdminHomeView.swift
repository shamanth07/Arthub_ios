import SwiftUI
import FirebaseDatabase
import FirebaseAuth
import Kingfisher

struct AdminHomeView: View {
    @State private var events: [Event] = []
    @State private var showCreateEvent = false
    @State private var isLoading = true
    @State private var showAccount = false
    @State private var showEditEvent = false
    @State private var selectedEvent: Event? = nil
    @State private var showDeleteConfirmation = false
    @State private var eventToDelete: Event? = nil
    @State private var showUpdateSuccess = false
    // Replace with actual admin email from auth if available
    let adminEmail: String = "abhishek991116"
    var onLogout: () -> Void
    
    var body: some View {
        ZStack {
            NavigationView {
                VStack(alignment: .leading) {
                    HStack {
                        Button(action: { showAccount = true }) {
                            Image(systemName: "line.horizontal.3")
                                .font(.title)
                                .foregroundColor(.black)
                        }
                        Button(action: { fetchEvents() }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.title)
                                .foregroundColor(.blue)
                                .padding(.leading, 8)
                        }
                        Spacer()
                        Text("Admin")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        showCreateEvent = true
                    }) {
                        Text("Create Event")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .cornerRadius(30)
                            .font(.headline)
                    }
                    .padding([.horizontal, .top])
                    
                    Text("Created Events")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    
                    if isLoading {
                        Spacer()
                        HStack { Spacer(); ProgressView(); Spacer() }
                        Spacer()
                    } else if events.isEmpty {
                        Spacer()
                        HStack { Spacer(); Text("No events found.").foregroundColor(.gray); Spacer() }
                        Spacer()
                    } else {
                        ScrollView {
                            VStack(spacing: 16) {
                                ForEach(events) { event in
                                    HStack(alignment: .top, spacing: 12) {
                                        ZStack {
                                            Color.gray.opacity(0.2)
                                            KFImage(URL(string: event.bannerImageUrl))
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        }
                                        .frame(width: 60, height: 60)
                                        .cornerRadius(8)
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(event.title)
                                                .font(.headline)
                                                .fontWeight(.bold)
                                            Text(event.eventDate, style: .date)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                            Text(event.time)
                                                .font(.subheadline)
                                                .foregroundColor(.gray)
                                        }
                                        Spacer()
                                        VStack(spacing: 12) {
                                            Button(action: {
                                                selectedEvent = event
                                                showEditEvent = true
                                            }) {
                                                Image(systemName: "pencil")
                                                    .foregroundColor(.black)
                                            }
                                            Button(action: {
                                                eventToDelete = event
                                                showDeleteConfirmation = true
                                            }) {
                                                Image(systemName: "trash")
                                                    .foregroundColor(.black)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    Spacer()
                }
                .sheet(isPresented: $showCreateEvent, onDismiss: fetchEvents) {
                    CreateEventView(onEventCreated: {
                        showCreateEvent = false
                        fetchEvents()
                    })
                }
                .onAppear(perform: fetchEvents)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            
            // Admin Account Page Overlay
            if showAccount {
                AdminAccountView(
                    adminEmail: adminEmail,
                    onBack: { showAccount = false },
                    onLogout: {
                        logout()
                    }
                )
                .transition(.move(edge: .leading))
                .zIndex(1)
            }
            
            // Debug Text
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text(selectedEvent != nil ? "Selected Event: \(selectedEvent!.id)" : "No event selected")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(6)
                        .background(Color.white.opacity(0.7))
                        .cornerRadius(8)
                        .padding()
                }
            }
        }
        .sheet(isPresented: $showEditEvent) {
            if let event = selectedEvent {
                EditEventView(event: event) {
                    showEditEvent = false
                    selectedEvent = nil
                    showUpdateSuccess = true
                    fetchEvents()
                }
            }
        }
        .alert(isPresented: $showDeleteConfirmation) {
            Alert(
                title: Text("Delete Event"),
                message: Text("Are you sure you want to delete this event?"),
                primaryButton: .destructive(Text("Delete"), action: {
                    if let event = eventToDelete {
                        deleteEvent(event)
                        eventToDelete = nil
                    }
                }),
                secondaryButton: .cancel({ eventToDelete = nil })
            )
        }
        .alert(isPresented: $showUpdateSuccess) {
            Alert(title: Text("Success"), message: Text("Event updated successfully!"), dismissButton: .default(Text("OK")))
        }
    }
    
    func logout() {
        do {
            try Auth.auth().signOut()
            onLogout()
        } catch {
            print("Logout error: \(error.localizedDescription)")
        }
    }
    
    func fetchEvents() {
        isLoading = true
        print("Fetching events from Firebase...")
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
                print("Fetched \(fetched.count) events.")
                self.events = fetched
                self.isLoading = false
            }
        }
    }
    
    func deleteEvent(_ event: Event) {
        print("Attempting to delete event with id: \(event.id)")
        let ref = Database.database().reference().child("events").child(event.id)
        ref.removeValue { error, _ in
            if let error = error {
                print("Delete error: \(error.localizedDescription)")
            } else {
                print("Event deleted successfully.")
                fetchEvents()
            }
        }
    }
}

#Preview {
    AdminHomeView(onLogout: {})
}
