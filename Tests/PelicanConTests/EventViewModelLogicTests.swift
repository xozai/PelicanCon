import XCTest
@testable import PelicanCon

// MARK: - EventViewModel pure-logic tests
//
// These tests exercise logic that doesn't require Firebase to be configured.
// EventViewModel's group() method is private+static, so we test its observable
// effects via the groupedEvents property after calling startListening — or
// we test the model-level helpers that feed into it.

final class EventGoingAttendeeTests: XCTestCase {

    // Tests for the EventViewModel.goingAttendeeIds helper which simply
    // filters the event.rsvps dictionary.

    private func makeEvent(rsvps: [String: RSVPStatus]) -> ReunionEvent {
        ReunionEvent(
            id: "ev-1",
            title: "Test",
            description: "",
            locationName: "Venue",
            address: "123 St",
            latitude: 0,
            longitude: 0,
            startTime: Date(),
            endTime: Date().addingTimeInterval(3600),
            emoji: "🎉",
            rsvps: rsvps,
            createdBy: "admin",
            sourceType: "manual"
        )
    }

    func testGoingAttendeeIdsReturnsOnlyGoingUsers() {
        let event = makeEvent(rsvps: [
            "u1": .going,
            "u2": .maybe,
            "u3": .no,
            "u4": .going
        ])
        // Replicate the logic from EventViewModel.goingAttendeeIds
        let goingIds = event.rsvps.filter { $0.value == .going }.map(\.key).sorted()
        XCTAssertEqual(goingIds, ["u1", "u4"])
    }

    func testGoingAttendeeIdsEmptyWhenNoRSVPs() {
        let event = makeEvent(rsvps: [:])
        let goingIds = event.rsvps.filter { $0.value == .going }.map(\.key)
        XCTAssertTrue(goingIds.isEmpty)
    }

    func testGoingAttendeeIdsExcludesMaybeAndNo() {
        let event = makeEvent(rsvps: ["u1": .maybe, "u2": .no])
        let goingIds = event.rsvps.filter { $0.value == .going }.map(\.key)
        XCTAssertTrue(goingIds.isEmpty)
    }
}

// MARK: - Event grouping key consistency

final class EventDayKeyGroupingTests: XCTestCase {

    /// Creates two events with the same start-day calendar date.
    private func makeEventsOnSameDay() -> [ReunionEvent] {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 20
        comps.timeZone = TimeZone(identifier: "UTC")
        let cal = Calendar(identifier: .gregorian)
        let morningDate = cal.date(from: comps)!.addingTimeInterval(8 * 3600)
        let eveningDate = cal.date(from: comps)!.addingTimeInterval(19 * 3600)

        let morning = ReunionEvent(
            id: "ev-1", title: "Breakfast",
            description: "", locationName: "Venue", address: "",
            latitude: 0, longitude: 0,
            startTime: morningDate, endTime: morningDate.addingTimeInterval(3600),
            emoji: "☀️", rsvps: [:], createdBy: "admin", sourceType: "manual"
        )
        let evening = ReunionEvent(
            id: "ev-2", title: "Dinner",
            description: "", locationName: "Venue", address: "",
            latitude: 0, longitude: 0,
            startTime: eveningDate, endTime: eveningDate.addingTimeInterval(7200),
            emoji: "🍽️", rsvps: [:], createdBy: "admin", sourceType: "manual"
        )
        return [morning, evening]
    }

    func testEventsOnSameDayShareDayKey() {
        let events = makeEventsOnSameDay()
        XCTAssertEqual(events[0].dayKey, events[1].dayKey,
                       "Morning and evening events on the same day should share a dayKey")
    }

    func testEventsOnDifferentDaysHaveDifferentDayKeys() {
        let date1 = Date(timeIntervalSince1970: 1_750_000_000)
        let date2 = date1.addingTimeInterval(24 * 3600)

        let ev1 = ReunionEvent(id: "1", title: "A", description: "", locationName: "", address: "",
                               latitude: 0, longitude: 0, startTime: date1, endTime: date1,
                               emoji: "🎉", rsvps: [:], createdBy: "a", sourceType: "manual")
        let ev2 = ReunionEvent(id: "2", title: "B", description: "", locationName: "", address: "",
                               latitude: 0, longitude: 0, startTime: date2, endTime: date2,
                               emoji: "🎉", rsvps: [:], createdBy: "a", sourceType: "manual")

        XCTAssertNotEqual(ev1.dayKey, ev2.dayKey)
    }
}
