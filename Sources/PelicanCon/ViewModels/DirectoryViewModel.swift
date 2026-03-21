import Foundation
import Combine

@MainActor
final class DirectoryViewModel: ObservableObject {
    @Published var allUsers:      [AppUser] = []
    @Published var filteredUsers: [AppUser] = []
    @Published var searchQuery = "" {
        didSet { applyFilter() }
    }
    @Published var isLoading     = false
    @Published var errorMessage: String?
    @Published var selectedUser: AppUser?

    private let userService = UserService.shared
    private var streamTask: Task<Void, Never>?

    deinit { streamTask?.cancel() }

    func startListening() {
        streamTask = Task {
            for await users in userService.allUsersStream() {
                self.allUsers     = users
                self.applyFilter()
            }
        }
    }

    private func applyFilter() {
        if searchQuery.isEmpty {
            filteredUsers = allUsers
        } else {
            let q = searchQuery.lowercased()
            filteredUsers = allUsers.filter {
                $0.displayName.lowercased().contains(q) ||
                ($0.maidenName?.lowercased().contains(q) ?? false) ||
                ($0.currentCity?.lowercased().contains(q) ?? false) ||
                ($0.bio?.lowercased().contains(q) ?? false)
            }
        }
    }

    var attendingCount: Int { allUsers.count }

    func clearError() { errorMessage = nil }
}
