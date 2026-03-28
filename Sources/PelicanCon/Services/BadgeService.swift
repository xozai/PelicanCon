import Foundation
import FirebaseFirestore

// MARK: - Badge thresholds

private let messageThreshold = 10
private let photoThreshold   = 5
private let earlyBirdLimit   = 50   // first N users to join get Early Bird

final class BadgeService {
    static let shared = BadgeService()
    private let db = Firestore.firestore()
    private var usersRef: CollectionReference { db.collection("users") }
    private var photosRef: CollectionReference { db.collection("photos") }

    // MARK: - Award

    func awardBadge(_ type: BadgeType, to userId: String) async {
        try? await usersRef.document(userId).updateData([
            "earnedBadges": FieldValue.arrayUnion([type.rawValue])
        ])
    }

    /// Called after key user actions to check and award newly earned badges.
    func checkAndAwardBadges(userId: String) async {
        async let photoCount   = countPhotos(userId: userId)
        async let msgCount     = messageSentCount(userId: userId)
        async let totalUsers   = countUsers()

        let (photos, messages, users) = await (photoCount, msgCount, totalUsers)

        if photos >= photoThreshold   { await awardBadge(.shutterbug,      to: userId) }
        if messages >= messageThreshold { await awardBadge(.socialButterfly, to: userId) }
        if users <= earlyBirdLimit     { await awardBadge(.earlyBird,       to: userId) }
    }

    // MARK: - Increment counters

    /// Increment the denormalised message count on the user document.
    func incrementMessageCount(userId: String) async {
        try? await usersRef.document(userId).updateData([
            "messagesSentCount": FieldValue.increment(Int64(1))
        ])
    }

    // MARK: - Private helpers

    private func countPhotos(userId: String) async -> Int {
        guard let agg = try? await photosRef
            .whereField("uploaderId", isEqualTo: userId)
            .count.getAggregation(source: .server) else { return 0 }
        return Int(truncating: agg.count)
    }

    private func messageSentCount(userId: String) async -> Int {
        guard let doc  = try? await usersRef.document(userId).getDocument(),
              let data = doc.data(),
              let n    = data["messagesSentCount"] as? Int else { return 0 }
        return n
    }

    private func countUsers() async -> Int {
        guard let agg = try? await usersRef
            .count.getAggregation(source: .server) else { return Int.max }
        return Int(truncating: agg.count)
    }
}
