import XCTest
@testable import PelicanCon

// MARK: - Message model tests

final class MessageModelTests: XCTestCase {

    // MARK: - Helpers

    private func makeMessage(
        id: String? = "msg-1",
        text: String? = "Hello",
        photoURL: String? = nil,
        reactions: [String: [String]] = [:],
        readBy: [String] = []
    ) -> Message {
        Message(
            id: id,
            conversationId: "conv-1",
            senderId: "user-1",
            senderName: "Alice",
            senderPhotoURL: nil,
            text: text,
            photoURL: photoURL,
            replyToMessageId: nil,
            replyToText: nil,
            reactions: reactions,
            readBy: readBy,
            sentAt: Date()
        )
    }

    // MARK: - reactionSummary

    func testReactionSummarySortedByCountDescending() {
        let msg = makeMessage(reactions: [
            "👍": ["u1", "u2", "u3"],
            "❤️": ["u1"],
            "😂": ["u1", "u2"]
        ])
        let summary = msg.reactionSummary
        XCTAssertEqual(summary.count, 3)
        XCTAssertEqual(summary[0].count, 3)
        XCTAssertEqual(summary[0].emoji, "👍")
        XCTAssertEqual(summary[1].count, 2)
        XCTAssertEqual(summary[1].emoji, "😂")
        XCTAssertEqual(summary[2].count, 1)
        XCTAssertEqual(summary[2].emoji, "❤️")
    }

    func testReactionSummaryEmptyWhenNoReactions() {
        let msg = makeMessage(reactions: [:])
        XCTAssertTrue(msg.reactionSummary.isEmpty)
    }

    func testReactionSummarySingleEmoji() {
        let msg = makeMessage(reactions: ["🎉": ["u1"]])
        let summary = msg.reactionSummary
        XCTAssertEqual(summary.count, 1)
        XCTAssertEqual(summary[0].emoji, "🎉")
        XCTAssertEqual(summary[0].count, 1)
    }

    func testReactionSummaryCountMatchesUserArrayLength() {
        let msg = makeMessage(reactions: ["👍": ["u1", "u2", "u3", "u4", "u5"]])
        XCTAssertEqual(msg.reactionSummary.first?.count, 5)
    }

    // MARK: - isReadBy

    func testIsReadByReturnsTrueWhenPresent() {
        let msg = makeMessage(readBy: ["user-1", "user-2"])
        XCTAssertTrue(msg.isReadBy("user-1"))
        XCTAssertTrue(msg.isReadBy("user-2"))
    }

    func testIsReadByReturnsFalseWhenAbsent() {
        let msg = makeMessage(readBy: ["user-1"])
        XCTAssertFalse(msg.isReadBy("user-99"))
    }

    func testIsReadByReturnsFalseForEmptyList() {
        let msg = makeMessage(readBy: [])
        XCTAssertFalse(msg.isReadBy("user-1"))
    }

    func testIsReadByCaseSensitive() {
        let msg = makeMessage(readBy: ["User-1"])
        XCTAssertFalse(msg.isReadBy("user-1"))
    }

    // MARK: - isPhoto

    func testIsPhotoFalseForTextMessage() {
        let msg = makeMessage(text: "Hello", photoURL: nil)
        XCTAssertFalse(msg.isPhoto)
    }

    func testIsPhotoTrueWhenPhotoURLSet() {
        let msg = makeMessage(text: nil, photoURL: "https://example.com/photo.jpg")
        XCTAssertTrue(msg.isPhoto)
    }

    func testIsPhotoTrueEvenIfTextAlsoSet() {
        let msg = makeMessage(text: "Caption", photoURL: "https://example.com/photo.jpg")
        XCTAssertTrue(msg.isPhoto)
    }
}

// MARK: - Conversation model tests

final class ConversationModelTests: XCTestCase {

    private func makeConversation(
        id: String? = "conv-1",
        participantNames: [String] = ["Alice", "Bob"],
        isGroup: Bool = false,
        unreadCounts: [String: Int] = [:]
    ) -> Conversation {
        Conversation(
            id: id,
            participantIds: ["user-1", "user-2"],
            participantNames: participantNames,
            lastMessage: "Hey there",
            lastMessageSenderId: "user-1",
            lastMessageAt: Date(),
            unreadCounts: unreadCounts,
            isGroup: isGroup
        )
    }

    // MARK: - displayName

    func testDisplayNameGroupChat() {
        let conv = makeConversation(isGroup: true)
        XCTAssertEqual(conv.displayName, "Class of '91 Group Chat")
    }

    func testDisplayNameDMTwoParticipants() {
        let conv = makeConversation(participantNames: ["Alice", "Bob"], isGroup: false)
        XCTAssertEqual(conv.displayName, "Alice, Bob")
    }

    func testDisplayNameDMSingleParticipant() {
        let conv = makeConversation(participantNames: ["Alice"], isGroup: false)
        XCTAssertEqual(conv.displayName, "Alice")
    }

    func testDisplayNameGroupIgnoresParticipantNames() {
        let conv = makeConversation(participantNames: ["Alice", "Bob", "Carol"], isGroup: true)
        XCTAssertEqual(conv.displayName, "Class of '91 Group Chat")
    }

    // MARK: - unreadCount

    func testUnreadCountForPresentUser() {
        let conv = makeConversation(unreadCounts: ["user-1": 5, "user-2": 0])
        XCTAssertEqual(conv.unreadCount(for: "user-1"), 5)
        XCTAssertEqual(conv.unreadCount(for: "user-2"), 0)
    }

    func testUnreadCountReturnsZeroForMissingUser() {
        let conv = makeConversation(unreadCounts: [:])
        XCTAssertEqual(conv.unreadCount(for: "nobody"), 0)
    }

    func testUnreadCountHighValue() {
        let conv = makeConversation(unreadCounts: ["user-1": 99])
        XCTAssertEqual(conv.unreadCount(for: "user-1"), 99)
    }
}
