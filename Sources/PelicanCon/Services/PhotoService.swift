import Foundation
import FirebaseFirestore
import FirebaseStorage
import UIKit

final class PhotoService {
    static let shared = PhotoService()
    private let db      = Firestore.firestore()
    private let storage = Storage.storage()

    private var photosRef: CollectionReference { db.collection("photos") }

    // MARK: - Upload

    func uploadPhoto(
        uploaderId: String,
        uploaderName: String,
        uploaderPhotoURL: String?,
        image: UIImage,
        caption: String?,
        isMemoryLane: Bool
    ) async throws -> SharedPhoto {
        let photoId = UUID().uuidString

        // Upload full-size image
        let fullData = image.jpegData(compressionQuality: 0.85) ?? Data()
        let fullRef  = storage.reference().child("photos/\(photoId)/full.jpg")
        let meta     = StorageMetadata(); meta.contentType = "image/jpeg"
        _ = try await fullRef.putDataAsync(fullData, metadata: meta)
        let fullURL = try await fullRef.downloadURL()

        // Upload thumbnail (smaller)
        let thumbSize = CGSize(width: 300, height: 300)
        let thumbImage = image.resized(to: thumbSize) ?? image
        let thumbData  = thumbImage.jpegData(compressionQuality: 0.6) ?? Data()
        let thumbRef   = storage.reference().child("photos/\(photoId)/thumb.jpg")
        _ = try await thumbRef.putDataAsync(thumbData, metadata: meta)
        let thumbURL = try await thumbRef.downloadURL()

        let photo = SharedPhoto(
            id:               photoId,
            uploaderId:       uploaderId,
            uploaderName:     uploaderName,
            uploaderPhotoURL: uploaderPhotoURL,
            imageURL:         fullURL.absoluteString,
            thumbnailURL:     thumbURL.absoluteString,
            caption:          caption,
            likes:            [],
            comments:         [],
            uploadedAt:       Date(),
            isMemoryLane:     isMemoryLane
        )

        try photosRef.document(photoId).setData(from: photo)
        return photo
    }

    // MARK: - Fetch streams

    func photosStream(memoryLaneOnly: Bool = false) -> AsyncStream<[SharedPhoto]> {
        AsyncStream { continuation in
            var query = photosRef
                .order(by: "uploadedAt", descending: true)
                .limit(to: 100) as Query

            if memoryLaneOnly {
                query = photosRef
                    .whereField("isMemoryLane", isEqualTo: true)
                    .order(by: "uploadedAt", descending: true)
            }

            let listener = query.addSnapshotListener { snapshot, _ in
                let photos = snapshot?.documents
                    .compactMap { try? $0.data(as: SharedPhoto.self) } ?? []
                continuation.yield(photos)
            }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    // MARK: - Likes

    func toggleLike(photoId: String, userId: String) async throws {
        let ref      = photosRef.document(photoId)
        let snapshot = try await ref.getDocument()
        guard var likes = snapshot.data()?["likes"] as? [String] else { return }

        if likes.contains(userId) {
            try await ref.updateData(["likes": FieldValue.arrayRemove([userId])])
        } else {
            try await ref.updateData(["likes": FieldValue.arrayUnion([userId])])
        }
    }

    // MARK: - Comments

    func addComment(
        photoId: String,
        authorId: String,
        authorName: String,
        authorPhotoURL: String?,
        text: String
    ) async throws {
        let comment = PhotoComment(
            id:             UUID().uuidString,
            authorId:       authorId,
            authorName:     authorName,
            authorPhotoURL: authorPhotoURL,
            text:           text,
            createdAt:      Date()
        )
        let data: [String: Any] = [
            "id":             comment.id,
            "authorId":       comment.authorId,
            "authorName":     comment.authorName,
            "authorPhotoURL": comment.authorPhotoURL as Any,
            "text":           comment.text,
            "createdAt":      comment.createdAt
        ]
        try await photosRef.document(photoId).updateData([
            "comments": FieldValue.arrayUnion([data])
        ])
    }

    // MARK: - Delete

    func deletePhoto(photoId: String, uploaderId: String) async throws {
        // Delete Firestore record
        try await photosRef.document(photoId).delete()
        // Delete from Storage
        let fullRef  = storage.reference().child("photos/\(photoId)/full.jpg")
        let thumbRef = storage.reference().child("photos/\(photoId)/thumb.jpg")
        try? await fullRef.delete()
        try? await thumbRef.delete()
    }
}

// MARK: - UIImage resize helper
private extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
