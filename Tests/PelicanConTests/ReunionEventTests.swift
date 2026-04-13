import XCTest
@testable import PelicanCon

// MARK: - ReunionEvent model tests

final class ReunionEventTests: XCTestCase {

    // MARK: - Helpers

    private static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        return cal
    }()

    /// Fixed reference date: 2026-06-19 (Friday)
    private static let referenceDate: Date = {
        var comps = DateComponents()
        comps.year = 2026; comps.month = 6; comps.day = 19
        comps.hour = 18; comps.minute = 0; comps.second = 0
        comps.timeZone = TimeZone(identifier: "America/New_York")
        return calendar.date(from: comps)!
    }()

    private func makeEvent(
        id: String = "ev-1",
        rsvps: [String: RSVPStatus] = [:],
        startTime: Date? = nil,
        endTime: Date? = nil
    ) -> ReunionEvent {
        let start = startTime ?? Self.referenceDate
        let end   = endTime   ?? Self.calendar.date(byAdding: .hour, value: 2, to: start)!
        return ReunionEvent(
            id: id,
            title: "Test Event",
            description: "A test event",
            locationName: "Pelican Bay Resort",
            address: "1234 Coastal Drive",
            latitude: 27.9506,
            longitude: -82.4572,
            startTime: start,
            endTime: end,
            emoji: "🎉",
            rsvps: rsvps,
            createdBy: "admin",
            sourceType: "manual"
        )
    }

    // MARK: - goingCount

    func testGoingCountAllGoing() {
        let event = makeEvent(rsvps: ["u1": .going, "u2": .going, "u3": .going])
        XCTAssertEqual(event.goingCount, 3)
    }

    func testGoingCountMixedStatuses() {
        let event = makeEvent(rsvps: [
            "u1": .going,
            "u2": .maybe,
            "u3": .no,
            "u4": .going
        ])
        XCTAssertEqual(event.goingCount, 2)
    }

    func testGoingCountNoneGoing() {
        let event = makeEvent(rsvps: ["u1": .maybe, "u2": .no])
        XCTAssertEqual(event.goingCount, 0)
    }

    func testGoingCountEmptyRSVPs() {
        let event = makeEvent(rsvps: [:])
        XCTAssertEqual(event.goingCount, 0)
    }

    // MARK: - dayKey

    func testDayKeyFormat() {
        let event = makeEvent()
        // dayKey should be yyyy-MM-dd
        let key = event.dayKey
        let parts = key.split(separator: "-")
        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(parts[0].count, 4) // year
        XCTAssertEqual(parts[1].count, 2) // month
        XCTAssertEqual(parts[2].count, 2) // day
    }

    func testDayKeyIsDateFormatted() {
        let event = makeEvent()
        // Value must parse back to a valid date
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let parsed = formatter.date(from: event.dayKey)
        XCTAssertNotNil(parsed)
    }

    // MARK: - formattedDate

    func testFormattedDateIsNonEmpty() {
        let event = makeEvent()
        XCTAssertFalse(event.formattedDate.isEmpty)
    }

    func testFormattedDateContainsDayName() {
        let event = makeEvent()
        let weekdays = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"]
        let hasWeekday = weekdays.contains { event.formattedDate.contains($0) }
        XCTAssertTrue(hasWeekday, "formattedDate should contain a weekday name, got: \(event.formattedDate)")
    }

    // MARK: - formattedTimeRange

    func testFormattedTimeRangeContainsDash() {
        let event = makeEvent()
        XCTAssertTrue(event.formattedTimeRange.contains("–"))
    }

    func testFormattedTimeRangeIsNonEmpty() {
        let event = makeEvent()
        XCTAssertFalse(event.formattedTimeRange.isEmpty)
    }

    // MARK: - coordinate

    func testCoordinateMatchesStoredValues() {
        let event = makeEvent()
        XCTAssertEqual(event.coordinate.latitude,  27.9506, accuracy: 0.0001)
        XCTAssertEqual(event.coordinate.longitude, -82.4572, accuracy: 0.0001)
    }
}

// MARK: - RSVPStatus tests

final class RSVPStatusTests: XCTestCase {

    func testRawValues() {
        XCTAssertEqual(RSVPStatus.going.rawValue, "going")
        XCTAssertEqual(RSVPStatus.maybe.rawValue, "maybe")
        XCTAssertEqual(RSVPStatus.no.rawValue,    "no")
    }

    func testLabels() {
        XCTAssertEqual(RSVPStatus.going.label, "Going")
        XCTAssertEqual(RSVPStatus.maybe.label, "Maybe")
        XCTAssertEqual(RSVPStatus.no.label,    "Can't Make It")
    }

    func testIcons() {
        XCTAssertEqual(RSVPStatus.going.icon, "checkmark.circle.fill")
        XCTAssertEqual(RSVPStatus.maybe.icon, "questionmark.circle.fill")
        XCTAssertEqual(RSVPStatus.no.icon,    "xmark.circle.fill")
    }

    func testAllCasesCount() {
        XCTAssertEqual(RSVPStatus.allCases.count, 3)
    }

    func testCodableRoundtrip() throws {
        for status in RSVPStatus.allCases {
            let data    = try JSONEncoder().encode(status)
            let decoded = try JSONDecoder().decode(RSVPStatus.self, from: data)
            XCTAssertEqual(decoded, status)
        }
    }
}
