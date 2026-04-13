import XCTest
@testable import PelicanCon

final class PendingMessageTests: XCTestCase {

    // MARK: - Auto-generated ID

    func testInitAutoGeneratesUUID() {
        let msg = PendingMessage(
            conversationId: "conv-1",
            senderId: "user-1",
            senderName: "Alice",
            senderPhotoURL: nil,
            text: "Hello"
        )
        XCTAssertFalse(msg.id.isEmpty)
        // Should be a valid UUID string
        XCTAssertNotNil(UUID(uuidString: msg.id))
    }

    func testTwoMessagesHaveDifferentIds() {
        let m1 = PendingMessage(conversationId: "c", senderId: "u", senderName: "A", senderPhotoURL: nil, text: "a")
        let m2 = PendingMessage(conversationId: "c", senderId: "u", senderName: "A", senderPhotoURL: nil, text: "a")
        XCTAssertNotEqual(m1.id, m2.id)
    }

    // MARK: - Field storage

    func testFieldsStoredCorrectly() {
        let msg = PendingMessage(
            conversationId: "conv-42",
            senderId: "user-99",
            senderName: "Bob",
            senderPhotoURL: "https://example.com/bob.jpg",
            text: "Are we still on for tonight?",
            replyToMessageId: "msg-7",
            replyToText: "See you there!"
        )
        XCTAssertEqual(msg.conversationId, "conv-42")
        XCTAssertEqual(msg.senderId, "user-99")
        XCTAssertEqual(msg.senderName, "Bob")
        XCTAssertEqual(msg.senderPhotoURL, "https://example.com/bob.jpg")
        XCTAssertEqual(msg.text, "Are we still on for tonight?")
        XCTAssertEqual(msg.replyToMessageId, "msg-7")
        XCTAssertEqual(msg.replyToText, "See you there!")
    }

    func testOptionalFieldsDefaultToNil() {
        let msg = PendingMessage(
            conversationId: "conv-1",
            senderId: "user-1",
            senderName: "Alice",
            senderPhotoURL: nil,
            text: "Hi"
        )
        XCTAssertNil(msg.senderPhotoURL)
        XCTAssertNil(msg.replyToMessageId)
        XCTAssertNil(msg.replyToText)
    }

    // MARK: - queuedAt timestamp

    func testQueuedAtIsNearCurrentTime() {
        let before = Date()
        let msg = PendingMessage(conversationId: "c", senderId: "u", senderName: "A", senderPhotoURL: nil, text: "x")
        let after = Date()
        XCTAssertGreaterThanOrEqual(msg.queuedAt, before)
        XCTAssertLessThanOrEqual(msg.queuedAt, after)
    }

    // MARK: - Codable roundtrip

    func testCodableRoundtripPreservesAllFields() throws {
        let original = PendingMessage(
            conversationId: "conv-1",
            senderId: "user-1",
            senderName: "Alice",
            senderPhotoURL: "https://example.com/avatar.jpg",
            text: "Hello, world!",
            replyToMessageId: "msg-5",
            replyToText: "Original text"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(PendingMessage.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.conversationId, original.conversationId)
        XCTAssertEqual(decoded.senderId, original.senderId)
        XCTAssertEqual(decoded.senderName, original.senderName)
        XCTAssertEqual(decoded.senderPhotoURL, original.senderPhotoURL)
        XCTAssertEqual(decoded.text, original.text)
        XCTAssertEqual(decoded.replyToMessageId, original.replyToMessageId)
        XCTAssertEqual(decoded.replyToText, original.replyToText)
        XCTAssertEqual(decoded.queuedAt.timeIntervalSince1970,
                       original.queuedAt.timeIntervalSince1970,
                       accuracy: 1.0)
    }

    func testCodableRoundtripWithNilOptionals() throws {
        let original = PendingMessage(
            conversationId: "conv-2",
            senderId: "user-2",
            senderName: "Bob",
            senderPhotoURL: nil,
            text: "Plain text"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode(PendingMessage.self, from: data)

        XCTAssertNil(decoded.senderPhotoURL)
        XCTAssertNil(decoded.replyToMessageId)
        XCTAssertNil(decoded.replyToText)
    }

    // MARK: - Array roundtrip (simulates UserDefaults persistence)

    func testArrayCodableRoundtrip() throws {
        let messages = [
            PendingMessage(conversationId: "c", senderId: "u1", senderName: "Alice", senderPhotoURL: nil, text: "First"),
            PendingMessage(conversationId: "c", senderId: "u2", senderName: "Bob",   senderPhotoURL: nil, text: "Second"),
        ]

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        let data = try encoder.encode(messages)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let decoded = try decoder.decode([PendingMessage].self, from: data)

        XCTAssertEqual(decoded.count, 2)
        XCTAssertEqual(decoded[0].text, "First")
        XCTAssertEqual(decoded[1].text, "Second")
        XCTAssertNotEqual(decoded[0].id, decoded[1].id)
    }
}
