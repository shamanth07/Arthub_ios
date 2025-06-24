import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id: String
    let message: String
    let sender: String
    let timestamp: Int64
    var isRead: Bool

    init(id: String, data: [String: Any]) {
        self.id = id
        self.message = data["message"] as? String ?? ""
        self.sender = data["sender"] as? String ?? ""
        if let ts = data["timestamp"] as? Int64 {
            self.timestamp = ts
        } else if let ts = data["timestamp"] as? Double {
            self.timestamp = Int64(ts)
        } else if let ts = data["timestamp"] as? Int {
            self.timestamp = Int64(ts)
        } else {
            self.timestamp = 0
        }
        self.isRead = data["isRead"] as? Bool ?? false
    }
}
