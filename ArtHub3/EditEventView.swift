import SwiftUI
import FirebaseDatabase
import MapKit
import PhotosUI
import FirebaseStorage
import Kingfisher

struct EditEventView: View {
    let event: Event
    var onEventUpdated: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var description: String
    @State private var eventDate: Date
    @State private var time: String
    @State private var location: String
    @State private var latitude: Double
    @State private var longitude: Double
    @State private var maxArtists: String
    @State private var ticketPrice: String
    @State private var bannerImageUrl: String
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    @State private var region: MKCoordinateRegion
    @State private var searchQuery = ""
    @State private var searchResults: [MKMapItem] = []
    @FocusState private var searchFieldFocused: Bool
    @State private var selectedBannerImage: PhotosPickerItem? = nil
    @State private var bannerUIImage: UIImage? = nil
    @State private var placeSuggestions: [PlaceSuggestion] = []
    @State private var isFetchingSuggestions = false
    
    init(event: Event, onEventUpdated: @escaping () -> Void) {
        self.event = event
        self.onEventUpdated = onEventUpdated
        _title = State(initialValue: event.title)
        _description = State(initialValue: event.description)
        _eventDate = State(initialValue: event.eventDate)
        _time = State(initialValue: event.time)
        _location = State(initialValue: event.location)
        _latitude = State(initialValue: event.latitude)
        _longitude = State(initialValue: event.longitude)
        _maxArtists = State(initialValue: String(event.maxArtists))
        _ticketPrice = State(initialValue: String(event.ticketPrice))
        _bannerImageUrl = State(initialValue: event.bannerImageUrl)
        _region = State(initialValue: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: event.latitude, longitude: event.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Banner Image
                    PhotosPicker(selection: $selectedBannerImage, matching: .images) {
                        ZStack {
                            if let image = bannerUIImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 200)
                                    .clipped()
                            } else if let url = URL(string: bannerImageUrl) {
                                ZStack {
                                    Color.gray.opacity(0.2)
                                    KFImage(url)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                }
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 200)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .font(.largeTitle)
                                            .foregroundColor(.gray)
                                    )
                            }
                        }
                        .cornerRadius(12)
                    }
                    .onChange(of: selectedBannerImage) { newItem in
                        if let newItem {
                            Task {
                                if let data = try? await newItem.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    bannerUIImage = uiImage
                                    uploadBannerImage(data: data)
                                }
                            }
                        }
                    }
                    
                    // Event Details
                    VStack(alignment: .leading, spacing: 16) {
                        TextField("Event Title", text: $title)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        TextField("Description", text: $description, axis: .vertical)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .lineLimit(3...6)
                        
                        DatePicker("Event Date", selection: $eventDate, in: Date()..., displayedComponents: .date)
                            .datePickerStyle(.graphical)
                        
                        TextField("Time (e.g., 14:30)", text: $time)
                            .onChange(of: time) { newValue in
                                // Filter to only allow numbers and colons
                                let filtered = newValue.filter { $0.isNumber || $0 == ":" }
                                if filtered != newValue {
                                    time = filtered
                                }
                            }
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        // Location Search
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Location")
                                .font(.headline)
                            
                            TextField("Search location", text: $searchQuery)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .focused($searchFieldFocused)
                                .onChange(of: searchQuery) { newValue in
                                    if !newValue.isEmpty {
                                        fetchPlaceSuggestions(query: newValue)
                                    } else {
                                        placeSuggestions = []
                                    }
                                }
                            
                            if !placeSuggestions.isEmpty {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(placeSuggestions) { suggestion in
                                            Button(action: {
                                                selectPlaceSuggestion(suggestion)
                                            }) {
                                                VStack(alignment: .leading) {
                                                    Text(suggestion.mainText)
                                                        .font(.subheadline)
                                                    Text(suggestion.secondaryText)
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                                .padding(.vertical, 8)
                                                .padding(.horizontal, 12)
                                            }
                                            Divider()
                                        }
                                    }
                                }
                                .frame(maxHeight: 200)
                                .background(Color(.systemBackground))
                                .cornerRadius(8)
                                .shadow(radius: 2)
                            }
                            
                            Map(coordinateRegion: $region, annotationItems: [MapPin(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))]) { pin in
                                MapMarker(coordinate: pin.coordinate, tint: .red)
                            }
                            .frame(height: 200)
                            .cornerRadius(12)
                        }
                        
                        TextField("Maximum Artists", text: $maxArtists)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                        
                        TextField("Ticket Price", text: $ticketPrice)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                    }
                    .padding(.horizontal)
                    
                    if showError {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    Button(action: updateEvent) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Save Changes")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .disabled(isLoading)
                }
                .padding(.vertical)
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func fetchPlaceSuggestions(query: String) {
        guard !query.isEmpty else { return }
        isFetchingSuggestions = true
        let apiKey = "AIzaSyC6AHrBrs9ygRQWjaOKCVKdFQLKcrUJPoo"
        let urlString = "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")&key=\(apiKey)"
        print("Requesting: \(urlString)")
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { data, response, error in
            defer { isFetchingSuggestions = false }
            if let error = error {
                print("Error: \(error)")
                return
            }
            guard let data = data else {
                print("No data received")
                return
            }
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Response: \(jsonString)")
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let predictions = json["predictions"] as? [[String: Any]] {
                let suggestions = predictions.compactMap { prediction -> PlaceSuggestion? in
                    guard let placeId = prediction["place_id"] as? String,
                          let structuredFormatting = prediction["structured_formatting"] as? [String: Any],
                          let mainText = structuredFormatting["main_text"] as? String,
                          let secondaryText = structuredFormatting["secondary_text"] as? String else {
                        return nil
                    }
                    return PlaceSuggestion(placeId: placeId, mainText: mainText, secondaryText: secondaryText)
                }
                DispatchQueue.main.async {
                    self.placeSuggestions = suggestions
                }
            }
        }.resume()
    }
    
    private func selectPlaceSuggestion(_ suggestion: PlaceSuggestion) {
        location = suggestion.mainText + ", " + suggestion.secondaryText
        searchQuery = location
        placeSuggestions = []
        searchFieldFocused = false
        // Fetch coordinates for the placeId and update the map
        let apiKey = "AIzaSyC6AHrBrs9ygRQWjaOKCVKdFQLKcrUJPoo"
        let urlString = "https://maps.googleapis.com/maps/api/place/details/json?place_id=\(suggestion.placeId)&key=\(apiKey)"
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else { return }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let result = json["result"] as? [String: Any],
               let geometry = result["geometry"] as? [String: Any],
               let loc = geometry["location"] as? [String: Any],
               let lat = loc["lat"] as? Double,
               let lng = loc["lng"] as? Double {
                DispatchQueue.main.async {
                    latitude = lat
                    longitude = lng
                    region = MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                }
            }
        }.resume()
    }
    
    private func uploadBannerImage(data: Data) {
        let storageRef = Storage.storage().reference()
        let fileName = "event_banners/\(UUID().uuidString).jpg"
        let imageRef = storageRef.child(fileName)
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        imageRef.putData(data, metadata: metadata) { metadata, error in
            if let error = error {
                print("Image upload error: \(error.localizedDescription)")
                return
            }
            
            imageRef.downloadURL { url, error in
                if let url = url {
                    bannerImageUrl = url.absoluteString
                }
            }
        }
    }
    
    private func updateEvent() {
        guard !title.isEmpty, !description.isEmpty, !time.isEmpty, !location.isEmpty,
              !maxArtists.isEmpty, !ticketPrice.isEmpty else {
            errorMessage = "Please fill in all fields"
            showError = true
            return
        }
        
        isLoading = true
        
        let ref = Database.database().reference().child("events").child(event.id)
        let eventData: [String: Any] = [
            "title": title,
            "description": description,
            "eventDate": eventDate.timeIntervalSince1970 * 1000,
            "time": time,
            "location": location,
            "latitude": latitude,
            "longitude": longitude,
            "maxArtists": Int(maxArtists) ?? 0,
            "ticketPrice": Double(ticketPrice) ?? 0.0,
            "bannerImageUrl": bannerImageUrl
        ]
        
        ref.updateChildValues(eventData) { error, _ in
            isLoading = false
            if let error = error {
                errorMessage = error.localizedDescription
                showError = true
            } else {
                onEventUpdated()
                dismiss()
            }
        }
    }
}

struct MapPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

struct PlaceSuggestion: Identifiable {
    let id = UUID()
    let placeId: String
    let mainText: String
    let secondaryText: String
}

#Preview {
    EditEventView(event: Event(id: "1", title: "Karan aujla", description: "singling concert", eventDate: Date(), time: "6:45 AM", location: "montreal", latitude: 45.5019, longitude: -73.5674, maxArtists: 5, ticketPrice: 40.0, bannerImageUrl: ""), onEventUpdated: {})
} 
