import SwiftUI

// MARK: - Badge type definitions

enum BadgeType: String, Codable, CaseIterable, Identifiable {
    case earlyBird       = "early_bird"
    case socialButterfly = "social_butterfly"
    case shutterbug      = "shutterbug"
    case checkedIn       = "checked_in"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .earlyBird:       return "Early Bird"
        case .socialButterfly: return "Social Butterfly"
        case .shutterbug:      return "Shutterbug"
        case .checkedIn:       return "Checked In"
        }
    }

    var description: String {
        switch self {
        case .earlyBird:       return "Among the first to join"
        case .socialButterfly: return "Sent 10+ messages"
        case .shutterbug:      return "Shared 5+ photos"
        case .checkedIn:       return "Checked in at the reunion"
        }
    }

    var icon: String {
        switch self {
        case .earlyBird:       return "bird.fill"
        case .socialButterfly: return "bubble.left.and.bubble.right.fill"
        case .shutterbug:      return "camera.fill"
        case .checkedIn:       return "checkmark.seal.fill"
        }
    }

    var color: Color {
        switch self {
        case .earlyBird:       return .orange
        case .socialButterfly: return Theme.softBlue
        case .shutterbug:      return Theme.gold
        case .checkedIn:       return Theme.success
        }
    }
}
