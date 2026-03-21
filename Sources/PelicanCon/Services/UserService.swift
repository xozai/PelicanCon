import Foundation
import FirebaseFirestore
import FirebaseStorage
import UIKit

final class UserService {
    static let shared = UserService()
    private let db      = Firestore.firestore()
    private let storage = Storage.storage()

    private var usersRef: CollectionReference { db.collection("users") }

    // MARK: - Create / Update

    func createUser(_ user: AppUser) async throws {
        guard let id = user.id else { throw UserServiceError.missingId }
        try usersRef.document(id).setData(from: user)
    }

    func updateUser(_ user: AppUser) async throws {
        guard let id = user.id else { throw UserServiceError.missingId }
        try usersRef.document(id).setData(from: user, merge: true)
    }

    func updateFCMToken(_ token: String, userId: String) async throws {
        try await usersRef.document(userId).updateData(["fcmToken": token])
    }

    func updateLastSeen(userId: String) async {
        try? await usersRef.document(userId).updateData(["lastSeen": Date()])
    }

    // MARK: - Fetch

    func fetchUser(id: String) async throws -> AppUser {
        let snapshot = try await usersRef.document(id).getDocument()
        guard let user = try? snapshot.data(as: AppUser.self) else {
            throw UserServiceError.notFound
        }
        return user
    }

    func fetchAllUsers() async throws -> [AppUser] {
        let snapshot = try await usersRef
            .order(by: "displayName")
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: AppUser.self) }
    }

    func searchUsers(query: String) async throws -> [AppUser] {
        // Firestore prefix search — client-side filter after fetch
        let all = try await fetchAllUsers()
        let q   = query.lowercased()
        return all.filter {
            $0.displayName.lowercased().contains(q) ||
            ($0.maidenName?.lowercased().contains(q) ?? false) ||
            ($0.currentCity?.lowercased().contains(q) ?? false)
        }
    }

    // MARK: - Profile photo upload

    func uploadProfilePhoto(userId: String, image: UIImage) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.7) else {
            throw UserServiceError.imageConversionFailed
        }
        let ref = storage.reference().child("profile_photos/\(userId)/avatar.jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: metadata)
        let url = try await ref.downloadURL()
        try await usersRef.document(userId).updateData(["profilePhotoURL": url.absoluteString])
        return url.absoluteString
    }

    // MARK: - Real-time listener

    func userStream(id: String) -> AsyncStream<AppUser?> {
        AsyncStream { continuation in
            let listener = usersRef.document(id).addSnapshotListener { snapshot, _ in
                let user = try? snapshot?.data(as: AppUser.self)
                continuation.yield(user)
            }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func allUsersStream() -> AsyncStream<[AppUser]> {
        AsyncStream { continuation in
            let listener = usersRef
                .order(by: "displayName")
                .addSnapshotListener { snapshot, _ in
                    let users = snapshot?.documents.compactMap { try? $0.data(as: AppUser.self) } ?? []
                    continuation.yield(users)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }
}

enum UserServiceError: LocalizedError {
    case missingId, notFound, imageConversionFailed

    var errorDescription: String? {
        switch self {
        case .missingId:              return "User ID is missing."
        case .notFound:               return "User not found."
        case .imageConversionFailed:  return "Could not process image."
        }
    }
}
