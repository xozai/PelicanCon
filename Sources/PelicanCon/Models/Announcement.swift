import Foundation
import FirebaseFirestore

struct Announcement: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var title: String
    var body: String
    var authorId: String
    var authorName: String
    var pinned: Bool
    var createdAt: Date

    var timeAgo: String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f.localizedString(for: createdAt, relativeTo: Date())
    }
}
