import Foundation
import FirebaseFirestore
import FirebaseStorage
import FirebaseFunctions

// MARK: - iCal Sync Config model

struct ICalSyncConfig: Codable {
    var url: String
    var lastSyncAt: Date?
    var lastSyncBy: String?
    var eventCount: Int

    static let firestoreId = "iCalSync"
}

// MARK: - AdminService

final class AdminService {
    static let shared = AdminService()

    private let db       = Firestore.firestore()
    private let storage  = Storage.storage()
    private let functions = Functions.functions()

    private var usersRef:    CollectionReference { db.collection("users") }
    private var bannedRef:   CollectionReference { db.collection("bannedUsers") }
    private var photosRef:   CollectionReference { db.collection("photos") }
    private var eventsRef:   CollectionReference { db.collection("events") }
    private var configRef:   DocumentReference   { db.collection("config").document(ICalSyncConfig.firestoreId) }

    // MARK: - User Removal

    /// Full removal pipeline: ban record → Firestore profile → Storage photos → Firebase Auth
    func removeUser(_ user: AppUser, removedBy adminUid: String) async throws {
        guard let uid = user.id else { throw AdminError.missingUserId }

        // 1. Write ban record first (so app blocks them even if later steps partially fail)
        let ban = BannedUser(
            uid:         uid,
            email:       user.email,
            displayName: user.displayName,
            removedAt:   Date(),
            removedBy:   adminUid,
            reason:      nil
        )
        try bannedRef.document(uid).setData(from: ban)

        // 2. Delete user's uploaded photos from Storage + Firestore
        try await deleteUserPhotos(uid: uid)

        // 3. Remove user from DM conversation participant lists
        await removeFromConversations(uid: uid)

        // 4. Delete Firestore user document
        try await usersRef.document(uid).delete()

        // 5. Call Cloud Function to revoke auth tokens and delete the Auth account
        //    The function verifies the caller is an admin server-side.
        let callable = functions.httpsCallable("removeAuthUser")
        _ = try await callable.call(["targetUid": uid])
    }

    /// Delete all photos uploaded by `uid` from both Storage and Firestore
    private func deleteUserPhotos(uid: String) async throws {
        let snapshot = try await photosRef
            .whereField("uploaderId", isEqualTo: uid)
            .getDocuments()

        let batch = db.batch()
        for doc in snapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()

        // Delete from Storage (best-effort; don't fail the whole pipeline if a file is missing)
        for doc in snapshot.documents {
            let photoId = doc.documentID
            try? await storage.reference().child("photos/\(photoId)/full.jpg").delete()
            try? await storage.reference().child("photos/\(photoId)/thumb.jpg").delete()
        }
    }

    /// Remove the user from any DM conversation they participate in
    private func removeFromConversations(uid: String) async {
        guard let snapshot = try? await db.collection("conversations")
            .whereField("participantIds", arrayContains: uid)
            .getDocuments() else { return }

        let batch = db.batch()
        for doc in snapshot.documents {
            batch.updateData([
                "participantIds": FieldValue.arrayRemove([uid])
            ], forDocument: doc.reference)
        }
        try? await batch.commit()
    }

    // MARK: - Ban Check (called at sign-in)

    func isUserBanned(uid: String) async -> Bool {
        let doc = try? await bannedRef.document(uid).getDocument()
        return doc?.exists == true
    }

    func isEmailBanned(_ email: String) async -> Bool {
        let snap = try? await bannedRef
            .whereField("email", isEqualTo: email)
            .limit(to: 1)
            .getDocuments()
        return snap?.isEmpty == false
    }

    // MARK: - iCal Fetch & Parse

    /// Fetch an ICS URL and parse it into `ReunionEvent` objects (no Firestore write yet).
    func fetchAndParseIcal(urlString: String) async throws -> [ReunionEvent] {
        guard let url = URL(string: urlString) else { throw AdminError.invalidURL }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AdminError.fetchFailed
        }
        guard let icsText = String(data: data, encoding: .utf8) ??
                            String(data: data, encoding: .isoLatin1) else {
            throw AdminError.parseError("Could not decode ICS data as text.")
        }

        let events = try ICSParser.parse(icsText)
        guard !events.isEmpty else { throw AdminError.noEventsFound }
        return events
    }

    // MARK: - iCal Sync (write to Firestore)

    /// Upsert all iCal-sourced events into Firestore and update the sync config.
    func syncICalEvents(_ events: [ReunionEvent], from urlString: String, adminUid: String) async throws {
        let batch = db.batch()

        // Upsert each event using its iCal-derived id as the document id
        for event in events {
            guard let id = event.id else { continue }
            let ref = eventsRef.document(id)
            if let encoded = try? Firestore.Encoder().encode(event) {
                batch.setData(encoded, forDocument: ref, merge: true)
            }
        }
        try await batch.commit()

        // Remove iCal-sourced events that are no longer in the feed
        try await pruneRemovedICalEvents(currentIds: events.compactMap(\.id))

        // Update sync config
        let config = ICalSyncConfig(
            url:         urlString,
            lastSyncAt:  Date(),
            lastSyncBy:  adminUid,
            eventCount:  events.count
        )
        try configRef.setData(from: config)
    }

    /// Delete any Firestore events prefixed `ical-` that are no longer in the feed.
    private func pruneRemovedICalEvents(currentIds: [String]) async throws {
        let snapshot = try await eventsRef
            .whereField("sourceType", isEqualTo: "ical")
            .getDocuments()

        let batch = db.batch()
        for doc in snapshot.documents where !currentIds.contains(doc.documentID) {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()
    }

    // MARK: - iCal Config read

    func fetchICalConfig() async -> ICalSyncConfig? {
        try? await configRef.getDocument(as: ICalSyncConfig.self)
    }

    func clearICalConfig() async throws {
        try await configRef.delete()
        // Delete all iCal-sourced events
        let snapshot = try await eventsRef
            .whereField("sourceType", isEqualTo: "ical")
            .getDocuments()
        let batch = db.batch()
        snapshot.documents.forEach { batch.deleteDocument($0.reference) }
        try await batch.commit()
    }
}

// MARK: - ICS Parser

enum ICSParser {

    /// Parse a full ICS text string into `ReunionEvent` objects.
    static func parse(_ icsText: String) throws -> [ReunionEvent] {
        // Unfold long lines (RFC 5545 §3.1: line ending CRLF + single space = continuation)
        let unfolded = icsText
            .replacingOccurrences(of: "\r\n ", with: "")
            .replacingOccurrences(of: "\r\n\t", with: "")
            .replacingOccurrences(of: "\n ", with: "")
            .replacingOccurrences(of: "\n\t", with: "")

        let lines = unfolded.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var events:      [ReunionEvent] = []
        var inEvent      = false
        var currentProps: [String: String] = [:]

        for line in lines {
            switch line {
            case "BEGIN:VEVENT":
                inEvent      = true
                currentProps = [:]
            case "END:VEVENT":
                if inEvent, let event = buildEvent(from: currentProps) {
                    events.append(event)
                }
                inEvent      = false
                currentProps = [:]
            default:
                if inEvent {
                    let (key, value) = splitICSLine(line)
                    currentProps[key] = value
                }
            }
        }
        return events
    }

    // MARK: - Private helpers

    /// Split `KEY;PARAM=VAL:content` into `(KEY, content)`.
    private static func splitICSLine(_ line: String) -> (String, String) {
        guard let colonIndex = line.firstIndex(of: ":") else { return (line, "") }
        let rawKey = String(line[line.startIndex..<colonIndex])
        let value  = String(line[line.index(after: colonIndex)...])
        // Strip parameter qualifiers: `DTSTART;TZID=America/New_York` → `DTSTART`
        let key    = rawKey.components(separatedBy: ";").first ?? rawKey
        return (key.uppercased(), value)
    }

    /// Build a `ReunionEvent` from a flat [property: value] dictionary.
    private static func buildEvent(from props: [String: String]) -> ReunionEvent? {
        guard
            let summary   = props["SUMMARY"], !summary.isEmpty,
            let dtStartStr = props["DTSTART"]
        else { return nil }

        let dtEndStr = props["DTEND"] ?? props["DTSTART"] ?? ""
        let uid      = props["UID"] ?? UUID().uuidString

        // Use a stable, prefixed Firestore ID derived from the iCal UID
        let docId    = "ical-\(uid.components(separatedBy: "@").first ?? uid)"
            .replacingOccurrences(of: "[^a-zA-Z0-9\\-_]", with: "-", options: .regularExpression)
            .prefix(100)
            .description

        let start    = parseICSDate(dtStartStr) ?? Date()
        let end      = parseICSDate(dtEndStr)   ?? start.addingTimeInterval(3600)
        let location = props["LOCATION"] ?? ""
        let desc     = stripHTML(props["DESCRIPTION"] ?? "")

        // Derive a map coordinate from the location string if it contains coords
        // (e.g. some iCal sources embed `GEO:lat;lon` — use that if present)
        var lat = 0.0, lon = 0.0
        if let geo = props["GEO"] {
            let parts = geo.components(separatedBy: ";")
            lat = Double(parts.first ?? "") ?? 0
            lon = Double(parts.last ?? "")  ?? 0
        }

        return ReunionEvent(
            id:           docId,
            title:        summary,
            description:  desc,
            locationName: location,
            address:      location,
            latitude:     lat,
            longitude:    lon,
            startTime:    start,
            endTime:      end,
            emoji:        emojiForEvent(summary),
            rsvps:        [:],
            createdBy:    "ical",
            sourceType:   "ical"
        )
    }

    /// Parse ICS date strings: `20260919T180000Z`, `20260919T140000`, `20260919`
    static func parseICSDate(_ str: String) -> Date? {
        let formatters: [(String, String)] = [
            ("yyyyMMdd'T'HHmmss'Z'", "UTC"),
            ("yyyyMMdd'T'HHmmss",    TimeZone.current.identifier),
            ("yyyyMMdd",             TimeZone.current.identifier),
        ]
        for (format, tzId) in formatters {
            let f = DateFormatter()
            f.dateFormat = format
            f.timeZone   = TimeZone(identifier: tzId)
            if let date = f.date(from: str) { return date }
        }
        return nil
    }

    /// Strip basic HTML tags from description text.
    private static func stripHTML(_ html: String) -> String {
        guard html.contains("<") else { return html }
        return html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Pick a contextual emoji based on keywords in the event title.
    private static func emojiForEvent(_ title: String) -> String {
        let t = title.lowercased()
        if t.contains("reception") || t.contains("cocktail") || t.contains("happy hour") { return "🍹" }
        if t.contains("dinner")    || t.contains("banquet")  || t.contains("gala")       { return "🍽️" }
        if t.contains("brunch")    || t.contains("breakfast") || t.contains("lunch")     { return "☀️" }
        if t.contains("golf")                                                             { return "⛳️" }
        if t.contains("tour")      || t.contains("walk")     || t.contains("hike")       { return "🚶" }
        if t.contains("game")      || t.contains("sport")    || t.contains("tennis")     { return "🏃" }
        if t.contains("photo")     || t.contains("picture")  || t.contains("portrait")   { return "📸" }
        if t.contains("ceremony")  || t.contains("award")                                { return "🏆" }
        if t.contains("memorial")  || t.contains("chapel")   || t.contains("service")   { return "🕊️" }
        return "🎉"
    }
}

// MARK: - Admin Errors

enum AdminError: LocalizedError {
    case missingUserId
    case invalidURL
    case fetchFailed
    case parseError(String)
    case noEventsFound
    case notAdmin

    var errorDescription: String? {
        switch self {
        case .missingUserId:        return "User ID is missing."
        case .invalidURL:           return "The URL entered is not valid."
        case .fetchFailed:          return "Could not fetch the calendar. Check the URL and try again."
        case .parseError(let msg):  return "Parse error: \(msg)"
        case .noEventsFound:        return "No events were found in this calendar feed."
        case .notAdmin:             return "Administrator privileges required."
        }
    }
}
