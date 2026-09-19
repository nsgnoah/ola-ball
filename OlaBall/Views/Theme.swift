import SwiftUI

enum Theme {
    static let background = Color(hex: "0B1220")
    static let card = Color(hex: "16203A")
    static let cardElevated = Color(hex: "1E2A4A")
    static let gold = Color(hex: "F5C542")
    static let grass = Color(hex: "2E7D4F")
    static let grassDark = Color(hex: "27693F")
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.72)
    static let good = Color(hex: "3DDC84")
    static let bad = Color(hex: "FF5C5C")
    static let firstDownYellow = Color(hex: "FFE45C")
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

extension Font {
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func label(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static func body(_ size: CGFloat = 17) -> Font { .system(size: size, weight: .medium, design: .rounded) }
}

struct CardBackground: ViewModifier {
    var color: Color = Theme.card
    func body(content: Content) -> some View {
        content
            .background(color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

extension View {
    func card(_ color: Color = Theme.card) -> some View { modifier(CardBackground(color: color)) }
}

struct BigButtonStyle: ButtonStyle {
    var fill: Color = Theme.gold
    var foreground: Color = Color(hex: "0B1220")
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.display(19))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(fill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred(); SoundKit.shared.play(.tap, volume: 0.5) }
    static func heavy() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred(); SoundKit.shared.play(.tap, volume: 0.9) }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func failure() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
}
