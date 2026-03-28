import SwiftUI

struct AdminDashboardView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var adminVM = AdminViewModel()
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.offWhite.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Admin badge header
                        adminBanner

                        // Stats row
                        statsRow

                        // Navigation cards
                        VStack(spacing: 14) {
                            adminNavCard(
                                icon:     "person.badge.minus",
                                iconColor: Theme.red,
                                title:    "User Management",
                                subtitle: "\(adminVM.allUsers.count) registered attendees",
                                destination: AnyView(
                                    UserManagementView()
                                        .environmentObject(adminVM)
                                        .environmentObject(authVM)
                                )
                            )

                            adminNavCard(
                                icon:     "calendar.badge.plus",
                                iconColor: Theme.red,
                                title:    "Calendar Event Sync",
                                subtitle: adminVM.icalConfig != nil
                                    ? "iCal active · \(adminVM.icalConfig!.eventCount) events"
                                    : "No iCal source linked",
                                destination: AnyView(
                                    ICalSyncView()
                                        .environmentObject(adminVM)
                                        .environmentObject(authVM)
                                )
                            )

                            adminNavCard(
                                icon:     "megaphone.fill",
                                iconColor: Theme.red,
                                title:    "Post Announcement",
                                subtitle: "Broadcast a message to all attendees",
                                destination: AnyView(
                                    AnnouncementsView().environmentObject(authVM)
                                )
                            )

                            adminNavCard(
                                icon:     "flag.fill",
                                iconColor: adminVM.flaggedPhotos.isEmpty ? Theme.navy : .orange,
                                title:    "Content Moderation",
                                subtitle: adminVM.flaggedPhotos.isEmpty
                                    ? "No reports pending"
                                    : "\(adminVM.flaggedPhotos.count) photo\(adminVM.flaggedPhotos.count == 1 ? "" : "s") flagged for review",
                                destination: AnyView(
                                    ModerationView()
                                        .environmentObject(adminVM)
                                        .environmentObject(authVM)
                                )
                            )

                            adminNavCard(
                                icon:     "lock.shield.fill",
                                iconColor: Theme.navy,
                                title:    "Invite List",
                                subtitle: "Manage who can register",
                                destination: AnyView(InviteListView())
                            )

                            adminNavCard(
                                icon:     "qrcode.viewfinder",
                                iconColor: Theme.success,
                                title:    "Check-In Scanner",
                                subtitle: "Scan attendee QR codes at the door",
                                destination: AnyView(QRScannerView())
                            )

                            adminNavCard(
                                icon:     "chart.bar.fill",
                                iconColor: Theme.navy,
                                title:    "RSVP Summary",
                                subtitle: "Per-event attendance breakdown",
                                destination: AnyView(
                                    RSVPSummaryView().environmentObject(authVM)
                                )
                            )
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Admin Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.red)
                }
            }
            .onAppear {
                if let uid = authVM.currentUser?.id {
                    adminVM.load(currentUserId: uid)
                    adminVM.startFlaggedStream(adminUid: uid)
                }
            }
        }
    }

    // MARK: - Subviews

    private var adminBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(Theme.redGradient).frame(width: 52, height: 52)
                Image(systemName: "shield.fill")
                    .font(.title3)
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("Administrator Access")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text("St. Paul's · Class of '91 Reunion")
                    .font(.caption)
                    .foregroundColor(Theme.yellow)
            }
            Spacer()
        }
        .padding(16)
        .background(Theme.redGradient)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(value: "\(adminVM.allUsers.count)", label: "Attendees")
            Divider().frame(height: 40)
            statCell(
                value: adminVM.icalConfig != nil ? "\(adminVM.icalConfig!.eventCount)" : "—",
                label: "Events"
            )
            Divider().frame(height: 40)
            statCell(
                value: adminVM.icalConfig != nil ? "iCal" : "Manual",
                label: "Schedule"
            )
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: Theme.cardShadow, radius: 6, x: 0, y: 2)
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.title3).fontWeight(.bold).foregroundColor(Theme.red)
            Text(label).font(.caption2).foregroundColor(Theme.midGray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    private func adminNavCard(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        destination: AnyView
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 46, height: 46)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(iconColor)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.darkGray)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Theme.midGray)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Theme.midGray)
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Theme.cardShadow, radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}
