import SwiftUI

struct ICalSyncView: View {
    @EnvironmentObject var adminVM: AdminViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @State private var showClearConfirm = false

    var body: some View {
        ZStack {
            Theme.offWhite.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {

                    // Current sync status card
                    syncStatusCard

                    // URL input
                    urlInputCard

                    // How-to guide
                    howToCard

                    // Preview of parsed events (shown after fetch)
                    if adminVM.showPreview && !adminVM.previewEvents.isEmpty {
                        previewCard
                    }

                    // Clear source (shown when active)
                    if adminVM.icalConfig != nil {
                        clearButton
                    }

                    Spacer(minLength: 32)
                }
                .padding(20)
            }
        }
        .navigationTitle("Calendar Event Sync")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if let msg = adminVM.syncSuccess {
                successToast(msg)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                            adminVM.syncSuccess = nil
                        }
                    }
            }
        }
        .animation(.spring(response: 0.4), value: adminVM.syncSuccess)
        .alert("Error", isPresented: .constant(adminVM.errorMessage != nil)) {
            Button("OK") { adminVM.clearMessages() }
        } message: {
            Text(adminVM.errorMessage ?? "")
        }
        .confirmationDialog("Clear Calendar Source?", isPresented: $showClearConfirm) {
            Button("Clear & Delete iCal Events", role: .destructive) {
                Task { await adminVM.clearICalSource() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will remove all iCal-imported events from the schedule. Manually created events are not affected.")
        }
    }

    // MARK: - Sync Status Card

    private var syncStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Sync Status", systemImage: "arrow.triangle.2.circlepath")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.darkGray)

            if let config = adminVM.icalConfig {
                HStack(spacing: 10) {
                    Circle().fill(Theme.success).frame(width: 9, height: 9)
                    Text("iCal source active")
                        .font(.subheadline).foregroundColor(Theme.darkGray)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Label("\(config.eventCount) events imported", systemImage: "calendar.badge.checkmark")
                        .font(.caption).foregroundColor(Theme.midGray)
                    if let syncDate = config.lastSyncAt {
                        Label("Last synced \(syncDate, style: .relative) ago",
                              systemImage: "clock")
                            .font(.caption).foregroundColor(Theme.midGray)
                    }
                    Text(config.url)
                        .font(.caption2)
                        .foregroundColor(Theme.midGray)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            } else {
                HStack(spacing: 10) {
                    Circle().fill(Theme.midGray).frame(width: 9, height: 9)
                    Text("No iCal source linked — events managed manually")
                        .font(.subheadline).foregroundColor(Theme.midGray)
                }
            }
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: - URL Input Card

    private var urlInputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Calendar URL (.ics)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.darkGray)

            // URL field
            HStack(spacing: 10) {
                Image(systemName: "link").foregroundColor(Theme.midGray).frame(width: 20)
                TextField("https://calendar.google.com/…/basic.ics", text: $adminVM.icalURLInput, axis: .vertical)
                    .font(.system(size: 14))
                    .autocorrectionDisabled()
                    .autocapitalization(.none)
                    .keyboardType(.URL)
                    .lineLimit(3)
            }
            .padding(14)
            .background(Theme.lightGray)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            // Fetch button
            Button {
                Task { await adminVM.fetchICalPreview() }
            } label: {
                if adminVM.isFetching {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white)
                        Text("Fetching calendar…")
                    }
                } else {
                    Label("Fetch & Preview Events", systemImage: "arrow.down.circle.fill")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(adminVM.isFetching || adminVM.icalURLInput.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(16)
        .cardStyle()
    }

    // MARK: - Preview card

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("\(adminVM.previewEvents.count) events found", systemImage: "calendar.badge.checkmark")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.darkGray)
                Spacer()
                Text("Preview")
                    .font(.caption)
                    .foregroundColor(Theme.midGray)
            }

            Divider()

            ForEach(adminVM.previewEvents.prefix(8)) { event in
                previewEventRow(event)
                if event.id != adminVM.previewEvents.prefix(8).last?.id {
                    Divider().padding(.leading, 36)
                }
            }

            if adminVM.previewEvents.count > 8 {
                Text("+ \(adminVM.previewEvents.count - 8) more events…")
                    .font(.caption)
                    .foregroundColor(Theme.midGray)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            // Confirm import button
            Button {
                guard let adminId = authVM.currentUser?.id else { return }
                Task { await adminVM.confirmSync(adminUid: adminId) }
            } label: {
                if adminVM.isSyncing {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white)
                        Text("Importing…")
                    }
                } else {
                    Label(
                        "Confirm Import (\(adminVM.previewEvents.count) events)",
                        systemImage: "checkmark.circle.fill"
                    )
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(adminVM.isSyncing)

            Button("Cancel Preview") {
                adminVM.showPreview   = false
                adminVM.previewEvents = []
            }
            .font(.subheadline)
            .foregroundColor(Theme.midGray)
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(Theme.yellow.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.yellow.opacity(0.5), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func previewEventRow(_ event: ReunionEvent) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(event.emoji)
                .font(.title3)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.darkGray)
                Text(event.formattedDate + " · " + event.formattedTimeRange)
                    .font(.caption)
                    .foregroundColor(Theme.midGray)
                if !event.locationName.isEmpty {
                    Label(event.locationName, systemImage: "mappin")
                        .font(.caption2)
                        .foregroundColor(Theme.midGray)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - How-to card

    private var howToCard: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                howToRow(source: "Google Calendar",
                         steps: "Calendar Settings → Integrate calendar → Secret address in iCal format")
                Divider()
                howToRow(source: "Apple iCloud",
                         steps: "Calendar app → Share → enable Public Calendar → copy link")
                Divider()
                howToRow(source: "Outlook / Microsoft 365",
                         steps: "Calendar → Share → Publish → ICS link")
                Divider()
                howToRow(source: "Any .ics file",
                         steps: "Host the file publicly on S3, Dropbox, etc. and paste the direct URL")
            }
            .padding(.top, 8)
        } label: {
            Label("How to get a calendar link", systemImage: "questionmark.circle")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.darkGray)
        }
        .padding(16)
        .cardStyle()
        .tint(Theme.red)
    }

    private func howToRow(source: String, steps: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(source)
                .font(.caption).fontWeight(.semibold).foregroundColor(Theme.darkGray)
            Text(steps)
                .font(.caption2).foregroundColor(Theme.midGray)
        }
    }

    // MARK: - Clear button

    private var clearButton: some View {
        Button {
            showClearConfirm = true
        } label: {
            Label("Clear iCal Source", systemImage: "calendar.badge.minus")
                .foregroundColor(Theme.red)
        }
        .buttonStyle(SecondaryButtonStyle())
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Theme.red, lineWidth: 1.5)
        )
    }

    // MARK: - Toast

    private func successToast(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill").foregroundColor(.white)
            Text(message).font(.subheadline).fontWeight(.medium).foregroundColor(.white)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(Theme.success)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8)
        .padding(.top, 12)
    }
}
