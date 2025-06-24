import SwiftUI
import FirebaseDatabase
import FirebaseAuth
import Kingfisher

struct EventCommentsSheet: View {
    let eventId: String
    var isVisitor: Bool = false
    @State private var comments: [ArtworkComment] = []
    @State private var isLoading = true
    @State private var replyingTo: ArtworkComment? = nil
    @State private var replyText: String = ""
    @State private var newComment: String = ""
    @State private var currentUserEmail: String = Auth.auth().currentUser?.email ?? ""
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(comments) { comment in
                                EventCommentThreadView(
                                    comment: comment,
                                    onReply: { replyingTo = $0 },
                                    isAdmin: !isVisitor
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                Divider()
                if let replying = replyingTo, !isVisitor {
                    HStack {
                        Text("Replying to: ")
                        Text(replying.userId)
                            .fontWeight(.bold)
                        Spacer()
                        Button("Cancel") { replyingTo = nil; replyText = "" }
                    }
                    .padding(.horizontal)
                    HStack {
                        TextField("Write a reply...", text: $replyText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button(action: { sendReply() }) {
                            Image(systemName: "arrowshape.turn.up.left.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                } else if isVisitor {
                    HStack {
                        TextField("Add a comment", text: $newComment)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Button(action: { sendComment() }) {
                            Image(systemName: "paperplane.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Event Comments")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear(perform: fetchComments)
    }
    
    func fetchComments() {
        isLoading = true
        let commentsRef = Database.database().reference().child("eventComments").child(eventId)
        commentsRef.observeSingleEvent(of: .value) { snapshot in
            let loaded = parseEventComments(snapshot: snapshot)
            self.comments = loaded.sorted { $0.timestamp < $1.timestamp }
            self.isLoading = false
        }
    }
    
    private func parseEventComments(snapshot: DataSnapshot, parentId: String? = nil) -> [ArtworkComment] {
        var result: [ArtworkComment] = []
        for child in snapshot.children {
            if let snap = child as? DataSnapshot,
               let dict = snap.value as? [String: Any] {
                let mainText = dict["comment"] as? String ?? dict["text"] as? String ?? dict["reply"] as? String
                let timestamp = dict["timestamp"] as? Double
                let userId = dict["userEmail"] as? String ?? dict["userId"] as? String
                if let mainText = mainText, let timestamp = timestamp, let userId = userId {
                    var replies: [ArtworkComment] = []
                    let repliesSnap = snap.childSnapshot(forPath: "replies")
                    if repliesSnap.exists() {
                        replies = parseEventComments(snapshot: repliesSnap, parentId: snap.key)
                    }
                    let commentObj = ArtworkComment(
                        id: snap.key,
                        comment: mainText,
                        timestamp: timestamp,
                        userId: userId,
                        parentId: parentId,
                        replies: replies
                    )
                    result.append(commentObj)
                }
            }
        }
        return result
    }
    
    func sendComment() {
        guard !newComment.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let commentsRef = Database.database().reference().child("eventComments").child(eventId).childByAutoId()
        let userEmail = Auth.auth().currentUser?.email ?? ""
        let commentData: [String: Any] = [
            "comment": newComment,
            "timestamp": ServerValue.timestamp(),
            "userEmail": userEmail
        ]
        commentsRef.setValue(commentData) { error, _ in
            if error == nil {
                newComment = ""
                fetchComments()
            }
        }
    }
    
    func sendReply() {
        guard let parent = replyingTo, !replyText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let replyRef = Database.database().reference().child("eventComments").child(eventId).child(parent.id).child("replies").childByAutoId()
        let userEmail = Auth.auth().currentUser?.email ?? ""
        let replyData: [String: Any] = [
            "comment": replyText,
            "timestamp": ServerValue.timestamp(),
            "userEmail": userEmail
        ]
        replyRef.setValue(replyData) { error, _ in
            if error == nil {
                replyText = ""
                replyingTo = nil
                fetchComments()
            }
        }
    }
}

struct EventCommentThreadView: View {
    let comment: ArtworkComment
    var onReply: (ArtworkComment) -> Void
    var isAdmin: Bool
    var depth: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                if let urlString = comment.profileImageUrl, let url = URL(string: urlString), !urlString.isEmpty {
                    KFImage(url)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.crop.circle")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundColor(.gray)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(comment.comment)
                        .font(.body)
                    HStack(spacing: 8) {
                        Text(comment.userName ?? comment.userId)
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(Date(timeIntervalSince1970: comment.timestamp / 1000), style: .date)
                            .font(.caption2)
                            .foregroundColor(.gray)
                        if isAdmin {
                            Button(action: { onReply(comment) }) {
                                Text("Reply")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .padding(.leading, CGFloat(depth) * 24)
            ForEach(comment.replies) { reply in
                EventCommentThreadView(
                    comment: reply,
                    onReply: onReply,
                    isAdmin: isAdmin,
                    depth: depth + 1
                )
            }
        }
    }
}
