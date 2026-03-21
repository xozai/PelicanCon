import SwiftUI

struct ScheduleView: View {
    @EnvironmentObject var eventVM: EventViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @State private var selectedEvent: ReunionEvent?

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
                    Image(systemName: "bird.fill")
                        .foregroundColor(Theme.gold)
                }
            }
            .sheet(item: $selectedEvent) { event in
                EventDetailView(event: event)
                    .environmentObject(eventVM)
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
            Text("🎓")
                .font(.system(size: 36))
            VStack(alignment: .leading, spacing: 2) {
                Text("Class of 1991")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Text("35th Reunion Weekend")
                    .font(.caption)
                    .foregroundColor(Theme.gold.opacity(0.9))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(eventVM.events.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.gold)
                Text("events")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(18)
        .background(Theme.navyGradient)
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
