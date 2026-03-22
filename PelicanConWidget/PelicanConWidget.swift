import WidgetKit
import SwiftUI

// MARK: - Reunion date (update if the date changes)
private let reunionStartDate: Date = {
    var c = DateComponents()
    c.year = 2026; c.month = 9; c.day = 18  // September 18, 2026
    return Calendar.current.date(from: c) ?? Date()
}()

// MARK: - Timeline Entry

struct ReunionCountdownEntry: TimelineEntry {
    let date:       Date
    let daysLeft:   Int
    let isHere:     Bool
    let nextEvent:  String?
}

// MARK: - Provider

struct ReunionCountdownProvider: TimelineProvider {
    typealias Entry = ReunionCountdownEntry

    func placeholder(in context: Context) -> Entry {
        ReunionCountdownEntry(date: Date(), daysLeft: 12, isHere: false, nextEvent: "Welcome Reception")
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(makeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let entry      = makeEntry()
        // Refresh at midnight each day (countdown decrements)
        let midnight   = Calendar.current.nextDate(
            after: Date(),
            matching: DateComponents(hour: 0, minute: 0, second: 1),
            matchingPolicy: .nextTime
        ) ?? Date().addingTimeInterval(86400)

        completion(Timeline(entries: [entry], policy: .after(midnight)))
    }

    private func makeEntry() -> ReunionCountdownEntry {
        let now      = Date()
        let days     = Calendar.current.dateComponents([.day], from: now, to: reunionStartDate).day ?? 0
        let isHere   = days <= 0
        return ReunionCountdownEntry(
            date:      now,
            daysLeft:  max(0, days),
            isHere:    isHere,
            nextEvent: isHere ? "Welcome Reception · 6pm" : nil
        )
    }
}

// MARK: - Small Widget view

struct ReunionCountdownWidgetView: View {
    var entry: ReunionCountdownEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            // St. Paul's red background
            Color(red: 0.682, green: 0.071, blue: 0.106)

            VStack(spacing: family == .systemSmall ? 4 : 8) {
                // Pelican icon
                HStack(spacing: 4) {
                    Image(systemName: "bird.fill")
                        .font(.system(size: family == .systemSmall ? 14 : 18))
                        .foregroundColor(.white)
                    Text("PelicanCon")
                        .font(.system(size: family == .systemSmall ? 10 : 13, weight: .bold))
                        .foregroundColor(Color(red: 1, green: 0.851, blue: 0.118))
                }

                if entry.isHere {
                    Text("🎉")
                        .font(.system(size: family == .systemSmall ? 36 : 48))
                    Text("We're here!")
                        .font(.system(size: family == .systemSmall ? 13 : 18, weight: .bold))
                        .foregroundColor(.white)
                    if let event = entry.nextEvent, family != .systemSmall {
                        Text(event)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Text("\(entry.daysLeft)")
                        .font(.system(size: family == .systemSmall ? 52 : 72,
                                      weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.5)
                    Text(entry.daysLeft == 1 ? "day to go" : "days to go")
                        .font(.system(size: family == .systemSmall ? 11 : 15, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                    Text("Class of '91 Reunion")
                        .font(.system(size: family == .systemSmall ? 9 : 12))
                        .foregroundColor(Color(red: 1, green: 0.851, blue: 0.118))
                }
            }
            .padding(family == .systemSmall ? 10 : 16)
        }
    }
}

// MARK: - Widget definition

struct PelicanConWidget: Widget {
    let kind = "PelicanConCountdown"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ReunionCountdownProvider()) { entry in
            ReunionCountdownWidgetView(entry: entry)
                .containerBackground(
                    Color(red: 0.682, green: 0.071, blue: 0.106),
                    for: .widget
                )
        }
        .configurationDisplayName("Reunion Countdown")
        .description("Days until the St. Paul's Class of '91 reunion.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Widget bundle

@main
struct PelicanConWidgetBundle: WidgetBundle {
    var body: some Widget {
        PelicanConWidget()
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    PelicanConWidget()
} timeline: {
    ReunionCountdownEntry(date: .now, daysLeft: 14, isHere: false, nextEvent: nil)
    ReunionCountdownEntry(date: .now, daysLeft: 0,  isHere: true,  nextEvent: "Welcome Reception · 6pm")
}
