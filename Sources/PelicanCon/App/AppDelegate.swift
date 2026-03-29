import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications
import GoogleSignIn

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        // NOTE: Notification permission is requested at the end of ProfileSetupView
        // (after the user understands the app's purpose) — not here at cold launch.
        Messaging.messaging().delegate = self
        registerNotificationCategories()
        return true
    }

    /// Register actionable notification categories.
    /// - MESSAGE: inline reply action
    /// - EVENT_REMINDER: no actions (just a tap-to-open)
    private func registerNotificationCategories() {
        let replyAction = UNTextInputNotificationAction(
            identifier: "REPLY_ACTION",
            title: "Reply",
            options: [],
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Write a reply…"
        )
        let messageCategory = UNNotificationCategory(
            identifier: "MESSAGE",
            actions: [replyAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        let eventCategory = UNNotificationCategory(
            identifier: "EVENT_REMINDER",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories(
            [messageCategory, eventCategory]
        )
    }

    /// Called from ProfileSetupView once the user has completed onboarding.
    func requestNotificationPermissionIfNeeded() {
        let options: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, _ in
                if granted {
                    DispatchQueue.main.async {
                        UIApplication.shared.registerForRemoteNotifications()
                    }
                }
            }
        }
    }

    // MARK: - Google Sign-In URL handling
    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    // MARK: - APNs device token
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[AppDelegate] Failed to register for remote notifications: \(error.localizedDescription)")
    }

}

// MARK: - UNUserNotificationCenterDelegate
extension AppDelegate: UNUserNotificationCenterDelegate {

    /// Show notification banner while app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .badge, .sound])
    }

    /// Handle notification tap or action
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Inline reply from lock screen / notification banner
        if response.actionIdentifier == "REPLY_ACTION",
           let textInput = response as? UNTextInputNotificationResponse,
           let convId    = userInfo["conversationId"] as? String {
            let replyText = textInput.userText
            Task {
                guard let uid  = AuthService.shared.currentUserId,
                      let name = await UserService.shared.fetchDisplayName(userId: uid),
                      !replyText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                try? await MessageService.shared.sendTextMessage(
                    conversationId: convId,
                    senderId:       uid,
                    senderName:     name,
                    senderPhotoURL: nil,
                    text:           replyText
                )
            }
        } else {
            NotificationService.shared.handleNotificationTap(userInfo: userInfo)
        }
        completionHandler()
    }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        NotificationService.shared.updateFCMToken(token)
    }
}
