import SwiftUI

struct ChatListView: View {
    @EnvironmentObject var chatVM: ChatViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var directoryVM: DirectoryViewModel
    @State private var showGroupChat = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.cream.ignoresSafeArea()

                List {
                    // Group chat row
                    Section {
                        Button { showGroupChat = true } label: {
                            groupChatRow
                        }
                        .listRowBackground(Color.white)
                    }

                    // DMs
                    Section("Direct Messages") {
                        if chatVM.dmConversations.isEmpty {
                            Text("No direct messages yet.\nFind classmates in the Directory!")
                                .font(.subheadline)
                                .foregroundColor(Theme.midGray)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(chatVM.dmConversations) { conversation in
                                NavigationLink {
                                    DirectMessageView(conversation: conversation)
                                        .environmentObject(chatVM)
                                        .environmentObject(directoryVM)
                                } label: {
                                    dmRow(conversation)
                                }
                                .listRowBackground(Color.white)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(isPresented: $showGroupChat) {
                GroupChatView()
                    .environmentObject(chatVM)
            }
        }
    }

    private var groupChatRow: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.redGradient)
                    .frame(width: 50, height: 50)
                ZStack {
                    Image(systemName: "bird.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                    Circle()
                        .fill(Theme.yellow)
                        .frame(width: 7, height: 7)
                        .offset(x: 8, y: 4)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Class of '91 Group Chat")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.navy)
                if let last = chatVM.groupMessages.last {
                    Text("\(last.senderName): \(last.text ?? "📷 Photo")")
                        .font(.subheadline)
                        .foregroundColor(Theme.midGray)
                        .lineLimit(1)
                } else {
                    Text("Say hello to your classmates!")
                        .font(.subheadline)
                        .foregroundColor(Theme.midGray)
                }
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(Theme.midGray)
        }
        .padding(.vertical, 6)
    }

    private func isOnline(_ conversation: Conversation) -> Bool {
        guard let uid = chatVM.currentUserId,
              let otherId = conversation.participantIds.first(where: { $0 != uid }),
              let user = directoryVM.allUsers.first(where: { $0.id == otherId }) else { return false }
        return Date().timeIntervalSince(user.lastSeen) < 300
    }

    private func otherPhotoURL(_ conversation: Conversation) -> String? {
        guard let uid = chatVM.currentUserId,
              let otherId = conversation.participantIds.first(where: { $0 != uid }) else { return nil }
        return directoryVM.allUsers.first(where: { $0.id == otherId })?.profilePhotoURL
    }

    private func dmRow(_ conversation: Conversation) -> some View {
        let otherName = otherParticipantName(conversation)
        let unread    = unreadCount(conversation)
        let online    = isOnline(conversation)

        return HStack(spacing: 14) {
            ZStack(alignment: .bottomTrailing) {
                AvatarView(photoURL: otherPhotoURL(conversation), name: otherName, size: 50)
                if online {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(otherName)
                    .font(.system(size: 16, weight: unread > 0 ? .semibold : .regular))
                    .foregroundColor(Theme.darkGray)
                if let lastMsg = conversation.lastMessage {
                    Text(lastMsg)
                        .font(.subheadline)
                        .foregroundColor(unread > 0 ? Theme.darkGray : Theme.midGray)
                        .fontWeight(unread > 0 ? .medium : .regular)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                if let date = conversation.lastMessageAt {
                    Text(timeAgo(date))
                        .font(.caption2)
                        .foregroundColor(Theme.midGray)
                }
                if unread > 0 {
                    Text("\(unread)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Theme.navy)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func otherParticipantName(_ conversation: Conversation) -> String {
        guard let uid = chatVM.currentUserId else { return conversation.displayName }
        let idx = conversation.participantIds.firstIndex(where: { $0 != uid })
        return idx.map { conversation.participantNames[$0] } ?? conversation.displayName
    }

    private func unreadCount(_ conversation: Conversation) -> Int {
        guard let uid = chatVM.currentUserId else { return 0 }
        return conversation.unreadCount(for: uid)
    }

    private func timeAgo(_ date: Date) -> String {
        let seconds = -date.timeIntervalSinceNow
        if seconds < 60      { return "now" }
        if seconds < 3600    { return "\(Int(seconds/60))m" }
        if seconds < 86400   { return "\(Int(seconds/3600))h" }
        return "\(Int(seconds/86400))d"
    }
}
