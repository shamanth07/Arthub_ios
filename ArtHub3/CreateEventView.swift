import SwiftUI
import FirebaseDatabase
import MapKit
import PhotosUI
import FirebaseStorage
import Kingfisher

struct CreateEventView: View {
    var onEventCreated: () -> Void
    @State private var title = ""
    @State private var description = ""
    @State private var eventDate = Date()
    @State private var time = ""
    @State private var location = ""
    @State private var latitude: Double = 0.0
    @State private var longitude: Double = 0.0
    @State private var maxArtists = ""
    @State private var ticketPrice = ""
    @State private var bannerImageUrl = ""
    @State private var isLoading = false
    @State private var errorMessage = ""
    @State private var showError = false
    // Map and search state
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20.0, longitude: 0.0),
        span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30)
    )
    @State private var searchQuery = ""
    @State private var searchResults: [MKMapItem] = []
    @FocusState private var searchFieldFocused: Bool
    // Image picker state
    @State private var selectedBannerImage: PhotosPickerItem? = nil
    @State private var bannerUIImage: UIImage? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Create Event")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top)
                    PhotosPicker(selection: $selectedBannerImage, matching: .images, photoLibrary: .shared()) {
                        ZStack {
                            Color.gray.opacity(0.2)
                            if let image = bannerUIImage {
                                KFImage(URL(string: bannerImageUrl))
                                    .resizable()
                                    .scaledToFill()
                                    .frame(height: 140)
                                    .clipped()
                                    .cornerRadius(8)
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 140)
                                    .overlay(Text("Banner Image").foregroundColor(.gray))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
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
                    TextField("Event Title", text: $title)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.clear)
                        .font(.headline)
                    Divider().padding(.horizontal)
                    TextField("Description", text: $description)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.clear)
                    Divider().padding(.horizontal)
                    DatePicker("", selection: $eventDate, in: Date()..., displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .padding(.horizontal)
                    TextField("Enter Time", text: $time)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    Divider().padding(.horizontal)
                    // Search bar and map
                    HStack {
                        Image(systemName: "magnifyingglass")
                        TextField("Search", text: $searchQuery, onCommit: searchLocation)
                            .focused($searchFieldFocused)
                            .submitLabel(.search)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    if !searchResults.isEmpty && searchFieldFocused {
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(Array(searchResults.enumerated()), id: \.offset) { index, item in
                                Button(action: {
                                    if let coordinate = item.placemark.location?.coordinate {
                                        region.center = coordinate
                                        latitude = coordinate.latitude
                                        longitude = coordinate.longitude
                                        location = item.placemark.title ?? ""
                                        searchResults = []
                                        searchFieldFocused = false
                                    }
                                }) {
                                    VStack(alignment: .leading) {
                                        Text(item.name ?? "Unknown")
                                            .fontWeight(.medium)
                                        if let subtitle = item.placemark.title {
                                            Text(subtitle)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal)
                                }
                                Divider()
                            }
                        }
                        .background(Color.white)
                        .cornerRadius(8)
                        .shadow(radius: 2)
                        .padding(.horizontal)
                    }
                    Map(coordinateRegion: $region, annotationItems: [MapPin(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))]) { pin in
                        MapMarker(coordinate: pin.coordinate, tint: .purple)
                    }
                    .frame(height: 180)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    HStack {
                        Text("Lat: \(latitude, specifier: "%.4f")")
                        Text("Long: \(longitude, specifier: "%.4f")")
                    }.padding(.horizontal)
                    TextField("Maximum Artists Allowed", text: $maxArtists)
                        .keyboardType(.numberPad)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    Divider().padding(.horizontal)
                    TextField("Enter the price", text: $ticketPrice)
                        .keyboardType(.decimalPad)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    Divider().padding(.horizontal)
                    if showError {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    Button(action: createEvent) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .cornerRadius(30)
                        } else {
                            Text("Create")
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .cornerRadius(30)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
        }
    }
    
    func uploadBannerImage(data: Data) {
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
    
    func searchLocation() {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchQuery
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let items = response?.mapItems {
                searchResults = items
            } else {
                searchResults = []
            }
        }
    }
    
    struct MapPin: Identifiable, Hashable, Equatable {
        let id = UUID()
        let coordinate: CLLocationCoordinate2D
        static func == (lhs: MapPin, rhs: MapPin) -> Bool {
            lhs.coordinate.latitude == rhs.coordinate.latitude && lhs.coordinate.longitude == rhs.coordinate.longitude
        }
        func hash(into hasher: inout Hasher) {
            hasher.combine(coordinate.latitude)
            hasher.combine(coordinate.longitude)
        }
    }
    
    func createEvent() {
        guard !title.isEmpty, !description.isEmpty, !time.isEmpty, !location.isEmpty, !maxArtists.isEmpty, !ticketPrice.isEmpty else {
            errorMessage = "Please fill all fields."
            showError = true
            return
        }
        isLoading = true
        let ref = Database.database().reference().child("events").childByAutoId()
        let eventId = ref.key ?? UUID().uuidString
        let eventData: [String: Any] = [
            "eventId": eventId,
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
        ref.setValue(eventData) { error, _ in
            isLoading = false
            if let error = error {
                errorMessage = error.localizedDescription
                showError = true
            } else {
                onEventCreated()
            }
        }
    }
}

#Preview {
    CreateEventView(onEventCreated: {})
} 