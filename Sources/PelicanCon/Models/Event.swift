import Foundation
import FirebaseFirestore
import CoreLocation

struct ReunionEvent: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var title: String
    var description: String
    var locationName: String
    var address: String
    var latitude: Double
    var longitude: Double
    var startTime: Date
    var endTime: Date
    var emoji: String
    var rsvps: [String: RSVPStatus]   // [userID: status]
    var createdBy: String

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var goingCount: Int {
        rsvps.values.filter { $0 == .going }.count
    }

    var formattedTimeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: startTime)) – \(formatter.string(from: endTime))"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: startTime)
    }

    var dayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: startTime)
    }

    enum CodingKeys: String, CodingKey {
        case id, title, description, locationName, address
        case latitude, longitude, startTime, endTime
        case emoji, rsvps, createdBy
    }
}

enum RSVPStatus: String, Codable, CaseIterable {
    case going  = "going"
    case maybe  = "maybe"
    case no     = "no"

    var label: String {
        switch self {
        case .going:  return "Going"
        case .maybe:  return "Maybe"
        case .no:     return "Can't Make It"
        }
    }

    var icon: String {
        switch self {
        case .going:  return "checkmark.circle.fill"
        case .maybe:  return "questionmark.circle.fill"
        case .no:     return "xmark.circle.fill"
        }
    }
}

extension ReunionEvent {
    static var previews: [ReunionEvent] {
        let base = Date()
        let cal  = Calendar.current

        let friday = cal.date(byAdding: .day, value: 0, to: base)!
        let saturday = cal.date(byAdding: .day, value: 1, to: base)!
        let sunday = cal.date(byAdding: .day, value: 2, to: base)!

        return [
            ReunionEvent(
                id: "1",
                title: "Welcome Reception",
                description: "Kick off the reunion weekend with cocktails and appetizers. Name tags provided at the door!",
                locationName: "Pelican Bay Resort – Beachfront Terrace",
                address: "1234 Coastal Drive, Tampa Bay, FL 33601",
                latitude: 27.9506, longitude: -82.4572,
                startTime: cal.date(bySettingHour: 18, minute: 0, second: 0, of: friday)!,
                endTime:   cal.date(bySettingHour: 21, minute: 0, second: 0, of: friday)!,
                emoji: "🍹",
                rsvps: ["uid1": .going, "uid2": .going, "uid3": .maybe],
                createdBy: "admin"
            ),
            ReunionEvent(
                id: "2",
                title: "Main Reunion Dinner & Dance",
                description: "The big night! Dinner banquet, awards, live DJ, and dancing until midnight.",
                locationName: "Grand Ballroom – Pelican Bay Resort",
                address: "1234 Coastal Drive, Tampa Bay, FL 33601",
                latitude: 27.9506, longitude: -82.4572,
                startTime: cal.date(bySettingHour: 18, minute: 30, second: 0, of: saturday)!,
                endTime:   cal.date(bySettingHour: 23, minute: 59, second: 0, of: saturday)!,
                emoji: "🎉",
                rsvps: ["uid1": .going, "uid2": .going],
                createdBy: "admin"
            ),
            ReunionEvent(
                id: "3",
                title: "Farewell Brunch",
                description: "A relaxed Sunday morning send-off. Brunch buffet, final photos, and tearful goodbyes.",
                locationName: "Pelican Bay Resort – Garden Patio",
                address: "1234 Coastal Drive, Tampa Bay, FL 33601",
                latitude: 27.9506, longitude: -82.4572,
                startTime: cal.date(bySettingHour: 10, minute: 0, second: 0, of: sunday)!,
                endTime:   cal.date(bySettingHour: 13, minute: 0, second: 0, of: sunday)!,
                emoji: "☀️",
                rsvps: [:],
                createdBy: "admin"
            )
        ]
    }
}
