import Foundation
import FirebaseFirestore

struct AppUser: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var displayName: String
    var maidenName: String?
    var email: String
    var phoneNumber: String?
    var profilePhotoURL: String?
    var bio: String?
    var currentCity: String?
    var graduationYear: Int
    var socialLinks: [String: String]
    var notificationPreferences: NotificationPreferences
    var fcmToken: String?
    var isAdmin: Bool = false
    var createdAt: Date
    var lastSeen: Date

    // Convenience
    var fullDisplayName: String {
        if let maiden = maidenName, !maiden.isEmpty {
            return "\(displayName) (\(maiden))"
        }
        return displayName
    }

    var initials: String {
        let parts = displayName.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last  = parts.dropFirst().last?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }

    enum CodingKeys: String, CodingKey {
        case id, displayName, maidenName, email, phoneNumber
        case profilePhotoURL, bio, currentCity, graduationYear
        case socialLinks, notificationPreferences, fcmToken
        case isAdmin, createdAt, lastSeen
    }
}

// MARK: - Banned User record (written by admins on removal)
struct BannedUser: Codable {
    @DocumentID var id: String?
    var uid: String
    var email: String
    var displayName: String
    var removedAt: Date
    var removedBy: String       // admin uid
    var reason: String?
}

struct NotificationPreferences: Codable, Equatable {
    var eventReminders: Bool = true
    var messages: Bool       = true
    var newPhotos: Bool      = true
    var announcements: Bool  = true
    var quietHoursEnabled: Bool = false
    var quietHoursStart: Int = 22   // 24h hour
    var quietHoursEnd: Int   = 8
}

extension AppUser {
    static var preview: AppUser {
        AppUser(
            id: "preview-uid",
            displayName: "Alex Johnson",
            maidenName: "Smith",
            email: "alex@example.com",
            profilePhotoURL: nil,
            bio: "Living in Nashville, TN. Can't believe it's been 35 years!",
            currentCity: "Nashville, TN",
            graduationYear: 1991,
            socialLinks: ["linkedin": "linkedin.com/in/alexj"],
            notificationPreferences: NotificationPreferences(),
            isAdmin: false,
            createdAt: Date(),
            lastSeen: Date()
        )
    }
}
