import SwiftUI
import FirebaseFirestore

struct RSVPSummaryView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var events:    [ReunionEvent] = []
    @State private var users:     [AppUser]      = []
    @State private var isLoading  = true
    @State private var showShare  = false
    @State private var csvURL:    URL?
    // Two separate long-running stream tasks (never-terminating for await loops
    // cannot be composed with async let — each needs its own Task).
    @State private var eventsTask: Task<Void, Never>?
    @State private var usersTask:  Task<Void, Never>?
    @State private var eventsLoaded = false
    @State private var usersLoaded  = false

    var body: some View {
        ZStack {
            Theme.offWhite.ignoresSafeArea()
            if isLoading {
                ProgressView("Loading RSVP data…").tint(Theme.red)
            } else {
                List {
                    ForEach(events.sorted { $0.startTime < $1.startTime }) { event in
                        eventSection(event)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .navigationTitle("RSVP Summary")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    csvURL  = generateCSV()
                    showShare = true
                } label: {
                    Image(systemName: "square.and.arrow.up").foregroundColor(Theme.red)
                }
                .disabled(events.isEmpty)
            }
        }
        .sheet(isPresented: $showShare) {
            if let url = csvURL {
                ShareSheet(items: [url])
            }
        }
        .onAppear { startListeners() }
        .onDisappear {
            eventsTask?.cancel()
            usersTask?.cancel()
        }
    }

    // MARK: - Event section

    @ViewBuilder
    private func eventSection(_ event: ReunionEvent) -> some View {
        Section {
            let going  = rsvpCount(event, .going)
            let maybe  = rsvpCount(event, .maybe)
            let no     = rsvpCount(event, .no)
            let none   = users.count - going - maybe - no

            rsvpRow(label: "Going",        count: going, icon: "checkmark.circle.fill", color: Theme.success)
            rsvpRow(label: "Maybe",        count: maybe, icon: "questionmark.circle.fill", color: Theme.yellow)
            rsvpRow(label: "Can't make it",count: no,    icon: "xmark.circle.fill",     color: Theme.error)
            rsvpRow(label: "No response",  count: none,  icon: "minus.circle",          color: Theme.midGray)

            if going > 0 {
                DisclosureGroup("Going (\(going))") {
                    ForEach(attendees(event, .going)) { user in
                        attendeeRow(user)
                    }
                }
                .font(.caption).foregroundColor(Theme.midGray)
            }
        } header: {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(event.emoji) \(event.title)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.darkGray)
                Text(event.formattedDate + " · " + event.formattedTimeRange)
                    .font(.caption2).foregroundColor(Theme.midGray)
            }
            .padding(.vertical, 4)
            .textCase(nil)
        }
    }

    private func rsvpRow(label: String, count: Int, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon).foregroundColor(color).frame(width: 22)
            Text(label).font(.subheadline).foregroundColor(Theme.darkGray)
            Spacer()
            Text("\(count)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(count > 0 ? color : Theme.midGray)
            Text("/ \(users.count)")
                .font(.caption2).foregroundColor(Theme.midGray)
        }
    }

    private func attendeeRow(_ user: AppUser) -> some View {
        HStack(spacing: 10) {
            AvatarView(user: user, size: 28)
            Text(user.fullDisplayName).font(.caption).foregroundColor(Theme.darkGray)
            Spacer()
            if let city = user.currentCity {
                Text(city).font(.caption2).foregroundColor(Theme.midGray)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Helpers

    private func rsvpCount(_ event: ReunionEvent, _ status: RSVPStatus) -> Int {
        event.rsvps.values.filter { $0 == status }.count
    }

    private func attendees(_ event: ReunionEvent, _ status: RSVPStatus) -> [AppUser] {
        let ids = event.rsvps.filter { $0.value == status }.map(\.key)
        return users.filter { ids.contains($0.id ?? "") }
    }

    // MARK: - CSV export

    private func generateCSV() -> URL? {
        var rows = ["Event,Date,Going,Maybe,Can't Make It,No Response,Total Invited"]
        for event in events.sorted(by: { $0.startTime < $1.startTime }) {
            let g    = rsvpCount(event, .going)
            let m    = rsvpCount(event, .maybe)
            let n    = rsvpCount(event, .no)
            let none = users.count - g - m - n
            let row  = "\"\(event.title)\",\"\(event.formattedDate)\",\(g),\(m),\(n),\(none),\(users.count)"
            rows.append(row)
        }
        let csv  = rows.joined(separator: "\n")
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("RSVP_Summary.csv")
        try? csv.write(to: file, atomically: true, encoding: .utf8)
        return file
    }

    // MARK: - Data loading

    private func startListeners() {
        isLoading    = true
        eventsLoaded = false
        usersLoaded  = false

        eventsTask = Task { @MainActor in
            for await loaded in EventService.shared.eventsStream() {
                events = loaded
                if !eventsLoaded {
                    eventsLoaded = true
                    if usersLoaded { isLoading = false }
                }
            }
        }

        usersTask = Task { @MainActor in
            for await loaded in UserService.shared.allUsersStream() {
                users = loaded
                if !usersLoaded {
                    usersLoaded = true
                    if eventsLoaded { isLoading = false }
                }
            }
        }
    }
}

// MARK: - UIActivityViewController wrapper

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
