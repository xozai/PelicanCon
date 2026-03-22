import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var eventVM:   EventViewModel
    @EnvironmentObject var authVM:    AuthViewModel
    @EnvironmentObject var galleryVM: GalleryViewModel
    @State private var selectedEvent:     ReunionEvent?
    @State private var selectedHighlight: SharedPhoto?
    @State private var showAnnouncements = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.cream.ignoresSafeArea()

                if eventVM.isLoading {
                    ProgressView("Loading schedule…")
                        .tint(Theme.navy)
                } else if eventVM.groupedEvents.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Banner
                            reuniteBanner

                            // Memory Lane highlights carousel
                            MemoryLaneHighlightsView { photo in
                                selectedHighlight = photo
                            }

                            // Event groups
                            ForEach(eventVM.groupedEvents, id: \.day) { group in
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text(group.date)
                                            .font(.system(size: 17, weight: .bold, design: .serif))
                                            .foregroundColor(Theme.navy)
                                        Spacer()
                                        Text("\(group.events.count) event\(group.events.count == 1 ? "" : "s")")
                                            .font(.caption)
                                            .foregroundColor(Theme.midGray)
                                    }
                                    .padding(.horizontal, 20)

                                    ForEach(group.events) { event in
                                        EventCard(
                                            event: event,
                                            userRSVP: eventVM.currentRSVP(for: event)
                                        ) { status in
                                            Task { await eventVM.updateRSVP(event: event, status: status) }
                                        }
                                        .padding(.horizontal, 16)
                                        .onTapGesture { selectedEvent = event }
                                    }
                                }
                            }

                            Spacer(minLength: 32)
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Schedule")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAnnouncements = true
                    } label: {
                        Image(systemName: "megaphone.fill").foregroundColor(Theme.gold)
                    }
                }
            }
            .sheet(isPresented: $showAnnouncements) {
                NavigationStack {
                    AnnouncementsView().environmentObject(authVM)
                }
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailView(event: event)
                    .environmentObject(eventVM)
            }
            .sheet(item: $selectedHighlight) { photo in
                PhotoDetailView(photo: photo)
                    .environmentObject(galleryVM)
            }
            .alert("Calendar", isPresented: .constant(eventVM.calendarSuccessMessage != nil)) {
                Button("OK") { eventVM.clearCalendarSuccess() }
            } message: {
                Text(eventVM.calendarSuccessMessage ?? "")
            }
        }
    }

    private var reuniteBanner: some View {
        HStack(spacing: 14) {
            // Pelican brand mark
            ZStack {
                Image(systemName: "bird.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.white)
                Circle()
                    .fill(Theme.yellow)
                    .frame(width: 9, height: 9)
                    .offset(x: 11, y: 5)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("St. Paul's School")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text("Class of '91 · 35th Reunion Weekend")
                    .font(.caption)
                    .foregroundColor(Theme.yellow)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(eventVM.events.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.yellow)
                Text("events")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(18)
        .background(Theme.redGradient)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 56))
                .foregroundColor(Theme.midGray)
            Text("No Events Yet")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(Theme.darkGray)
            Text("The reunion schedule will appear here once events are added.")
                .font(.subheadline)
                .foregroundColor(Theme.midGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}
