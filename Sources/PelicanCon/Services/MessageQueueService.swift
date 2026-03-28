import Foundation
import Combine

// MARK: - Pending message model

struct PendingMessage: Codable, Identifiable {
    let id: String
    let conversationId: String
    let senderId: String
    let senderName: String
    let senderPhotoURL: String?
    let text: String
    let replyToMessageId: String?
    let replyToText: String?
    let queuedAt: Date

    init(
        conversationId: String,
        senderId: String,
        senderName: String,
        senderPhotoURL: String?,
        text: String,
        replyToMessageId: String? = nil,
        replyToText: String? = nil
    ) {
        self.id               = UUID().uuidString
        self.conversationId   = conversationId
        self.senderId         = senderId
        self.senderName       = senderName
        self.senderPhotoURL   = senderPhotoURL
        self.text             = text
        self.replyToMessageId = replyToMessageId
        self.replyToText      = replyToText
        self.queuedAt         = Date()
    }
}

// MARK: - Queue service

@MainActor
final class MessageQueueService: ObservableObject {
    static let shared = MessageQueueService()

    @Published private(set) var pendingMessages: [PendingMessage] = []
    @Published private(set) var isFlushing = false

    private let storeKey = "com.pelicancon.messageQueue"
    private var networkCancellable: AnyCancellable?
    private let messageService = MessageService.shared

    private init() {
        load()
        networkCancellable = NetworkMonitor.shared.$isConnected
            .receive(on: RunLoop.main)
            .sink { [weak self] connected in
                if connected { Task { await self?.flush() } }
            }
    }

    // MARK: - Enqueue

    func enqueue(_ message: PendingMessage) {
        pendingMessages.append(message)
        persist()
    }

    var pendingCount: Int { pendingMessages.count }

    // MARK: - Flush when online

    func flush() async {
        guard !pendingMessages.isEmpty, !isFlushing else { return }
        isFlushing = true
        var remaining: [PendingMessage] = []
        for msg in pendingMessages {
            do {
                try await messageService.sendTextMessage(
                    conversationId: msg.conversationId,
                    senderId:       msg.senderId,
                    senderName:     msg.senderName,
                    senderPhotoURL: msg.senderPhotoURL,
                    text:           msg.text,
                    replyToId:      msg.replyToMessageId,
                    replyToText:    msg.replyToText
                )
            } catch {
                remaining.append(msg)
            }
        }
        pendingMessages = remaining
        persist()
        isFlushing = false
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(pendingMessages) else { return }
        UserDefaults.standard.set(data, forKey: storeKey)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: storeKey),
              let msgs = try? JSONDecoder().decode([PendingMessage].self, from: data) else { return }
        pendingMessages = msgs
    }
}
