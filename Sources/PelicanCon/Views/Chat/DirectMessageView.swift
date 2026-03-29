import SwiftUI
import PhotosUI

struct DirectMessageView: View {
    let conversation: Conversation
    @EnvironmentObject var chatVM: ChatViewModel
    @EnvironmentObject var directoryVM: DirectoryViewModel
    @State private var messageText        = ""
    @State private var replyingTo: Message?
    @State private var selectedPhotoItem: PhotosPickerItem?

    private var otherUserId: String? {
        guard let uid = chatVM.currentUserId else { return nil }
        return conversation.participantIds.first(where: { $0 != uid })
    }

    private var otherName: String {
        guard let uid = chatVM.currentUserId else { return conversation.displayName }
        let idx = conversation.participantIds.firstIndex(where: { $0 != uid })
        return idx.map { conversation.participantNames[$0] } ?? conversation.displayName
    }

    private var otherUser: AppUser? {
        guard let otherId = otherUserId else { return nil }
        return directoryVM.allUsers.first(where: { $0.id == otherId })
    }

    private var isOtherOnline: Bool {
        guard let lastSeen = otherUser?.lastSeen else { return false }
        return Date().timeIntervalSince(lastSeen) < 300   // online within 5 min
    }

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()

            VStack(spacing: 0) {
                // Online presence header bar
                if isOtherOnline {
                    HStack(spacing: 6) {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text("\(otherName) is active now")
                            .font(.caption).foregroundColor(Theme.midGray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.white)
                    Divider()
                }

                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(chatVM.directMessages) { message in
                                let isOwn = message.senderId == chatVM.currentUserId
                                let readCount = isOwn ? max(0, message.readBy.count - 1) : 0
                                MessageBubbleView(
                                    message:           message,
                                    isFromCurrentUser: isOwn,
                                    readByCount:       readCount
                                ) { emoji in
                                    Task { await chatVM.toggleReaction(emoji: emoji, message: message, inGroup: false) }
                                } onSwipeReply: {
                                    withAnimation(.easeInOut(duration: 0.2)) { replyingTo = message }
                                }
                                .id(message.id)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .onAppear {
                        if let id = conversation.id {
                            chatVM.startDMMessagesListener(conversationId: id)
                            chatVM.activeDMConvId = id
                        }
                        scrollToBottom(proxy)
                    }
                    .onChange(of: chatVM.directMessages.count) { _, _ in scrollToBottom(proxy) }
                }

                Divider()

                // Reply preview
                if let reply = replyingTo {
                    replyBanner(reply)
                }

                // Input
                inputBar
            }
        }
        .navigationTitle(otherName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await chatVM.markDMRead() }
        .onChange(of: selectedPhotoItem) { _, newItem in
            Task {
                if let data  = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data),
                   let uid   = chatVM.currentUserId,
                   let name  = chatVM.currentUserName,
                   let convId = conversation.id {
                    try? await MessageService.shared.sendPhotoMessage(
                        conversationId: convId,
                        senderId:       uid,
                        senderName:     name,
                        senderPhotoURL: chatVM.currentUserPhoto,
                        image:          image
                    )
                    selectedPhotoItem = nil
                }
            }
        }
    }

    // MARK: - Subviews

    private func replyBanner(_ reply: Message) -> some View {
        HStack {
            Rectangle().fill(Theme.gold).frame(width: 3)
            VStack(alignment: .leading) {
                Text("Replying to \(reply.senderName)")
                    .font(.caption).fontWeight(.semibold).foregroundColor(Theme.navy)
                Text(reply.text ?? "📷 Photo")
                    .font(.caption).foregroundColor(Theme.midGray).lineLimit(1)
            }
            Spacer()
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { replyingTo = nil }
            } label: {
                Image(systemName: "xmark.circle.fill").foregroundColor(Theme.midGray)
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Cancel reply")
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .background(Theme.lightGray)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                Image(systemName: "photo.on.rectangle")
                    .font(.title3).foregroundColor(Theme.softBlue)
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityLabel("Share a photo")

            TextField("Message \(otherName)…", text: $messageText, axis: .vertical)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Theme.lightGray)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .lineLimit(4)

            Button {
                let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                messageText = ""
                Task {
                    await chatVM.sendDMMessage(text: text, replyTo: replyingTo)
                    replyingTo = nil
                }
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.title3)
                    .foregroundColor(messageText.isEmpty ? Theme.midGray : Theme.navy)
            }
            .frame(minWidth: 44, minHeight: 44)
            .disabled(messageText.isEmpty || chatVM.isSending)
            .accessibilityLabel("Send message")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.white)
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        if let lastId = chatVM.directMessages.last?.id {
            withAnimation { proxy.scrollTo(lastId, anchor: .bottom) }
        }
    }
}
