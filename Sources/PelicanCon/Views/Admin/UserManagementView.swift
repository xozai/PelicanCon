import SwiftUI

struct UserManagementView: View {
    @EnvironmentObject var adminVM: AdminViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @State private var userToRemove: AppUser?
    @State private var showConfirmRemoval = false

    var body: some View {
        ZStack {
            Theme.offWhite.ignoresSafeArea()

            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundColor(Theme.midGray)
                    TextField("Search by name, email, or city…", text: $adminVM.userSearchQuery)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16).padding(.vertical, 10)

                // Count header
                HStack {
                    Text("\(adminVM.filteredUsers.count) of \(adminVM.allUsers.count) attendees")
                        .font(.caption).foregroundColor(Theme.midGray)
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.bottom, 4)

                // User list
                if adminVM.filteredUsers.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    List {
                        ForEach(adminVM.filteredUsers) { user in
                            userRow(user)
                                .listRowBackground(Color.white)
                                .listRowSeparatorTint(Theme.lightGray)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("User Management")
        .navigationBarTitleDisplayMode(.inline)
        // Success toast
        .overlay(alignment: .top) {
            if let msg = adminVM.userRemoveSuccess {
                successToast(msg)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            adminVM.userRemoveSuccess = nil
                        }
                    }
            }
        }
        .animation(.spring(response: 0.4), value: adminVM.userRemoveSuccess)
        // Error alert
        .alert("Error", isPresented: .constant(adminVM.errorMessage != nil)) {
            Button("OK") { adminVM.clearMessages() }
        } message: {
            Text(adminVM.errorMessage ?? "")
        }
        // Removal confirmation
        .confirmationDialog(
            removalTitle,
            isPresented: $showConfirmRemoval,
            titleVisibility: .visible
        ) {
            Button("Remove Permanently", role: .destructive) {
                guard let user   = userToRemove,
                      let adminId = authVM.currentUser?.id else { return }
                Task { await adminVM.removeUser(user, adminUid: adminId) }
            }
            Button("Cancel", role: .cancel) { userToRemove = nil }
        } message: {
            if let user = userToRemove {
                Text("This will permanently delete \(user.displayName)'s account, profile, and photos. It cannot be undone.")
            }
        }
    }

    // MARK: - Row

    private func userRow(_ user: AppUser) -> some View {
        HStack(spacing: 14) {
            AvatarView(user: user, size: 48)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(user.fullDisplayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.darkGray)
                    if user.isAdmin {
                        Text("ADMIN")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(Theme.red)
                            .clipShape(Capsule())
                    }
                }
                Text(user.email)
                    .font(.caption)
                    .foregroundColor(Theme.midGray)
                if let city = user.currentCity {
                    Label(city, systemImage: "location.fill")
                        .font(.caption2)
                        .foregroundColor(Theme.midGray)
                }
            }

            Spacer()

            // Disable removal of other admins from within the app
            if !user.isAdmin {
                Button {
                    userToRemove       = user
                    showConfirmRemoval = true
                } label: {
                    if adminVM.isRemovingUser && userToRemove?.id == user.id {
                        ProgressView().tint(Theme.red)
                    } else {
                        Image(systemName: "person.badge.minus")
                            .font(.title3)
                            .foregroundColor(Theme.red)
                    }
                }
                .buttonStyle(.plain)
                .disabled(adminVM.isRemovingUser)
            } else {
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundColor(Theme.midGray)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private var removalTitle: String {
        "Remove \(userToRemove?.displayName ?? "User")?"
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 48)).foregroundColor(Theme.midGray)
            Text(adminVM.userSearchQuery.isEmpty ? "No attendees yet" : "No results")
                .font(.subheadline).foregroundColor(Theme.midGray)
        }
    }

    private func successToast(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.white)
            Text(message).font(.subheadline).fontWeight(.medium).foregroundColor(.white)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(Theme.success)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8)
        .padding(.top, 12)
    }
}
