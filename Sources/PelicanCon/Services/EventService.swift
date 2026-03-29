import Foundation
import FirebaseFirestore
import EventKit

final class EventService {
    static let shared = EventService()
    private let db    = Firestore.firestore()

    private var eventsRef: CollectionReference { db.collection("events") }

    // MARK: - Fetch

    func fetchEvents() async throws -> [ReunionEvent] {
        let snapshot = try await eventsRef
            .order(by: "startTime")
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: ReunionEvent.self) }
    }

    // MARK: - Real-time stream

    func eventsStream() -> AsyncStream<[ReunionEvent]> {
        AsyncStream { continuation in
            let listener = eventsRef
                .order(by: "startTime")
                .addSnapshotListener { snapshot, _ in
                    let events = snapshot?.documents
                        .compactMap { try? $0.data(as: ReunionEvent.self) } ?? []
                    continuation.yield(events)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    // MARK: - RSVP

    func updateRSVP(eventId: String, userId: String, status: RSVPStatus) async throws {
        try await eventsRef.document(eventId).updateData([
            "rsvps.\(userId)": status.rawValue
        ])
    }

    // MARK: - Create (admin)

    func createEvent(_ event: ReunionEvent) async throws {
        _ = try eventsRef.addDocument(from: event)
    }

    func updateEvent(_ event: ReunionEvent) async throws {
        guard let id = event.id else { return }
        try eventsRef.document(id).setData(from: event, merge: true)
    }

    func deleteEvent(id: String) async throws {
        try await eventsRef.document(id).delete()
    }

    // MARK: - iOS Calendar Export

    func addToCalendar(_ event: ReunionEvent) async throws {
        let store = EKEventStore()
        let granted: Bool

        if #available(iOS 17.0, *) {
            granted = try await store.requestWriteOnlyAccessToEvents()
        } else {
            granted = try await store.requestAccess(to: .event)
        }

        guard granted else { throw EventServiceError.calendarAccessDenied }

        let calEvent      = EKEvent(eventStore: store)
        calEvent.title    = "PelicanCon: \(event.title)"
        calEvent.notes    = event.description
        calEvent.location = event.locationName
        calEvent.startDate = event.startTime
        calEvent.endDate   = event.endTime
        calEvent.calendar  = store.defaultCalendarForNewEvents
        calEvent.addAlarm(EKAlarm(relativeOffset: -3600))   // 1h before
        calEvent.addAlarm(EKAlarm(relativeOffset: -86400))  // 1d before

        try store.save(calEvent, span: .thisEvent, commit: true)
    }
}

enum EventServiceError: LocalizedError {
    case calendarAccessDenied

    var errorDescription: String? {
        "Calendar access was denied. Please allow access in Settings."
    }
}
