import Foundation
import UIKit

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var groupMessages: [Message]       = []
    @Published var dmConversations: [Conversation] = []
    @Published var directMessages: [Message]      = []
    @Published var isSending       = false
    @Published var errorMessage: String?

    private let messageService = MessageService.shared
    private var groupTask:  Task<Void, Never>?
    private var dmListTask: Task<Void, Never>?
    private var dmMsgsTask: Task<Void, Never>?

    var currentUserId:    String?
    var currentUserName:  String?
    var currentUserPhoto: String?
    var activeDMConvId:   String?

    init() {}

    deinit {
        groupTask?.cancel()
        dmListTask?.cancel()
        dmMsgsTask?.cancel()
    }

    // MARK: - Group chat

    func startGroupChatListener() {
        groupTask = Task {
            for await messages in messageService.messagesStream(conversationId: groupConversationId) {
                self.groupMessages = messages
            }
        }
    }

    func sendGroupMessage(text: String, replyTo: Message? = nil) async {
        guard let uid   = currentUserId,
              let name  = currentUserName,
              !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSending = true
        if !NetworkMonitor.shared.isConnected {
            let pending = PendingMessage(
                conversationId:   groupConversationId,
                senderId:         uid,
                senderName:       name,
                senderPhotoURL:   currentUserPhoto,
                text:             text,
                replyToMessageId: replyTo?.id,
                replyToText:      replyTo?.text
            )
            await MessageQueueService.shared.enqueue(pending)
            isSending = false
            return
        }
        do {
            try await messageService.sendTextMessage(
                conversationId: groupConversationId,
                senderId:       uid,
                senderName:     name,
                senderPhotoURL: currentUserPhoto,
                text:           text,
                replyTo:        replyTo
            )
            await BadgeService.shared.incrementMessageCount(userId: uid)
            await BadgeService.shared.checkAndAwardBadges(userId: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }

    func sendGroupPhoto(image: UIImage) async {
        guard let uid  = currentUserId,
              let name = currentUserName else { return }
        isSending = true
        do {
            try await messageService.sendPhotoMessage(
                conversationId: groupConversationId,
                senderId:       uid,
                senderName:     name,
                senderPhotoURL: currentUserPhoto,
                image:          image
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }

    func markGroupRead() async {
        guard let uid = currentUserId else { return }
        try? await messageService.markConversationRead(
            conversationId: groupConversationId, userId: uid
        )
    }

    // MARK: - DM conversations list

    func startDMListListener(userId: String) {
        dmListTask = Task {
            for await convs in messageService.dmConversationsStream(userId: userId) {
                self.dmConversations = convs
            }
        }
    }

    // MARK: - Single DM thread

    func openDM(with otherUser: AppUser) async {
        guard let uid  = currentUserId,
              let name = currentUserName,
              let otherId = otherUser.id else { return }
        do {
            let convId = try await messageService.fetchOrCreateDMConversation(
                currentUserId:   uid,
                currentUserName: name,
                otherUserId:     otherId,
                otherUserName:   otherUser.displayName
            )
            activeDMConvId = convId
            startDMMessagesListener(conversationId: convId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startDMMessagesListener(conversationId: String) {
        dmMsgsTask?.cancel()
        dmMsgsTask = Task {
            for await messages in messageService.messagesStream(conversationId: conversationId) {
                self.directMessages = messages
            }
        }
    }

    func sendDMMessage(text: String, replyTo: Message? = nil) async {
        guard let convId = activeDMConvId,
              let uid    = currentUserId,
              let name   = currentUserName,
              !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSending = true
        if !NetworkMonitor.shared.isConnected {
            let pending = PendingMessage(
                conversationId:   convId,
                senderId:         uid,
                senderName:       name,
                senderPhotoURL:   currentUserPhoto,
                text:             text,
                replyToMessageId: replyTo?.id,
                replyToText:      replyTo?.text
            )
            await MessageQueueService.shared.enqueue(pending)
            isSending = false
            return
        }
        do {
            try await messageService.sendTextMessage(
                conversationId: convId,
                senderId:       uid,
                senderName:     name,
                senderPhotoURL: currentUserPhoto,
                text:           text,
                replyTo:        replyTo
            )
            await BadgeService.shared.incrementMessageCount(userId: uid)
            await BadgeService.shared.checkAndAwardBadges(userId: uid)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSending = false
    }

    func markDMRead() async {
        guard let convId = activeDMConvId,
              let uid    = currentUserId else { return }
        try? await messageService.markConversationRead(conversationId: convId, userId: uid)
    }

    // MARK: - Reactions

    func toggleReaction(emoji: String, message: Message, inGroup: Bool) async {
        guard let msgId = message.id,
              let uid   = currentUserId else { return }
        let convId = inGroup ? groupConversationId : (activeDMConvId ?? "")
        try? await messageService.toggleReaction(
            emoji:          emoji,
            messageId:      msgId,
            conversationId: convId,
            userId:         uid
        )
    }

    func totalUnreadDMs() -> Int {
        guard let uid = currentUserId else { return 0 }
        return dmConversations.reduce(0) { $0 + $1.unreadCount(for: uid) }
    }

    func clearError() { errorMessage = nil }
}
