import Foundation
import FirebaseFirestore

@MainActor
final class AdminViewModel: ObservableObject {

    // MARK: - User Management state
    @Published var allUsers: [AppUser]         = []
    @Published var filteredUsers: [AppUser]    = []
    @Published var userSearchQuery = "" {
        didSet { filterUsers() }
    }
    @Published var isRemovingUser              = false
    @Published var userRemoveSuccess: String?

    // MARK: - Moderation state
    @Published var flaggedPhotos: [SharedPhoto]   = []
    @Published var isLoadingFlagged               = false
    private var flaggedTask: Task<Void, Never>?

    // MARK: - iCal sync state
    @Published var icalURLInput                = ""
    @Published var icalConfig: ICalSyncConfig?
    @Published var previewEvents: [ReunionEvent] = []
    @Published var showPreview                 = false
    @Published var isFetching                  = false
    @Published var isSyncing                   = false
    @Published var syncSuccess: String?

    // MARK: - Shared
    @Published var errorMessage: String?
    @Published var isLoading                   = false

    private let adminService   = AdminService.shared
    private let userService    = UserService.shared
    private var usersStreamTask: Task<Void, Never>?

    deinit {
        usersStreamTask?.cancel()
        flaggedTask?.cancel()
    }

    // MARK: - Setup

    func load(currentUserId: String) {
        Task { await loadICalConfig() }
        startUsersStream(excludingId: currentUserId)
    }

    // MARK: - User stream

    private func startUsersStream(excludingId: String) {
        usersStreamTask = Task {
            for await users in userService.allUsersStream() {
                self.allUsers     = users.filter { $0.id != excludingId }
                self.filterUsers()
            }
        }
    }

    private func filterUsers() {
        if userSearchQuery.isEmpty {
            filteredUsers = allUsers
        } else {
            let q = userSearchQuery.lowercased()
            filteredUsers = allUsers.filter {
                $0.displayName.lowercased().contains(q) ||
                $0.email.lowercased().contains(q) ||
                ($0.currentCity?.lowercased().contains(q) ?? false)
            }
        }
    }

    // MARK: - Remove user

    func removeUser(_ user: AppUser, adminUid: String) async {
        isRemovingUser = true
        errorMessage   = nil
        do {
            try await adminService.removeUser(user, removedBy: adminUid)
            userRemoveSuccess = "\(user.displayName) has been removed."
        } catch {
            errorMessage = error.localizedDescription
        }
        isRemovingUser = false
    }

    // MARK: - iCal: fetch preview

    func fetchICalPreview() async {
        let urlString = icalURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !urlString.isEmpty else {
            errorMessage = "Please enter a calendar URL."
            return
        }
        isFetching    = true
        errorMessage  = nil
        previewEvents = []
        showPreview   = false
        do {
            let events    = try await adminService.fetchAndParseIcal(urlString: urlString)
            previewEvents = events
            showPreview   = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isFetching = false
    }

    // MARK: - iCal: confirm sync

    func confirmSync(adminUid: String) async {
        let urlString = icalURLInput.trimmingCharacters(in: .whitespacesAndNewlines)
        isSyncing    = true
        errorMessage = nil
        do {
            try await adminService.syncICalEvents(previewEvents, from: urlString, adminUid: adminUid)
            syncSuccess   = "✓ \(previewEvents.count) event\(previewEvents.count == 1 ? "" : "s") imported from calendar."
            showPreview   = false
            previewEvents = []
            await loadICalConfig()
        } catch {
            errorMessage = error.localizedDescription
        }
        isSyncing = false
    }

    // MARK: - iCal: clear

    func clearICalSource() async {
        isSyncing    = true
        errorMessage = nil
        do {
            try await adminService.clearICalConfig()
            icalConfig   = nil
            icalURLInput = ""
            syncSuccess  = "Calendar source cleared. You can now manage events manually."
        } catch {
            errorMessage = error.localizedDescription
        }
        isSyncing = false
    }

    // MARK: - iCal: load saved config

    private func loadICalConfig() async {
        icalConfig = await adminService.fetchICalConfig()
        if let saved = icalConfig?.url {
            icalURLInput = saved
        }
    }

    // MARK: - Moderation

    func startFlaggedStream(adminUid: String) {
        guard flaggedTask == nil else { return }
        isLoadingFlagged = true
        flaggedTask = Task {
            for await photos in PhotoService.shared.flaggedPhotosStream() {
                self.flaggedPhotos   = photos
                self.isLoadingFlagged = false
            }
        }
    }

    /// Remove flag reports but keep the photo
    func dismissFlag(_ photo: SharedPhoto) async {
        guard let photoId = photo.id else { return }
        do {
            // Clear all flags by overwriting the array to empty
            try await Firestore.firestore()
                .collection("photos")
                .document(photoId)
                .updateData(["flaggedBy": []])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Delete the photo and its Storage files
    func deleteAndDismissPhoto(_ photo: SharedPhoto, adminUid: String) async {
        guard let photoId = photo.id else { return }
        do {
            try await PhotoService.shared.deletePhoto(photoId: photoId, uploaderId: photo.uploaderId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearMessages() {
        errorMessage      = nil
        userRemoveSuccess = nil
        syncSuccess       = nil
    }
}
