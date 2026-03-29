import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss
    var showAcceptButton = false
    var onAccept: (() -> Void)?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.cream.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Header
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Privacy Policy & Terms of Use")
                                .font(.system(size: 22, weight: .bold, design: .serif))
                                .foregroundColor(Theme.red)
                            Text("Last updated: March 2026")
                                .font(.caption)
                                .foregroundColor(Theme.midGray)
                            Divider()
                        }

                        section(title: "Who We Are") {
                            "PelicanCon is a private iOS application built exclusively for the St. Paul's School Class of 1991 35th Reunion at Pelican Bay Resort. Access is limited to invited attendees."
                        }

                        section(title: "Information We Collect") {
                            """
                            • Account information: your name, maiden name, email address, class year, and profile photo.
                            • Profile data: current city, biography, and optional social media links you choose to add.
                            • Photos you upload to the shared gallery.
                            • Messages sent in the group chat and direct messages.
                            • RSVP responses for scheduled events.
                            • Device FCM token for push notifications.
                            • Last-seen timestamp (used to show active status).
                            """
                        }

                        section(title: "How We Use Your Information") {
                            """
                            • To display your profile to other verified classmates.
                            • To enable messaging between attendees.
                            • To send push notifications about events, messages, and photos you've opted into.
                            • To manage the event schedule and your RSVP responses.
                            • To allow administrators to manage the attendee list.
                            """
                        }

                        section(title: "Data Sharing") {
                            """
                            Your data is visible only to other verified PelicanCon attendees. We do not sell, rent, or share your personal information with any third parties for marketing purposes.

                            Our infrastructure partners include:
                            • Google Firebase (Firestore, Authentication, Storage, Cloud Functions) — data processing agreement in place.
                            • Google Sign-In (optional authentication method).
                            • Apple Sign In (optional authentication method).
                            """
                        }

                        section(title: "Photos & Media") {
                            """
                            Photos you upload are stored securely in Firebase Cloud Storage and visible to all PelicanCon attendees. You can delete your own photos at any time. Administrators may remove photos that violate community standards.
                            """
                        }

                        section(title: "Push Notifications") {
                            """
                            We send push notifications for: event reminders, new messages, new photos, and class announcements. You can control which categories you receive in Settings → Notifications, or disable all notifications in your device Settings.
                            """
                        }

                        section(title: "Data Retention") {
                            """
                            Your account data is retained until you delete your account (Settings → Delete My Account). Deletion removes your profile, messages, photos, and authentication record permanently. Administrators can also remove accounts for conduct violations.
                            """
                        }

                        section(title: "Your Rights") {
                            """
                            You may request access to or deletion of your personal data at any time by deleting your account within the app, or by contacting a reunion organizer. As this is a private event application, we comply with applicable data protection regulations on a best-efforts basis.
                            """
                        }

                        section(title: "Terms of Use") {
                            """
                            By using PelicanCon you agree to:
                            • Only use the app if you are a verified St. Paul's School Class of 1991 alumnus or an invited guest.
                            • Treat fellow classmates with respect in all messages and photo content.
                            • Not share your login credentials or invite unauthorized individuals.
                            • Accept that administrators may remove accounts or content that violate these terms.

                            This application is provided "as is" for the duration of the reunion weekend. No warranty is made regarding uptime or data permanence beyond the event.
                            """
                        }

                        section(title: "Contact") {
                            "For privacy questions or data requests, contact the reunion organizing committee at reunion@stpauls91.com."
                        }

                        if showAcceptButton {
                            Button("I Agree — Continue") {
                                onAccept?()
                            }
                            .buttonStyle(PrimaryButtonStyle())
                            .padding(.top, 8)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.red)
                }
            }
        }
    }

    @ViewBuilder
    private func section(title: String, @ViewBuilder body: () -> String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Theme.darkGray)
            Text(body())
                .font(.system(size: 14))
                .foregroundColor(Theme.midGray)
                .lineSpacing(4)
        }
    }
}
