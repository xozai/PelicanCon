import Foundation
import FirebaseFirestore

struct SharedPhoto: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var uploaderId: String
    var uploaderName: String
    var uploaderPhotoURL: String?
    var imageURL: String
    var thumbnailURL: String
    var caption: String?
    var likes: [String]              // [userID]
    var comments: [PhotoComment]
    var uploadedAt: Date
    var isMemoryLane: Bool           // true = throwback 1991 photo
    // Memory Lane: Then vs. Now
    var thenPhotoURL: String?        // optional "then" (1991) image URL for side-by-side
    var taggedUserIds: [String]      // classmates tagged in this photo
    // Moderation
    var flaggedBy: [String]          // userIDs who have flagged this photo

    var likeCount: Int { likes.count }
    var flagCount: Int { flaggedBy.count }

    func isLikedBy(_ userId: String) -> Bool {
        likes.contains(userId)
    }

    func isFlaggedBy(_ userId: String) -> Bool {
        flaggedBy.contains(userId)
    }

    enum CodingKeys: String, CodingKey {
        case id, uploaderId, uploaderName, uploaderPhotoURL
        case imageURL, thumbnailURL, caption, likes, comments
        case uploadedAt, isMemoryLane, thenPhotoURL, taggedUserIds, flaggedBy
    }
}

struct PhotoComment: Identifiable, Codable, Equatable {
    var id: String
    var authorId: String
    var authorName: String
    var authorPhotoURL: String?
    var text: String
    var createdAt: Date
}

extension SharedPhoto {
    static var previews: [SharedPhoto] {
        (1...6).map { i in
            SharedPhoto(
                id: "photo-\(i)",
                uploaderId: "uid\(i)",
                uploaderName: "Classmate \(i)",
                imageURL: "https://picsum.photos/seed/pelican\(i)/600/600",
                thumbnailURL: "https://picsum.photos/seed/pelican\(i)/300/300",
                caption: i == 1 ? "So great to see everyone! 🎉" : nil,
                likes: i <= 3 ? ["uid1", "uid2"] : [],
                comments: i == 1 ? [
                    PhotoComment(
                        id: "c1",
                        authorId: "uid2",
                        authorName: "Jamie Lee",
                        text: "This is amazing!!",
                        createdAt: Date()
                    )
                ] : [],
                uploadedAt: Date().addingTimeInterval(Double(-i * 3600)),
                isMemoryLane: i > 4,
                thenPhotoURL: nil,
                taggedUserIds: [],
                flaggedBy: []
            )
        }
    }
}
