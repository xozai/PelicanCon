import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var eventVM:     EventViewModel
    @EnvironmentObject var authVM:      AuthViewModel
    @EnvironmentObject var galleryVM:   GalleryViewModel
    @EnvironmentObject var directoryVM: DirectoryViewModel
    @State private var selectedEvent:     ReunionEvent?
    @State private var selectedHighlight: SharedPhoto?
    @State private var showAnnouncements = false
    @State private var showTrivia        = false
    @State private var showSurvey        = false

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

                            // Fun & Games section
                            funSection

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
                    .environmentObject(directoryVM)
            }
            .sheet(item: $selectedHighlight) { photo in
                PhotoDetailView(photo: photo)
                    .environmentObject(galleryVM)
            }
            .sheet(isPresented: $showTrivia) {
                TriviaView().environmentObject(authVM)
            }
            .sheet(isPresented: $showSurvey) {
                SurveyView().environmentObject(authVM)
            }
            .alert("Calendar", isPresented: .constant(eventVM.calendarSuccessMessage != nil)) {
                Button("OK") { eventVM.clearCalendarSuccess() }
            } message: {
                Text(eventVM.calendarSuccessMessage ?? "")
            }
        }
    }

    private var funSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fun & Games")
                .font(.system(size: 17, weight: .bold, design: .serif))
                .foregroundColor(Theme.navy)
                .padding(.horizontal, 20)

            HStack(spacing: 12) {
                funCard(
                    icon: "questionmark.bubble.fill",
                    color: Theme.softBlue,
                    title: "Trivia",
                    subtitle: "Test your class knowledge"
                ) { showTrivia = true }

                funCard(
                    icon: "doc.text.fill",
                    color: Theme.success,
                    title: "Survey",
                    subtitle: "Share your memories"
                ) { showSurvey = true }
            }
            .padding(.horizontal, 20)
        }
    }

    private func funCard(
        icon: String,
        color: Color,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.darkGray)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(Theme.midGray)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundColor(Theme.midGray)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: Theme.cardShadow, radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
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
