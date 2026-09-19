import SwiftUI

/// Game palette: saturated world colors, white chunky panels, gold crowns.
enum Theme {
    static let his = Color(hex: "2F62FF")
    static let hisDeep = Color(hex: "1B3FC9")
    static let hers = Color(hex: "FF3F8E")
    static let hersDeep = Color(hex: "C4136A")
    static let night = Color(hex: "1A1B4B")
    static let nightDeep = Color(hex: "0E0F2E")
    static let violet = Color(hex: "6C3BFF")
    static let violetDeep = Color(hex: "3E1FB5")
    static let gold = Color(hex: "FFC93C")
    static let goldDeep = Color(hex: "E09A00")
    static let good = Color(hex: "22C55E")
    static let goodDeep = Color(hex: "15803D")
    static let bad = Color(hex: "FF4757")
    static let badDeep = Color(hex: "C0263A")
    static let ink = Color(hex: "1B1B2F")
    static let ink2 = Color(hex: "5B5E7A")
    static let ink3 = Color(hex: "9A9DB8")
    static let panel = Color.white
    static let panelEdge = Color(hex: "D8DAEA")
    static let cream = Color(hex: "FFF6E5")

    // Kept for old call sites.
    static let paper = Color(hex: "F4EFE4")
    static let paperCard = Color.white
    static let rule = Color(hex: "E3DCCD")
    static let goodInk = Color(hex: "15803D")
    static let badInk = Color(hex: "C0263A")
    static let background = night
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.75)
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

/// Type: Futura Condensed ExtraBold for the loud stuff, rounded system for everything you read.
extension Font {
    static func headline(_ size: CGFloat) -> Font { .custom("Futura-CondensedExtraBold", size: size) }
    static func score(_ size: CGFloat) -> Font { .custom("Futura-CondensedExtraBold", size: size) }
    static func condensed(_ size: CGFloat) -> Font { .custom("AvenirNextCondensed-Bold", size: size) }
    static func display(_ size: CGFloat) -> Font { .custom("Futura-CondensedExtraBold", size: size) }
    static func label(_ size: CGFloat = 13) -> Font { .system(size: size, weight: .heavy, design: .rounded) }
    static func body(_ size: CGFloat = 17) -> Font { .system(size: size, weight: .semibold, design: .rounded) }
    static func bodyRegular(_ size: CGFloat = 17) -> Font { .system(size: size, weight: .medium, design: .rounded) }
    static func bodyBold(_ size: CGFloat = 17) -> Font { .system(size: size, weight: .bold, design: .rounded) }
}

/// A chunky game button: solid face over a darker "edge" that compresses when pressed.
struct ChunkyButtonStyle: ButtonStyle {
    var color: Color = Theme.gold
    var edge: Color? = nil
    var ink: Color = Theme.ink
    var height: CGFloat = 56
    var fontSize: CGFloat = TypeScale.button

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        let edgeColor = edge ?? color.mix(with: .black, by: 0.3)
        return configuration.label
            .font(.headline(fontSize))
            .tracking(0.5)
            .textCase(.uppercase)
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(edgeColor).offset(y: pressed ? 2 : 6)
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(color)
                    RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center))
                }
            )
            .offset(y: pressed ? 4 : 0)
            .animation(.spring(duration: 0.15), value: pressed)
    }
}

// Old name, new look.
typealias InkButtonStyle = ChunkyButtonStyle

extension Color {
    func mix(with other: Color, by amount: Double) -> Color {
        let a = UIColor(self), b = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = CGFloat(amount)
        return Color(UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, alpha: 1))
    }
}

extension View {
    /// White chunky panel with a soft edge, the game's card.
    func panel(padding: CGFloat = 16, radius: CGFloat = 22) -> some View {
        self.padding(padding)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Theme.panelEdge).offset(y: 5))
    }

    // Old name, new look.
    func paperCard(padding: CGFloat = 16, radius: CGFloat = 22) -> some View { panel(padding: padding, radius: radius) }
}

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred(); SoundKit.shared.play(.tap, volume: 0.5) }
    static func heavy() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred(); SoundKit.shared.play(.tap, volume: 0.9) }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func failure() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func answer(correct: Bool) { correct ? success() : failure() }
    static func tick() { UISelectionFeedbackGenerator().selectionChanged() }
}
