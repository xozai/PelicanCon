import SwiftUI
import MapKit

struct EventDetailView: View {
    let event: ReunionEvent
    @EnvironmentObject var eventVM: EventViewModel
    @EnvironmentObject var directoryVM: DirectoryViewModel
    @Environment(\.dismiss) var dismiss
    @State private var mapRegion: MKCoordinateRegion
    @State private var showVenueGuide = false

    init(event: ReunionEvent) {
        self.event = event
        _mapRegion = State(initialValue: MKCoordinateRegion(
            center: event.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    ZStack(alignment: .bottomLeading) {
                        Theme.navyGradient
                            .frame(height: 160)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(event.emoji)
                                .font(.system(size: 40))
                            Text(event.title)
                                .font(.system(size: 26, weight: .bold, design: .serif))
                                .foregroundColor(.white)
                        }
                        .padding(20)
                    }

                    VStack(alignment: .leading, spacing: 20) {
                        // Date / time
                        infoRow(icon: "calendar", color: Theme.softBlue) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.formattedDate)
                                    .fontWeight(.semibold)
                                Text(event.formattedTimeRange)
                                    .font(.subheadline)
                                    .foregroundColor(Theme.midGray)
                            }
                        }

                        // Location
                        infoRow(icon: "mappin.circle.fill", color: Theme.error) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.locationName)
                                    .fontWeight(.semibold)
                                Text(event.address)
                                    .font(.subheadline)
                                    .foregroundColor(Theme.midGray)
                            }
                        }

                        // Description
                        if !event.description.isEmpty {
                            Text(event.description)
                                .font(.body)
                                .foregroundColor(Theme.darkGray)
                                .lineSpacing(4)
                        }

                        // RSVP
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Will you be there?")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Theme.navy)

                            HStack(spacing: 10) {
                                ForEach(RSVPStatus.allCases, id: \.rawValue) { status in
                                    rsvpButton(status)
                                }
                            }

                            // Going attendee avatars
                            let goingIds = eventVM.goingAttendeeIds(for: event)
                            let goingUsers = directoryVM.allUsers.filter { goingIds.contains($0.id ?? "") }
                            if !goingUsers.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: -10) {
                                        ForEach(goingUsers.prefix(12)) { user in
                                            AvatarView(user: user, size: 32)
                                                .overlay(
                                                    Circle().stroke(Color.white, lineWidth: 2)
                                                )
                                        }
                                        if goingUsers.count > 12 {
                                            ZStack {
                                                Circle()
                                                    .fill(Theme.lightGray)
                                                    .frame(width: 32, height: 32)
                                                Text("+\(goingUsers.count - 12)")
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundColor(Theme.midGray)
                                            }
                                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                        }
                                    }
                                }
                            }

                            Text("\(event.goingCount) classmate\(event.goingCount == 1 ? "" : "s") going")
                                .font(.caption)
                                .foregroundColor(Theme.midGray)
                        }
                        .padding(16)
                        .cardStyle()

                        // Map
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Location")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Theme.navy)

                            Map(coordinateRegion: $mapRegion, annotationItems: [event]) { _ in
                                MapMarker(coordinate: event.coordinate, tint: Theme.navy)
                            }
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .accessibilityLabel("Map showing \(event.locationName)")
                            .accessibilityHint("Interactive map. Double-tap to open in Maps app.")

                            Button {
                                openInMaps()
                            } label: {
                                Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(Theme.softBlue)
                            }
                            .frame(minHeight: 44)
                            .accessibilityLabel("Get directions to \(event.locationName)")
                        }

                        // Venue Guide button
                        Button {
                            showVenueGuide = true
                        } label: {
                            Label("Venue Guide", systemImage: "map.fill")
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        // Add to Calendar button
                        Button {
                            Task { await eventVM.addToCalendar(event) }
                        } label: {
                            Label("Add to Calendar", systemImage: "calendar.badge.plus")
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        Spacer(minLength: 32)
                    }
                    .padding(20)
                }
            }
            .ignoresSafeArea(edges: .top)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.navy)
                }
            }
            .sheet(isPresented: $showVenueGuide) {
                VenueGuideView(event: event)
            }
        }
    }

    private func rsvpButton(_ status: RSVPStatus) -> some View {
        let isSelected = eventVM.currentRSVP(for: event) == status
        return Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            Task { await eventVM.updateRSVP(event: event, status: status) }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: status.icon)
                Text(status.label)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(isSelected ? Theme.navy : Theme.lightGray)
            )
            .foregroundColor(isSelected ? .white : Theme.darkGray)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .accessibilityLabel(status.label)
        .accessibilityValue(isSelected ? "selected" : "not selected")
        .accessibilityHint("Double-tap to RSVP \(status.label.lowercased())")
    }

    private func infoRow<Content: View>(icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 28)
            content()
            Spacer()
        }
    }

    private func openInMaps() {
        let url = URL(string: "maps://?daddr=\(event.latitude),\(event.longitude)")!
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}
