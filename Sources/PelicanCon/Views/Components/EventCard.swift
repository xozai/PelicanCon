import SwiftUI

struct EventCard: View {
    let event: ReunionEvent
    let userRSVP: RSVPStatus?
    let onRSVP: (RSVPStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header stripe
            HStack {
                Text(event.emoji)
                    .font(.title2)
                Text(event.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text(event.formattedTimeRange)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.navyGradient)

            // Body
            VStack(alignment: .leading, spacing: 10) {
                Label(event.locationName, systemImage: "mappin.circle.fill")
                    .font(.subheadline)
                    .foregroundColor(Theme.softBlue)

                if !event.description.isEmpty {
                    Text(event.description)
                        .font(.subheadline)
                        .foregroundColor(Theme.darkGray)
                        .lineLimit(2)
                }

                // RSVP row
                HStack(spacing: 8) {
                    ForEach(RSVPStatus.allCases, id: \.rawValue) { status in
                        rsvpButton(status)
                    }
                    Spacer()
                    Text("\(event.goingCount) going")
                        .font(.caption)
                        .foregroundColor(Theme.midGray)
                }
            }
            .padding(16)
        }
        .cardStyle()
    }

    private func rsvpButton(_ status: RSVPStatus) -> some View {
        let isSelected = userRSVP == status
        return Button {
            onRSVP(status)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: status.icon)
                Text(status.label)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(isSelected ? Theme.navy : Theme.lightGray)
            )
            .foregroundColor(isSelected ? .white : Theme.darkGray)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
