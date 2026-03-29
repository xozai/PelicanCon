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

    static let maxPhotosPerUser = 20
    static let maxDimensionPx:  CGFloat = 1920

    func uploadPhoto(
        uploaderId: String,
        uploaderName: String,
        uploaderPhotoURL: String?,
        image: UIImage,
        caption: String?,
        isMemoryLane: Bool,
        thenImage: UIImage? = nil,
        taggedUserIds: [String] = []
    ) async throws -> SharedPhoto {
        // Enforce per-user photo limit
        let existing = try await photosRef
            .whereField("uploaderId", isEqualTo: uploaderId)
            .count
            .getAggregation(source: .server)
        if Int(truncating: existing.count) >= PhotoService.maxPhotosPerUser {
            throw PhotoError.limitReached(PhotoService.maxPhotosPerUser)
        }

        let photoId = UUID().uuidString
        let meta    = StorageMetadata(); meta.contentType = "image/jpeg"

        // Downscale to max 1920px on longest side, then compress
        let scaled   = image.scaledToMaxDimension(PhotoService.maxDimensionPx) ?? image
        let fullData = scaled.jpegData(compressionQuality: 0.75) ?? Data()
        let fullRef  = storage.reference().child("photos/\(photoId)/full.jpg")
        _ = try await fullRef.putDataAsync(fullData, metadata: meta)
        let fullURL = try await fullRef.downloadURL()

        // Thumbnail: 400×400, quality 0.55
        let thumbSize  = CGSize(width: 400, height: 400)
        let thumbImage = image.resized(to: thumbSize) ?? image
        let thumbData  = thumbImage.jpegData(compressionQuality: 0.55) ?? Data()
        let thumbRef   = storage.reference().child("photos/\(photoId)/thumb.jpg")
        _ = try await thumbRef.putDataAsync(thumbData, metadata: meta)
        let thumbURL = try await thumbRef.downloadURL()

        // Optional "then" (1991) photo for Memory Lane Then vs. Now
        var thenURL: String? = nil
        if let thenImg = thenImage {
            let thenScaled = thenImg.scaledToMaxDimension(PhotoService.maxDimensionPx) ?? thenImg
            let thenData   = thenScaled.jpegData(compressionQuality: 0.75) ?? Data()
            let thenRef    = storage.reference().child("photos/\(photoId)/then.jpg")
            _ = try await thenRef.putDataAsync(thenData, metadata: meta)
            thenURL = try await thenRef.downloadURL().absoluteString
        }

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
            isMemoryLane:     isMemoryLane,
            thenPhotoURL:     thenURL,
            taggedUserIds:    taggedUserIds,
            flaggedBy:        []
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
        try await photosRef.document(photoId).delete()
        let base = storage.reference().child("photos/\(photoId)")
        try? await base.child("full.jpg").delete()
        try? await base.child("thumb.jpg").delete()
        try? await base.child("then.jpg").delete()
    }

    // MARK: - Flagging (content moderation)

    func flagPhoto(photoId: String, userId: String) async throws {
        try await photosRef.document(photoId).updateData([
            "flaggedBy": FieldValue.arrayUnion([userId])
        ])
    }

    func unflagPhoto(photoId: String, userId: String) async throws {
        try await photosRef.document(photoId).updateData([
            "flaggedBy": FieldValue.arrayRemove([userId])
        ])
    }

    func flaggedPhotosStream() -> AsyncStream<[SharedPhoto]> {
        AsyncStream { continuation in
            let listener = photosRef
                .whereField("flaggedBy", isNotEqualTo: [] as [String])
                .order(by: "flaggedBy", descending: false)
                .order(by: "uploadedAt", descending: true)
                .addSnapshotListener { snapshot, _ in
                    let photos = snapshot?.documents
                        .compactMap { try? $0.data(as: SharedPhoto.self) } ?? []
                    continuation.yield(photos)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }
}

// MARK: - Photo Errors

enum PhotoError: LocalizedError {
    case limitReached(Int)
    var errorDescription: String? {
        switch self {
        case .limitReached(let n):
            return "You've reached the \(n)-photo limit. Delete an existing photo to upload a new one."
        }
    }
}

// MARK: - UIImage helpers

private extension UIImage {
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }

    /// Scales the image down so its longest side is at most `maxPx` points.
    func scaledToMaxDimension(_ maxPx: CGFloat) -> UIImage? {
        let longest = max(size.width, size.height)
        guard longest > maxPx else { return self }
        let scale    = maxPx / longest
        let newSize  = CGSize(width: size.width * scale, height: size.height * scale)
        return resized(to: newSize)
    }
}
