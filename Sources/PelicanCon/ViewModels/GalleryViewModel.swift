import Foundation
import UIKit

@MainActor
final class GalleryViewModel: ObservableObject {
    @Published var photos: [SharedPhoto]      = []
    @Published var memoryLanePhotos: [SharedPhoto] = []
    @Published var selectedPhoto: SharedPhoto?
    @Published var isUploading     = false
    @Published var uploadProgress: Double = 0
    @Published var errorMessage: String?
    @Published var showMemoryLane  = false

    private let photoService = PhotoService.shared
    private var photosTask:   Task<Void, Never>?
    private var memoryTask:   Task<Void, Never>?

    var currentUserId:    String?
    var currentUserName:  String?
    var currentUserPhoto: String?

    deinit {
        photosTask?.cancel()
        memoryTask?.cancel()
    }

    func startListening() {
        photosTask = Task {
            for await photos in photoService.photosStream(memoryLaneOnly: false) {
                self.photos = photos
            }
        }
        memoryTask = Task {
            for await photos in photoService.photosStream(memoryLaneOnly: true) {
                self.memoryLanePhotos = photos
            }
        }
    }

    var displayedPhotos: [SharedPhoto] {
        showMemoryLane ? memoryLanePhotos : photos.filter { !$0.isMemoryLane }
    }

    // MARK: - Upload

    func uploadPhoto(
        image: UIImage,
        caption: String?,
        isMemoryLane: Bool,
        thenImage: UIImage? = nil,
        taggedUserIds: [String] = []
    ) async {
        guard let uid  = currentUserId,
              let name = currentUserName else { return }
        isUploading  = true
        errorMessage = nil
        do {
            _ = try await photoService.uploadPhoto(
                uploaderId:       uid,
                uploaderName:     name,
                uploaderPhotoURL: currentUserPhoto,
                image:            image,
                caption:          caption.flatMap { $0.isEmpty ? nil : $0 },
                isMemoryLane:     isMemoryLane,
                thenImage:        thenImage,
                taggedUserIds:    taggedUserIds
            )
            await BadgeService.shared.checkAndAwardBadges(userId: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
        isUploading = false
    }

    // MARK: - Likes

    func toggleLike(photo: SharedPhoto) async {
        guard let photoId = photo.id,
              let uid     = currentUserId else { return }
        try? await photoService.toggleLike(photoId: photoId, userId: uid)
    }

    func isLiked(photo: SharedPhoto) -> Bool {
        guard let uid = currentUserId else { return false }
        return photo.isLikedBy(uid)
    }

    // MARK: - Comments

    func addComment(to photo: SharedPhoto, text: String) async {
        guard let photoId = photo.id,
              let uid     = currentUserId,
              let name    = currentUserName,
              !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        do {
            try await photoService.addComment(
                photoId:        photoId,
                authorId:       uid,
                authorName:     name,
                authorPhotoURL: currentUserPhoto,
                text:           text
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Delete

    func deletePhoto(_ photo: SharedPhoto) async {
        guard let photoId = photo.id,
              let uid     = currentUserId,
              photo.uploaderId == uid else { return }
        do {
            try await photoService.deletePhoto(photoId: photoId, uploaderId: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Save to camera roll

    func saveToPhotoLibrary(photo: SharedPhoto) async {
        guard let url = URL(string: photo.imageURL),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let image     = UIImage(data: data) else {
            errorMessage = "Could not download photo."
            return
        }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }

    // MARK: - Flagging

    func flagPhoto(_ photo: SharedPhoto) async {
        guard let photoId = photo.id,
              let uid     = currentUserId else { return }
        try? await photoService.flagPhoto(photoId: photoId, userId: uid)
    }

    func isFlagged(photo: SharedPhoto) -> Bool {
        guard let uid = currentUserId else { return false }
        return photo.isFlaggedBy(uid)
    }

    func clearError() { errorMessage = nil }
}
