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
    @State private var eventToDelete: Event? = nil
    @State private var showUpdateSuccess = false
    @State private var errorMessage: String? = nil
    @State private var showingManageInvitations = false
    @State private var showMessagesList = false
    @State private var hasUnreadMessages = false
    @State private var unreadMessageCount = 0
  
    let adminEmail: String = "abhishek991116"
    @State private var showCommentsSheet = false
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
                        Button(action: { showMessagesList = true }) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "bell.fill")
                                    .font(.title2)
                                    .foregroundColor(.black)
                                if unreadMessageCount > 0 {
                                    Text("\(unreadMessageCount)")
                                        .font(.caption2)
                                        .foregroundColor(.white)
                                        .padding(5)
                                        .background(Circle().fill(Color.red))
                                        .offset(x: 8, y: -8)
                                }
                            }
                        }
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
                    } else if let errorMessage = errorMessage {
                        Spacer()
                        Text(errorMessage).foregroundColor(.red)
                        Spacer()
                    } else if events.isEmpty {
                        Spacer()
                        HStack { Spacer(); Text("No events found.").foregroundColor(.gray); Spacer() }
                        Spacer()
                    } else {
                        List {
                            ForEach(events) { event in
                                EventCard(
                                    event: event,
                                    onEdit: {
                                            selectedEvent = event
                                            showEditEvent = true
                                    },
                                    onDelete: {
                                            eventToDelete = event
                                    },
                                    onShowComments: {
                                        selectedEvent = event
                                        showCommentsSheet = true
                                    }
                                )
                                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            }
                        }
                        .listStyle(.plain)
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
        .alert(item: $eventToDelete) { event in
            Alert(
                title: Text("Delete Event"),
                message: Text("Are you sure you want to delete this event?"),
                primaryButton: .destructive(Text("Delete")) {
                    deleteEvent(event)
                },
                secondaryButton: .cancel()
            )
        }
        .alert(isPresented: $showUpdateSuccess) {
            Alert(title: Text("Success"), message: Text("Event updated successfully!"), dismissButton: .default(Text("OK")))
        }
        .sheet(isPresented: $showMessagesList) {
            MessageSendersListView(
                currentUserRole: "admin",
                currentUserName: adminUsername
            )
        }
        .sheet(isPresented: $showCommentsSheet) {
            if let event = selectedEvent {
                EventCommentsSheet(eventId: event.id, isVisitor: false)
            }
        }
        .onAppear {
            observeUnreadMessages()
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
        errorMessage = nil
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
    
    func observeUnreadMessages() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        let db = Database.database().reference()
        db.child("chats").observe(.value) { snapshot in
            var count = 0
            let group = DispatchGroup()
            for child in snapshot.children {
                if let chatSnap = child as? DataSnapshot {
                    let chatId = chatSnap.key
                    let ids = chatId.components(separatedBy: "_")
                    guard ids.contains(userId), ids.count == 2 else { continue }
                    let otherUserId = ids.first { $0 != userId } ?? ""
                    group.enter()
                    // Try users first
                    db.child("users").child(otherUserId).observeSingleEvent(of: .value) { userSnap in
                        if let userDict = userSnap.value as? [String: Any], let role = userDict["role"] as? String {
                            let otherUserRole = role.lowercased()
                            let messagesSnap = chatSnap.childSnapshot(forPath: "messages")
                            for msgChild in messagesSnap.children {
                                if let msgSnap = msgChild as? DataSnapshot,
                                   let dict = msgSnap.value as? [String: Any],
                                   let senderId = dict["sender"] as? String,
                                   senderId == otherUserRole,
                                   let isRead = dict["isRead"] as? Bool,
                                   !isRead {
                                    count += 1
                                }
                            }
                            group.leave()
                        } else {
                            // Try admin if not found in users
                            db.child("admin").child(otherUserId).observeSingleEvent(of: .value) { adminSnap in
                                if let adminDict = adminSnap.value as? [String: Any], let role = adminDict["role"] as? String {
                                    let otherUserRole = role.lowercased()
                                    let messagesSnap = chatSnap.childSnapshot(forPath: "messages")
                                    for msgChild in messagesSnap.children {
                                        if let msgSnap = msgChild as? DataSnapshot,
                                           let dict = msgSnap.value as? [String: Any],
                                           let senderId = dict["sender"] as? String,
                                           senderId == otherUserRole,
                                           let isRead = dict["isRead"] as? Bool,
                                           !isRead {
                                            count += 1
                                        }
                                    }
                                    group.leave()
                                } else {
                                    // Not found in users or admin, just leave
                                    group.leave()
                                }
                            }
                        }
                    }
                }
            }
            group.notify(queue: .main) {
                unreadMessageCount = count
            }
        }
    }
    
    var adminUsername: String {
        Auth.auth().currentUser?.email?.components(separatedBy: "@").first ?? "Admin"
    }
}

struct EventCard: View {
    let event: Event
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onShowComments: () -> Void
    var body: some View {
        HStack(spacing: 16) {
            KFImage(URL(string: event.bannerImageUrl))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 80, height: 80)
                .cornerRadius(8)
                .clipped()
            
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
                Text("Max Artists: \(event.maxArtists)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                Button(action: onShowComments) {
                    Text("Comments")
                        .font(.callout)
                        .foregroundColor(.purple)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            
            Spacer()
            
            VStack(spacing: 24) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
            }
            .foregroundColor(.black)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AdminHomeView(onLogout: {})
}
