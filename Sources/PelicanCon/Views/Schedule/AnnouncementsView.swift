import SwiftUI

struct AnnouncementsView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var announcements: [Announcement] = []
    @State private var showPost    = false
    @State private var streamTask: Task<Void, Never>?

    private var isAdmin: Bool { authVM.currentUser?.isAdmin == true }

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            Group {
                if announcements.isEmpty {
                    emptyState
                } else {
                    List {
                        // Pinned first
                        let pinned   = announcements.filter { $0.pinned }
                        let unpinned = announcements.filter { !$0.pinned }

                        if !pinned.isEmpty {
                            Section(header: Label("Pinned", systemImage: "pin.fill")
                                .font(.caption).foregroundColor(Theme.red)) {
                                ForEach(pinned) { ann in announcementRow(ann) }
                            }
                        }
                        Section(header: Text("Recent").font(.caption).foregroundColor(Theme.midGray)) {
                            ForEach(unpinned) { ann in announcementRow(ann) }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Announcements")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isAdmin {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showPost = true
                    } label: {
                        Image(systemName: "megaphone.fill").foregroundColor(Theme.red)
                    }
                }
            }
        }
        .sheet(isPresented: $showPost) {
            PostAnnouncementView().environmentObject(authVM)
        }
        .onAppear { startStream() }
        .onDisappear { streamTask?.cancel() }
    }

    // MARK: - Row

    @ViewBuilder
    private func announcementRow(_ ann: Announcement) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(ann.title)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(Theme.darkGray)
                    Text("From \(ann.authorName) · \(ann.timeAgo)")
                        .font(.caption2).foregroundColor(Theme.midGray)
                }
                Spacer()
                if ann.pinned {
                    Image(systemName: "pin.fill").font(.caption2).foregroundColor(Theme.red)
                }
            }
            Text(ann.body)
                .font(.system(size: 14)).foregroundColor(Theme.darkGray).lineSpacing(3)

            if isAdmin {
                HStack(spacing: 16) {
                    Spacer()
                    Button(ann.pinned ? "Unpin" : "Pin") {
                        guard let id = ann.id else { return }
                        Task { try? await AnnouncementService.shared.setPinned(!ann.pinned, id: id) }
                    }
                    .font(.caption).foregroundColor(Theme.red)

                    Button("Delete") {
                        guard let id = ann.id else { return }
                        Task { try? await AnnouncementService.shared.deleteAnnouncement(id: id) }
                    }
                    .font(.caption).foregroundColor(Theme.midGray)
                }
            }
        }
        .padding(.vertical, 4)
        .listRowBackground(ann.pinned ? Theme.yellow.opacity(0.06) : Color.white)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "megaphone").font(.system(size: 48)).foregroundColor(Theme.midGray)
            Text("No announcements yet").font(.subheadline).foregroundColor(Theme.midGray)
            if isAdmin {
                Button("Post First Announcement") { showPost = true }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func startStream() {
        streamTask = Task {
            for await items in AnnouncementService.shared.announcementsStream() {
                announcements = items
            }
        }
    }
}
