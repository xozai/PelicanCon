import Foundation
import UserNotifications
import FirebaseFirestore
import FirebaseMessaging

@MainActor
final class NotificationService: ObservableObject {
    static let shared = NotificationService()

    @Published var deepLinkTarget: DeepLinkTarget?
    @Published var pendingNotifications: [AppNotification] = []

    private let db = Firestore.firestore()

    // MARK: - FCM Token

    func updateFCMToken(_ token: String) {
        guard let userId = AuthService.shared.currentUserId else { return }
        Task {
            try? await UserService.shared.updateFCMToken(token, userId: userId)
        }
    }

    // MARK: - Schedule local event reminders

    func scheduleEventReminders(for events: [ReunionEvent]) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        for event in events {
            scheduleReminder(for: event, offset: -86400, suffix: "tomorrow")  // 1 day before
            scheduleReminder(for: event, offset: -3600,  suffix: "in 1 hour") // 1 hour before
            scheduleReminder(for: event, offset: 0,      suffix: "is starting now") // on start
        }
    }

    private func scheduleReminder(for event: ReunionEvent, offset: TimeInterval, suffix: String) {
        let triggerDate = event.startTime.addingTimeInterval(offset)
        guard triggerDate > Date() else { return }

        let content        = UNMutableNotificationContent()
        content.title      = "PelicanCon: \(event.emoji) \(event.title)"
        content.body       = "\(event.title) \(suffix) at \(event.locationName)"
        content.sound      = .default
        content.categoryIdentifier = "EVENT_REMINDER"
        content.userInfo   = ["type": "event_reminder", "eventId": event.id ?? ""]

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: triggerDate
        )
        let trigger  = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let id       = "event-\(event.id ?? "")-\(Int(offset))"
        let request  = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    // MARK: - Store in-app notification

    func storeNotification(_ note: AppNotification) async {
        guard let userId = note.recipientId.isEmpty ? nil : Optional(note.recipientId) else { return }
        try? db.collection("notifications").addDocument(from: note)
    }

    // MARK: - Fetch notifications

    func fetchNotifications(userId: String) -> AsyncStream<[AppNotification]> {
        AsyncStream { continuation in
            let listener = db.collection("notifications")
                .whereField("recipientId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .addSnapshotListener { snapshot, _ in
                    let notes = snapshot?.documents
                        .compactMap { try? $0.data(as: AppNotification.self) } ?? []
                    continuation.yield(notes)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func markAllRead(userId: String) async {
        let snapshot = try? await db.collection("notifications")
            .whereField("recipientId", isEqualTo: userId)
            .whereField("isRead", isEqualTo: false)
            .getDocuments()

        let batch = db.batch()
        snapshot?.documents.forEach {
            batch.updateData(["isRead": true], forDocument: $0.reference)
        }
        try? await batch.commit()
    }

    // MARK: - Deep-link handling (from notification tap)

    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        guard let typeString = userInfo["type"] as? String else { return }

        switch typeString {
        case "message":
            if let convId = userInfo["conversationId"] as? String {
                deepLinkTarget = .conversation(convId)
            }
        case "new_photo", "photo_like", "photo_comment":
            if let photoId = userInfo["photoId"] as? String {
                deepLinkTarget = .photo(photoId)
            }
        case "event_reminder", "event_starting":
            if let eventId = userInfo["eventId"] as? String {
                deepLinkTarget = .event(eventId)
            }
        default:
            break
        }
    }
}

enum DeepLinkTarget {
    case conversation(String)
    case photo(String)
    case event(String)
}
