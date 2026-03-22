import Foundation
import FirebaseFirestore
import FirebaseFunctions

final class AnnouncementService {
    static let shared = AnnouncementService()
    private let db        = Firestore.firestore()
    private let functions = Functions.functions()
    private var ref: CollectionReference { db.collection("announcements") }

    // MARK: - Real-time stream (all users)

    func announcementsStream() -> AsyncStream<[Announcement]> {
        AsyncStream { continuation in
            let listener = ref
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .addSnapshotListener { snapshot, _ in
                    let items = snapshot?.documents
                        .compactMap { try? $0.data(as: Announcement.self) } ?? []
                    continuation.yield(items)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    // MARK: - Admin: post announcement + push to all users

    func postAnnouncement(
        title: String,
        body: String,
        pinned: Bool,
        authorId: String,
        authorName: String
    ) async throws {
        let ann = Announcement(
            title:      title,
            body:       body,
            authorId:   authorId,
            authorName: authorName,
            pinned:     pinned,
            createdAt:  Date()
        )
        let ref = try ref.addDocument(from: ann)

        // Call Cloud Function to send FCM push to all tokens
        // The function reads all user FCM tokens from /users and sends a multicast message.
        let callable = functions.httpsCallable("broadcastAnnouncement")
        _ = try await callable.call([
            "announcementId": ref.documentID,
            "title":  title,
            "body":   body
        ])
    }

    // MARK: - Admin: delete announcement

    func deleteAnnouncement(id: String) async throws {
        try await ref.document(id).delete()
    }

    // MARK: - Admin: toggle pin

    func setPinned(_ pinned: Bool, id: String) async throws {
        try await ref.document(id).updateData(["pinned": pinned])
    }
}
