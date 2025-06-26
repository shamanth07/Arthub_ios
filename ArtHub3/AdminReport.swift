import SwiftUI
import FirebaseDatabase
import Kingfisher

struct AdminReport: Identifiable {
    let id: String
    let bannerImageUrl: String
    let title: String
    let interestedCount: Int
    let rsvpCount: Int
    let mostLikedArtist: String
    let confirmedVisitors: [String]
    var topArtistLikes: Int = 0
}

struct ReportsPage: View {
    @State private var reports: [AdminReport] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationView {
            ScrollView {
                if isLoading {
                    ProgressView("Loading reports...")
                        .padding()
                } else if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                } else if reports.isEmpty {
                    Text("No reports found.")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    VStack(spacing: 16) {
                        ForEach(reports) { report in
                            ReportCard(report: report)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Reports")
            .onAppear(perform: fetchReports)
        }
    }
    
    func fetchReports() {
        isLoading = true
        errorMessage = nil
        let ref = Database.database().reference().child("adminreports")
        ref.observeSingleEvent(of: .value) { snapshot in
            var loaded: [AdminReport] = []
            let group = DispatchGroup()
            for child in snapshot.children {
                if let snap = child as? DataSnapshot,
                   let dict = snap.value as? [String: Any] {
                    let id = snap.key
                    let bannerImageUrl = dict["bannerImageUrl"] as? String ?? ""
                    let title = dict["title"] as? String ?? ""
                    let interestedCount = dict["interestedCount"] as? Int ?? 0
                    let rsvpCount = dict["rsvpCount"] as? Int ?? 0
                    let mostLikedArtist = dict["mostLikedArtist"] as? String ?? ""
                    let confirmedVisitorsArray = dict["confirmedVisitors"] as? [Any] ?? []
                    let confirmedVisitors: [String]
                    if let arr = confirmedVisitorsArray as? [String] {
                        confirmedVisitors = arr
                    } else if let dict = dict["confirmedVisitors"] as? [String: Any] {
                        confirmedVisitors = dict.values.compactMap { $0 as? String }
                    } else {
                        confirmedVisitors = []
                    }
                    var report = AdminReport(
                        id: id,
                        bannerImageUrl: bannerImageUrl,
                        title: title,
                        interestedCount: interestedCount,
                        rsvpCount: rsvpCount,
                        mostLikedArtist: mostLikedArtist,
                        confirmedVisitors: confirmedVisitors,
                        topArtistLikes: 0
                    )
                    if !mostLikedArtist.isEmpty {
                        group.enter()
                        let artistsRef = Database.database().reference().child("artists")
                        artistsRef.queryOrdered(byChild: "name").queryEqual(toValue: mostLikedArtist).observeSingleEvent(of: .value) { artistSnap in
                            var artistUid: String? = nil
                            for child in artistSnap.children {
                                if let snap = child as? DataSnapshot {
                                    artistUid = snap.key
                                    break
                                }
                            }
                            if let artistUid = artistUid {
                                let artworksRef = Database.database().reference().child("artworks")
                                artworksRef.queryOrdered(byChild: "artistId").queryEqual(toValue: artistUid).observeSingleEvent(of: .value) { artSnap in
                                    var totalLikes = 0
                                    for artChild in artSnap.children {
                                        if let artDict = (artChild as? DataSnapshot)?.value as? [String: Any],
                                           let likes = artDict["likes"] as? Int {
                                            totalLikes += likes
                                        }
                                    }
                                    report.topArtistLikes = totalLikes
                                    loaded.append(report)
                                    group.leave()
                                }
                            } else {
                                loaded.append(report)
                                group.leave()
                            }
                        }
                    } else {
                        loaded.append(report)
                    }
                }
            }
            group.notify(queue: .main) {
                self.reports = loaded
                self.isLoading = false
            }
        } withCancel: { error in
            DispatchQueue.main.async {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

struct ReportCard: View {
    let report: AdminReport
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            KFImage(URL(string: report.bannerImageUrl))
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 160)
                .clipped()
                .cornerRadius(8)
            Text(report.title)
                .font(.headline)
                .padding(.top, 4)
            Text("Interested: \(report.interestedCount)")
                .font(.subheadline)
            Text("RSVP: \(report.rsvpCount)")
                .font(.subheadline)
            Text("Top Artist: \(report.mostLikedArtist)")
                .font(.subheadline)
            if !report.mostLikedArtist.isEmpty {
                Text("Total Likes (Top Artist): \(report.topArtistLikes)")
                    .font(.subheadline)
                    .foregroundColor(.purple)
            }
            Text("Visitors: \(report.confirmedVisitors.joined(separator: ", "))")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

#Preview {
    ReportsPage()
} 
