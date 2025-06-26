import Foundation

struct Event: Identifiable {
    let id: String
    let title: String
    let description: String
    let eventDate: Date
    let time: String
    let location: String
    let latitude: Double
    let longitude: Double
    let maxArtists: Int
    let ticketPrice: Double
    let bannerImageUrl: String
} 
