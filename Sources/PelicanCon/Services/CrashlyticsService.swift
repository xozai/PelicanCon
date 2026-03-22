import Foundation
import FirebaseCrashlytics

/// Thin wrapper around Firebase Crashlytics that ties crash reports to
/// the authenticated user and provides structured error logging.
enum CrashlyticsService {

    // MARK: - Session identity

    /// Call after successful sign-in so crash reports are attributed to a user.
    static func setUser(_ user: AppUser) {
        guard let uid = user.id else { return }
        Crashlytics.crashlytics().setUserID(uid)
        Crashlytics.crashlytics().setCustomValue(user.displayName, forKey: "displayName")
        Crashlytics.crashlytics().setCustomValue(user.email,       forKey: "email")
        Crashlytics.crashlytics().setCustomValue(user.isAdmin,     forKey: "isAdmin")
    }

    /// Call on sign-out to stop attributing future reports to this user.
    static func clearUser() {
        Crashlytics.crashlytics().setUserID("")
        Crashlytics.crashlytics().setCustomValue("", forKey: "displayName")
        Crashlytics.crashlytics().setCustomValue("", forKey: "email")
    }

    // MARK: - Non-fatal error logging

    /// Log a non-fatal error with optional context keys (e.g. screen name, operation).
    static func record(_ error: Error, context: [String: String] = [:]) {
        var info = context
        info["localizedDescription"] = error.localizedDescription
        Crashlytics.crashlytics().record(error: error,
                                         userInfo: info.mapValues { $0 as Any })
    }

    /// Log a string message that will appear in the Crashlytics log for the session.
    static func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }

    // MARK: - Breadcrumb helpers for key operations

    static func logPhotoUpload(uploaderId: String, isMemoryLane: Bool) {
        log("PhotoUpload: uploader=\(uploaderId) memoryLane=\(isMemoryLane)")
    }

    static func logRSVP(eventId: String, status: String) {
        log("RSVP: event=\(eventId) status=\(status)")
    }

    static func logMessageSent(conversationId: String, isGroup: Bool) {
        log("MessageSent: conv=\(conversationId) group=\(isGroup)")
    }

    static func logAdminAction(_ action: String, targetUid: String) {
        log("AdminAction: \(action) target=\(targetUid)")
        Crashlytics.crashlytics().setCustomValue(action, forKey: "lastAdminAction")
    }
}
