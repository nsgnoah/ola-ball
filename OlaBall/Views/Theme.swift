import SwiftUI

/// Two palettes: the night stadium (field HUD) and paper (menus, cards, Ola's notes).
enum Theme {
    // Night: the field and its HUD
    static let background = Color(hex: "0B1220")
    static let card = Color(hex: "16203A")
    static let cardElevated = Color(hex: "1E2A4A")
    static let gold = Color(hex: "F0B429")
    static let grass = Color(hex: "2E7D4F")
    static let grassDark = Color(hex: "27693F")
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.72)
    static let good = Color(hex: "3DDC84")
    static let bad = Color(hex: "FF5C5C")
    static let firstDownYellow = Color(hex: "FFE45C")

    // Paper: menus and cards
    static let paper = Color(hex: "F4EFE4")
    static let paperCard = Color.white
    static let ink = Color(hex: "12141A")
    static let ink2 = Color(hex: "5C6169")
    static let ink3 = Color(hex: "9A9FA8")
    static let rule = Color(hex: "E3DCCD")
    static let goodInk = Color(hex: "1D8A4E")
    static let badInk = Color(hex: "C8322B")
}

extension Color {
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

/// Type system, all from faces that ship with iOS (no font files, no network):
/// Futura Condensed ExtraBold for headlines and scores, Avenir Next Condensed for labels, Avenir Next for reading.
extension Font {
    static func headline(_ size: CGFloat) -> Font { .custom("Futura-CondensedExtraBold", size: size) }
    static func score(_ size: CGFloat) -> Font { .custom("Futura-CondensedExtraBold", size: size) }
    static func condensed(_ size: CGFloat) -> Font { .custom("AvenirNextCondensed-Bold", size: size) }
    static func condensedMedium(_ size: CGFloat) -> Font { .custom("AvenirNextCondensed-DemiBold", size: size) }
    static func display(_ size: CGFloat) -> Font { .custom("Futura-CondensedExtraBold", size: size) }
    static func label(_ size: CGFloat = 13) -> Font { .custom("AvenirNextCondensed-Bold", size: size) }
    static func body(_ size: CGFloat = 17) -> Font { .custom("AvenirNext-Medium", size: size) }
    static func bodyRegular(_ size: CGFloat = 17) -> Font { .custom("AvenirNext-Regular", size: size) }
    static func bodyBold(_ size: CGFloat = 17) -> Font { .custom("AvenirNext-DemiBold", size: size) }
}

struct CardBackground: ViewModifier {
    var color: Color = Theme.card
    func body(content: Content) -> some View {
        content.background(color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

extension View {
    func card(_ color: Color = Theme.card) -> some View { modifier(CardBackground(color: color)) }

    /// A white paper card with a hairline rule and a soft shadow.
    func paperCard(padding: CGFloat = 16, radius: CGFloat = 16) -> some View {
        self.padding(padding)
            .background(Theme.paperCard, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(Theme.rule, lineWidth: 1))
            .shadow(color: .black.opacity(0.06), radius: 12, y: 6)
    }
}

/// Primary action: ink block, paper type. Secondary: paper with an ink rule.
struct InkButtonStyle: ButtonStyle {
    var fill: Color = Theme.ink
    var foreground: Color = Theme.paper
    var outlined = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline(24))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(outlined ? Theme.ink : foreground)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(outlined ? Color.clear : fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.ink, lineWidth: outlined ? 2 : 0))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

// Kept for older call sites.
struct BigButtonStyle: ButtonStyle {
    var fill: Color = Theme.gold
    var foreground: Color = Color(hex: "0B1220")
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline(22))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred(); SoundKit.shared.play(.tap, volume: 0.5) }
    static func heavy() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred(); SoundKit.shared.play(.tap, volume: 0.9) }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func failure() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
