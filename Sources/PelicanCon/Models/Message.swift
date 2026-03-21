import Foundation
import FirebaseFirestore

struct Message: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var conversationId: String
    var senderId: String
    var senderName: String
    var senderPhotoURL: String?
    var text: String?
    var photoURL: String?
    var replyToMessageId: String?
    var replyToText: String?
    var reactions: [String: [String]]   // [emoji: [userID]]
    var readBy: [String]
    var sentAt: Date

    var isPhoto: Bool { photoURL != nil }

    var reactionSummary: [(emoji: String, count: Int)] {
        reactions
            .map { (emoji: $0.key, count: $0.value.count) }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
    }

    func isReadBy(_ userId: String) -> Bool {
        readBy.contains(userId)
    }

    enum CodingKeys: String, CodingKey {
        case id, conversationId, senderId, senderName, senderPhotoURL
        case text, photoURL, replyToMessageId, replyToText
        case reactions, readBy, sentAt
    }
}

struct Conversation: Identifiable, Codable {
    @DocumentID var id: String?
    var participantIds: [String]
    var participantNames: [String]
    var lastMessage: String?
    var lastMessageSenderId: String?
    var lastMessageAt: Date?
    var unreadCounts: [String: Int]     // [userID: count]
    var isGroup: Bool

    var displayName: String {
        if isGroup { return "Class of '91 Group Chat" }
        return participantNames.joined(separator: ", ")
    }

    func unreadCount(for userId: String) -> Int {
        unreadCounts[userId] ?? 0
    }

    enum CodingKeys: String, CodingKey {
        case id, participantIds, participantNames
        case lastMessage, lastMessageSenderId, lastMessageAt
        case unreadCounts, isGroup
    }
}

let groupConversationId = "group-class-1991"
