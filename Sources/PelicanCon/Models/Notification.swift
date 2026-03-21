import Foundation
import FirebaseFirestore

struct AppNotification: Identifiable, Codable {
    @DocumentID var id: String?
    var recipientId: String
    var type: NotificationType
    var title: String
    var body: String
    var referenceId: String?         // event/message/photo id for deep-link
    var isRead: Bool
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, recipientId, type, title, body
        case referenceId, isRead, createdAt
    }
}

enum NotificationType: String, Codable {
    case message          = "message"
    case newPhoto         = "new_photo"
    case eventReminder    = "event_reminder"
    case eventStarting    = "event_starting"
    case announcement     = "announcement"
    case photoLike        = "photo_like"
    case photoComment     = "photo_comment"
    case newAttendee      = "new_attendee"

    var systemImage: String {
        switch self {
        case .message:        return "message.fill"
        case .newPhoto:       return "photo.fill"
        case .eventReminder:  return "calendar.badge.clock"
        case .eventStarting:  return "bell.fill"
        case .announcement:   return "megaphone.fill"
        case .photoLike:      return "heart.fill"
        case .photoComment:   return "bubble.right.fill"
        case .newAttendee:    return "person.badge.plus"
        }
    }
}
