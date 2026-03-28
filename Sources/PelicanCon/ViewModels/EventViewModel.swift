import Foundation
import Combine

@MainActor
final class EventViewModel: ObservableObject {
    @Published var events: [ReunionEvent]            = []
    @Published var groupedEvents: [(day: String, date: String, events: [ReunionEvent])] = []
    @Published var isLoading       = false
    @Published var errorMessage: String?
    @Published var selectedEvent: ReunionEvent?
    @Published var calendarSuccessMessage: String?

    private let eventService = EventService.shared
    private var streamTask: Task<Void, Never>?
    private var userId: String?

    init(userId: String? = nil) {
        self.userId = userId
    }

    deinit { streamTask?.cancel() }

    func startListening() {
        streamTask = Task {
            var didScheduleReminders = false
            for await events in eventService.eventsStream() {
                self.events        = events
                self.groupedEvents = Self.group(events)
                // Schedule local reminders once per session when we first get events
                if !didScheduleReminders && !events.isEmpty {
                    didScheduleReminders = true
                    NotificationService.shared.scheduleEventReminders(for: events)
                }
            }
        }
    }

    func stopListening() { streamTask?.cancel() }

    // MARK: - RSVP

    func updateRSVP(event: ReunionEvent, status: RSVPStatus) async {
        guard let eventId = event.id,
              let uid     = userId else { return }
        do {
            try await eventService.updateRSVP(eventId: eventId, userId: uid, status: status)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func currentRSVP(for event: ReunionEvent) -> RSVPStatus? {
        guard let uid = userId else { return nil }
        return event.rsvps[uid]
    }

    func goingAttendeeIds(for event: ReunionEvent) -> [String] {
        event.rsvps.filter { $0.value == .going }.map(\.key)
    }

    // MARK: - Calendar

    func addToCalendar(_ event: ReunionEvent) async {
        do {
            try await eventService.addToCalendar(event)
            calendarSuccessMessage = "'\(event.title)' added to your Calendar!"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Group by day

    private static func group(_ events: [ReunionEvent]) -> [(day: String, date: String, events: [ReunionEvent])] {
        var dict: [String: [ReunionEvent]] = [:]
        for event in events {
            dict[event.dayKey, default: []].append(event)
        }
        return dict.keys.sorted().compactMap { key -> (day: String, date: String, events: [ReunionEvent])? in
            guard let eventsForDay = dict[key], let first = eventsForDay.first else { return nil }
            return (day: key, date: first.formattedDate, events: eventsForDay)
        }
    }

    func clearError() { errorMessage = nil }
    func clearCalendarSuccess() { calendarSuccessMessage = nil }
}
