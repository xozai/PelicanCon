import Foundation
import UIKit

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var user: AppUser?
    @Published var isUploading    = false
    @Published var isSaving       = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let userService = UserService.shared
    private var streamTask: Task<Void, Never>?

    deinit { streamTask?.cancel() }

    func startListening(userId: String) {
        streamTask = Task {
            for await updatedUser in userService.userStream(id: userId) {
                self.user = updatedUser
            }
        }
    }

    // MARK: - Update profile

    func saveProfile(
        displayName: String,
        maidenName: String?,
        bio: String?,
        currentCity: String?,
        socialLinks: [String: String],
        notificationPrefs: NotificationPreferences
    ) async {
        guard var updated = user else { return }
        updated.displayName           = displayName
        updated.maidenName            = maidenName?.isEmpty == true ? nil : maidenName
        updated.bio                   = bio?.isEmpty == true ? nil : bio
        updated.currentCity           = currentCity?.isEmpty == true ? nil : currentCity
        updated.socialLinks           = socialLinks
        updated.notificationPreferences = notificationPrefs

        isSaving = true
        do {
            try await userService.updateUser(updated)
            user           = updated
            successMessage = "Profile saved!"
        } catch {
            errorMessage = error.localizedDescription
        }
        isSaving = false
    }

    // MARK: - Photo upload

    func uploadProfilePhoto(image: UIImage) async {
        guard let uid = user?.id else { return }
        isUploading = true
        do {
            let url = try await userService.uploadProfilePhoto(userId: uid, image: image)
            user?.profilePhotoURL = url
            successMessage = "Profile photo updated!"
        } catch {
            errorMessage = error.localizedDescription
        }
        isUploading = false
    }

    // MARK: - Notification preferences

    func saveNotificationPreferences(_ prefs: NotificationPreferences) async {
        guard var updated = user else { return }
        updated.notificationPreferences = prefs
        try? await userService.updateUser(updated)
        user = updated
    }

    func clearMessages() {
        errorMessage   = nil
        successMessage = nil
    }
}
