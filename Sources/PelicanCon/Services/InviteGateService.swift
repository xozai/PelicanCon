import Foundation
import FirebaseFirestore

/// Manages the admin-controlled email allowlist that restricts who can register.
/// Admins write to /config/inviteGate  { allowedEmails: [String], enabled: Bool }
final class InviteGateService {
    static let shared = InviteGateService()
    private let db = Firestore.firestore()
    private var configRef: DocumentReference { db.collection("config").document("inviteGate") }

    // MARK: - Gate check (called before sign-up)

    /// Returns nil if allowed, or an error message if the email is not on the list.
    func validateEmail(_ email: String) async -> String? {
        let normalized = email.lowercased().trimmingCharacters(in: .whitespaces)
        guard let doc = try? await configRef.getDocument(), doc.exists else {
            // No gate configured — open registration
            return nil
        }
        guard let data = doc.data() else { return nil }
        let enabled = data["enabled"] as? Bool ?? false
        guard enabled else { return nil }

        let allowed = (data["allowedEmails"] as? [String] ?? [])
            .map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        if allowed.contains(normalized) { return nil }
        return "This email is not on the approved attendee list. Please contact a reunion organizer."
    }

    // MARK: - Admin management

    func fetchConfig() async -> InviteGateConfig? {
        guard let doc = try? await configRef.getDocument(), doc.exists else { return nil }
        return try? doc.data(as: InviteGateConfig.self)
    }

    func saveConfig(_ config: InviteGateConfig) async throws {
        try configRef.setData(from: config)
    }

    func addEmails(_ emails: [String]) async throws {
        let normalized = emails.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        try await configRef.setData(
            ["allowedEmails": FieldValue.arrayUnion(normalized)],
            merge: true
        )
    }

    func removeEmail(_ email: String) async throws {
        let normalized = email.lowercased().trimmingCharacters(in: .whitespaces)
        try await configRef.updateData(["allowedEmails": FieldValue.arrayRemove([normalized])])
    }
}

struct InviteGateConfig: Codable {
    @DocumentID var id: String?
    var enabled: Bool
    var allowedEmails: [String]
}
