import Foundation
import FirebaseFirestore
import FirebaseStorage
import UIKit

final class MessageService {
    static let shared = MessageService()
    private let db      = Firestore.firestore()
    private let storage = Storage.storage()

    private var conversationsRef: CollectionReference { db.collection("conversations") }

    // MARK: - Conversations

    func fetchOrCreateDMConversation(
        currentUserId: String,
        currentUserName: String,
        otherUserId: String,
        otherUserName: String
    ) async throws -> String {
        // Check for existing DM
        let existing = try await conversationsRef
            .whereField("participantIds", arrayContains: currentUserId)
            .whereField("isGroup", isEqualTo: false)
            .getDocuments()

        for doc in existing.documents {
            if let conv = try? doc.data(as: Conversation.self),
               conv.participantIds.contains(otherUserId) {
                return doc.documentID
            }
        }

        // Create new DM conversation
        let conv = Conversation(
            participantIds:     [currentUserId, otherUserId],
            participantNames:   [currentUserName, otherUserName],
            lastMessage:        nil,
            lastMessageSenderId: nil,
            lastMessageAt:      nil,
            unreadCounts:       [currentUserId: 0, otherUserId: 0],
            isGroup:            false
        )
        let ref = try conversationsRef.addDocument(from: conv)
        return ref.documentID
    }

    func dmConversationsStream(userId: String) -> AsyncStream<[Conversation]> {
        AsyncStream { continuation in
            let listener = conversationsRef
                .whereField("participantIds", arrayContains: userId)
                .whereField("isGroup", isEqualTo: false)
                .order(by: "lastMessageAt", descending: true)
                .addSnapshotListener { snapshot, _ in
                    let convs = snapshot?.documents
                        .compactMap { try? $0.data(as: Conversation.self) } ?? []
                    continuation.yield(convs)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    // MARK: - Messages stream

    func messagesStream(conversationId: String) -> AsyncStream<[Message]> {
        AsyncStream { continuation in
            let listener = conversationsRef
                .document(conversationId)
                .collection("messages")
                .order(by: "sentAt")
                .addSnapshotListener { snapshot, _ in
                    let msgs = snapshot?.documents
                        .compactMap { try? $0.data(as: Message.self) } ?? []
                    continuation.yield(msgs)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    // MARK: - Send

    func sendTextMessage(
        conversationId: String,
        senderId: String,
        senderName: String,
        senderPhotoURL: String?,
        text: String,
        replyTo: Message? = nil
    ) async throws {
        let msg = Message(
            conversationId:    conversationId,
            senderId:          senderId,
            senderName:        senderName,
            senderPhotoURL:    senderPhotoURL,
            text:              text,
            photoURL:          nil,
            replyToMessageId:  replyTo?.id,
            replyToText:       replyTo?.text,
            reactions:         [:],
            readBy:            [senderId],
            sentAt:            Date()
        )
        let msgsRef = conversationsRef.document(conversationId).collection("messages")
        _ = try msgsRef.addDocument(from: msg)
        try await updateConversationLastMessage(conversationId: conversationId, text: text, senderId: senderId)
    }

    /// Convenience overload used by the offline queue (stores raw reply fields, not a full Message).
    func sendTextMessage(
        conversationId: String,
        senderId: String,
        senderName: String,
        senderPhotoURL: String?,
        text: String,
        replyToId: String?,
        replyToText: String?
    ) async throws {
        let msg = Message(
            conversationId:   conversationId,
            senderId:         senderId,
            senderName:       senderName,
            senderPhotoURL:   senderPhotoURL,
            text:             text,
            photoURL:         nil,
            replyToMessageId: replyToId,
            replyToText:      replyToText,
            reactions:        [:],
            readBy:           [senderId],
            sentAt:           Date()
        )
        let msgsRef = conversationsRef.document(conversationId).collection("messages")
        _ = try msgsRef.addDocument(from: msg)
        try await updateConversationLastMessage(conversationId: conversationId, text: text, senderId: senderId)
    }

    func sendPhotoMessage(
        conversationId: String,
        senderId: String,
        senderName: String,
        senderPhotoURL: String?,
        image: UIImage
    ) async throws {
        guard let data = image.jpegData(compressionQuality: 0.7) else { return }
        let path = "chat_photos/\(conversationId)/\(UUID().uuidString).jpg"
        let ref  = storage.reference().child(path)
        let meta = StorageMetadata(); meta.contentType = "image/jpeg"
        _ = try await ref.putDataAsync(data, metadata: meta)
        let url = try await ref.downloadURL()

        let msg = Message(
            conversationId:  conversationId,
            senderId:        senderId,
            senderName:      senderName,
            senderPhotoURL:  senderPhotoURL,
            text:            nil,
            photoURL:        url.absoluteString,
            replyToMessageId: nil,
            replyToText:     nil,
            reactions:       [:],
            readBy:          [senderId],
            sentAt:          Date()
        )
        let msgsRef = conversationsRef.document(conversationId).collection("messages")
        _ = try msgsRef.addDocument(from: msg)
        try await updateConversationLastMessage(conversationId: conversationId, text: "📷 Photo", senderId: senderId)
    }

    // MARK: - Reactions

    func toggleReaction(emoji: String, messageId: String, conversationId: String, userId: String) async throws {
        let ref = conversationsRef
            .document(conversationId)
            .collection("messages")
            .document(messageId)

        let snapshot = try await ref.getDocument()
        guard var reactions = snapshot.data()?["reactions"] as? [String: [String]] else { return }

        if reactions[emoji]?.contains(userId) == true {
            reactions[emoji]?.removeAll { $0 == userId }
        } else {
            reactions[emoji, default: []].append(userId)
        }

        try await ref.updateData(["reactions": reactions])
    }

    // MARK: - Read receipts

    func markConversationRead(conversationId: String, userId: String) async throws {
        try await conversationsRef.document(conversationId).updateData([
            "unreadCounts.\(userId)": 0
        ])
        // Mark last batch of messages as read
        let msgs = try await conversationsRef
            .document(conversationId)
            .collection("messages")
            .order(by: "sentAt", descending: true)
            .limit(to: 50)
            .getDocuments()

        let batch = db.batch()
        msgs.documents.forEach { doc in
            batch.updateData(["readBy": FieldValue.arrayUnion([userId])], forDocument: doc.reference)
        }
        try await batch.commit()
    }

    // MARK: - Private

    private func updateConversationLastMessage(
        conversationId: String,
        text: String,
        senderId: String
    ) async throws {
        try await conversationsRef.document(conversationId).updateData([
            "lastMessage":         text,
            "lastMessageSenderId": senderId,
            "lastMessageAt":       Date()
        ])
    }
}
