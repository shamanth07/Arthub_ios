
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
                        // fallback for dictionary structure
                        confirmedVisitors = dict.values.compactMap { $0 as? String }
                    } else {
                        confirmedVisitors = []
                    }
                    let report = AdminReport(
                        id: id,
                        bannerImageUrl: bannerImageUrl,
                        title: title,
                        interestedCount: interestedCount,
                        rsvpCount: rsvpCount,
                        mostLikedArtist: mostLikedArtist,
                        confirmedVisitors: confirmedVisitors
                    )
                    loaded.append(report)
                }
            }
            DispatchQueue.main.async {
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
