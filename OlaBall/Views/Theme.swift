import SwiftUI

/// Game-show palette: saturated primaries, cream paper, navy ink, brass gold.
enum Theme {
    static let his = Color(hex: "2F56BF")
    static let hisDeep = Color(hex: "1A3579")
    static let hers = Color(hex: "D6406F")
    static let hersDeep = Color(hex: "962352")
    static let night = Color(hex: "1A1B4B")
    static let nightDeep = Color(hex: "0E0F2E")
    static let violet = Color(hex: "4F3DB0")
    static let violetDeep = Color(hex: "33267A")
    static let gold = Color(hex: "EDB240")
    static let goldDeep = Color(hex: "B97F0C")
    static let good = Color(hex: "2AA35C")
    static let goodDeep = Color(hex: "157A3D")
    static let bad = Color(hex: "D9463F")
    static let badDeep = Color(hex: "B0271F")
    static let ink = Color(hex: "1D1A33")
    static let ink2 = Color(hex: "5A5670")
    static let ink3 = Color(hex: "9793A8")
    static let panel = Color(hex: "FFFBF1")
    static let panelEdge = Color(hex: "E0D2B4")
    static let cream = Color(hex: "FFF3D9")

    // Kept for old call sites.
    static let paper = Color(hex: "F4EFE4")
    static let paperCard = Color(hex: "FFFBF1")
    static let rule = Color(hex: "E3DCCD")
    static let goodInk = Color(hex: "157A3D")
    static let badInk = Color(hex: "B0271F")
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

/// Type: Rockwell (slab serif) for anything loud or read, DIN Condensed for scoreboard numbers and labels.
/// Both ship with iOS; nothing is bundled or downloaded.
extension Font {
    // `relativeTo` lets the phone's text-size setting scale everything (capped at xxLarge in RootView);
    // the floors keep reading text legible for older eyes even where a layout asked for something tiny.
    static func headline(_ size: CGFloat) -> Font { .custom("Rockwell-Bold", size: size, relativeTo: .headline) }
    static func score(_ size: CGFloat) -> Font { .custom("DINCondensed-Bold", size: size * 1.12, relativeTo: .title) }
    static func condensed(_ size: CGFloat) -> Font { .custom("DINCondensed-Bold", size: size * 1.15, relativeTo: .headline) }
    static func display(_ size: CGFloat) -> Font { .custom("Rockwell-Bold", size: size, relativeTo: .largeTitle) }
    static func label(_ size: CGFloat = 13) -> Font { .custom("DINCondensed-Bold", size: max(size, 12) * 1.15, relativeTo: .caption) }
    static func body(_ size: CGFloat = 17) -> Font { .custom("Rockwell", size: max(size, 15), relativeTo: .body) }
    static func bodyRegular(_ size: CGFloat = 17) -> Font { .custom("Rockwell", size: max(size, 14), relativeTo: .body) }
    static func bodyBold(_ size: CGFloat = 17) -> Font { .custom("Rockwell-Bold", size: max(size, 15), relativeTo: .body) }
    /// Logo type: the wordmark and other fixed-frame art must not scale with the text-size setting.
    static func logo(_ size: CGFloat) -> Font { .custom("Rockwell-Bold", fixedSize: size) }
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
