import SwiftUI

// MARK: - PelicanCon Brand Theme
// St. Paul's School Official Athletic Brand Colors
// Source: St. Paul's Athletic Branding Implementation Guidelines
//
//  St. Paul's Red   — PMS 200  | #C72035 | RGB(199, 32, 53)
//  St. Paul's Yellow — PMS 115 | #FFD91E | RGB(255, 217, 30)
//  St. Paul's Black             | #000000 | RGB(0, 0, 0)
//  St. Paul's White             | #FFFFFF | RGB(255, 255, 255)

enum Theme {
    // MARK: - Official St. Paul's Brand Colors
    static let red        = Color(red: 199/255, green: 32/255,  blue: 53/255)   // PMS 200 · #C72035
    static let redDark    = Color(red: 140/255, green: 16/255,  blue: 32/255)   // Deep crimson for gradients
    static let redLight   = Color(red: 220/255, green: 60/255,  blue: 78/255)   // Lighter red for hover states
    static let yellow     = Color(red: 255/255, green: 217/255, blue: 30/255)   // PMS 115 · #FFD91E
    static let yellowDark = Color(red: 220/255, green: 185/255, blue: 10/255)   // Deeper gold for text on white

    // MARK: - Neutral Palette (St. Paul's Black & White + grays)
    static let black      = Color(red: 0/255,   green: 0/255,   blue: 0/255)    // #000000
    static let white      = Color.white                                           // #FFFFFF
    static let offWhite   = Color(red: 250/255, green: 248/255, blue: 245/255)  // warm off-white page bg
    static let darkGray   = Color(red: 28/255,  green: 28/255,  blue: 30/255)   // near-black body text
    static let midGray    = Color(red: 108/255, green: 108/255, blue: 112/255)  // secondary labels
    static let lightGray  = Color(red: 236/255, green: 236/255, blue: 238/255)  // input backgrounds
    static let divider    = Color(red: 220/255, green: 220/255, blue: 222/255)

    // MARK: - Semantic
    static let success    = Color(red: 52/255,  green: 168/255, blue: 83/255)   // green
    static let error      = Color(red: 199/255, green: 32/255,  blue: 53/255)   // re-use brand red

    // MARK: - Gradients
    /// Primary gradient: deep crimson → brand red (used on headers, buttons, cards)
    static let redGradient = LinearGradient(
        colors: [redDark, red],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Accent gradient: yellow-gold sweep (used for badges, highlights)
    static let yellowGradient = LinearGradient(
        colors: [yellow, Color(red: 255/255, green: 200/255, blue: 10/255)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Dark gradient for full-bleed banners
    static let darkGradient = LinearGradient(
        colors: [black, Color(red: 40/255, green: 8/255, blue: 12/255)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Legacy aliases (keeps all existing call sites compiling)
    // These map the old navy/gold/cream/softBlue names onto the new palette
    static var navy:      Color { red }
    static var gold:      Color { yellow }
    static var cream:     Color { offWhite }
    static var softBlue:  Color { redLight }
    static var navyGradient: LinearGradient { redGradient }
    static var goldGradient: LinearGradient { yellowGradient }

    // MARK: - Shadows
    static let cardShadow = Color.black.opacity(0.10)

    // MARK: - Typography helpers
    static func largeTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 32, weight: .bold, design: .serif))
            .foregroundColor(red)
    }

    static func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .semibold, design: .default))
            .foregroundColor(red)
    }
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
                    .fill(Theme.redGradient)
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
            .foregroundColor(Theme.red)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Theme.red, lineWidth: 1.5)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(configuration.isPressed ? 0.92 : 1.0))
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
