import SwiftUI

// MARK: - PelicanCon Brand Theme
// Navy blue + gold + cream — classic reunion / yearbook palette

enum Theme {
    // MARK: Colors
    static let navy      = Color(red: 0.08, green: 0.18, blue: 0.38)   // Deep navy
    static let gold      = Color(red: 0.85, green: 0.65, blue: 0.13)   // Warm gold
    static let cream     = Color(red: 0.98, green: 0.96, blue: 0.90)   // Off-white cream
    static let softBlue  = Color(red: 0.20, green: 0.40, blue: 0.70)   // Lighter navy accent
    static let darkGray  = Color(red: 0.20, green: 0.20, blue: 0.24)
    static let midGray   = Color(red: 0.55, green: 0.55, blue: 0.60)
    static let lightGray = Color(red: 0.93, green: 0.93, blue: 0.95)
    static let success   = Color(red: 0.20, green: 0.72, blue: 0.45)
    static let error     = Color(red: 0.90, green: 0.27, blue: 0.27)

    // Gradients
    static let navyGradient = LinearGradient(
        colors: [navy, softBlue],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let goldGradient = LinearGradient(
        colors: [gold, Color(red: 0.95, green: 0.78, blue: 0.30)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: Typography
    static func largeTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 32, weight: .bold, design: .serif))
            .foregroundColor(navy)
    }

    static func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .semibold, design: .default))
            .foregroundColor(navy)
    }

    // MARK: Shadows
    static let cardShadow = Color.black.opacity(0.08)
}

// MARK: - View Modifiers

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Theme.navyGradient)
                    .opacity(configuration.isPressed ? 0.85 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Theme.navy)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.navy, lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(configuration.isPressed ? 0.9 : 1.0))
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Theme.cardShadow, radius: 8, x: 0, y: 2)
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardStyle()) }
}

struct PelicanTextField: View {
    let placeholder: String
    let icon: String
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Theme.midGray)
                .frame(width: 20)
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .autocorrectionDisabled()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Theme.lightGray)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
