import SwiftUI

struct DirectoryView: View {
    @EnvironmentObject var directoryVM: DirectoryViewModel
    @EnvironmentObject var chatVM: ChatViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @State private var selectedUser: AppUser?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.cream.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Theme.midGray)
                        TextField("Search classmates…", text: $directoryVM.searchQuery)
                            .autocorrectionDisabled()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    // Count
                    HStack {
                        Text("\(directoryVM.attendingCount) classmates registered")
                            .font(.caption)
                            .foregroundColor(Theme.midGray)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 4)

                    // List
                    if directoryVM.filteredUsers.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "person.2.slash")
                                .font(.system(size: 48))
                                .foregroundColor(Theme.midGray)
                            Text(directoryVM.searchQuery.isEmpty ? "No classmates yet" : "No results for \"\(directoryVM.searchQuery)\"")
                                .font(.subheadline)
                                .foregroundColor(Theme.midGray)
                        }
                        Spacer()
                    } else {
                        List(directoryVM.filteredUsers) { user in
                            if user.id != authVM.currentUser?.id {
                                attendeeRow(user)
                                    .onTapGesture { selectedUser = user }
                                    .listRowBackground(Color.white)
                                    .listRowSeparatorTint(Theme.lightGray)
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Directory")
            .navigationBarTitleDisplayMode(.large)
            .sheet(item: $selectedUser) { user in
                AttendeeProfileView(user: user)
                    .environmentObject(chatVM)
                    .environmentObject(authVM)
            }
        }
    }

    private func attendeeRow(_ user: AppUser) -> some View {
        HStack(spacing: 14) {
            AvatarView(user: user, size: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(user.fullDisplayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.darkGray)

                if let city = user.currentCity {
                    Label(city, systemImage: "location.fill")
                        .font(.caption)
                        .foregroundColor(Theme.midGray)
                }

                if let bio = user.bio {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(Theme.midGray)
                        .lineLimit(1)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Theme.midGray)
        }
        .padding(.vertical, 8)
    }
}
