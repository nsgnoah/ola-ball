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

/// One dial for "how big is the surface we are drawing on". The phone layout is authored at
/// 393x852; this reports how far it can grow (or, on an iPad only, shrink) to suit the window it
/// actually got. Type, buttons, panels and drawn art all read it, so they grow together instead of
/// the phone layout stranding itself in a narrow column on a big screen.
///
/// It tracks the WINDOW, not the device: since iPadOS 26 every app gets a resizable window, so a
/// half-width iPad window has to look composed too, and a short landscape one must not overflow.
@Observable
final class Viewport {
    static let shared = Viewport()
    /// Seeded from the idiom so the very first frame is already right in the common full-screen
    /// case; `Stage` corrects it from real geometry as soon as there is any.
    var scale: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 1.3 : 1
    var isPad: Bool = UIDevice.current.userInterfaceIdiom == .pad

    static let designSize = CGSize(width: 393, height: 852)

    func fit(_ size: CGSize) {
        guard size.width > 20, size.height > 20 else { return }
        let room = min(size.width / Self.designSize.width, size.height / Self.designSize.height)
        // A phone never shrinks: the layout already fits the smallest iPhone and shrinking it
        // would undercut the reading floors. An iPad may shrink a little, because 0.95 of the
        // phone layout on an iPad is still physically larger than a phone.
        let floor: CGFloat = isPad ? 0.9 : 1
        let next = min(1.3, max(floor, room))
        if abs(next - scale) > 0.005 { scale = next }
    }
}

enum UI {
    static var scale: CGFloat { Viewport.shared.scale }
    static var isPad: Bool { Viewport.shared.isPad }
    /// Scale a hand-placed size (art, avatars, ring diameters). Fonts scale in the `Font` helpers.
    static func s(_ v: CGFloat) -> CGFloat { v * scale }
}

/// Type: Rockwell (slab serif) for anything loud or read, DIN Condensed for scoreboard numbers and labels.
/// Both ship with iOS; nothing is bundled or downloaded.
extension Font {
    // `relativeTo` lets the phone's text-size setting scale everything (capped at xxLarge in RootView);
    // the floors keep reading text legible for older eyes even where a layout asked for something tiny.
    static func headline(_ size: CGFloat) -> Font { .custom("Rockwell-Bold", size: UI.s(size), relativeTo: .headline) }
    static func score(_ size: CGFloat) -> Font { .custom("DINCondensed-Bold", size: UI.s(size * 1.12), relativeTo: .title) }
    static func condensed(_ size: CGFloat) -> Font { .custom("DINCondensed-Bold", size: UI.s(size * 1.15), relativeTo: .headline) }
    static func display(_ size: CGFloat) -> Font { .custom("Rockwell-Bold", size: UI.s(size), relativeTo: .largeTitle) }
    static func label(_ size: CGFloat = 13) -> Font { .custom("DINCondensed-Bold", size: UI.s(max(size, 12) * 1.15), relativeTo: .caption) }
    static func body(_ size: CGFloat = 17) -> Font { .custom("Rockwell", size: UI.s(max(size, 15)), relativeTo: .body) }
    static func bodyRegular(_ size: CGFloat = 17) -> Font { .custom("Rockwell", size: UI.s(max(size, 14)), relativeTo: .body) }
    static func bodyBold(_ size: CGFloat = 17) -> Font { .custom("Rockwell-Bold", size: UI.s(max(size, 15)), relativeTo: .body) }
    /// Art type: takes FINAL points and applies no canvas scale and no Dynamic Type. For lettering
    /// inside fixed-frame art (the wordmark, an avatar's initial, the timer's count), where the
    /// frame has already been scaled and scaling the text again would overflow it.
    static func logo(_ size: CGFloat) -> Font { .custom("Rockwell-Bold", fixedSize: size) }
    static func artScore(_ size: CGFloat) -> Font { .custom("DINCondensed-Bold", fixedSize: size * 1.12) }
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
            .frame(height: max(44, UI.s(height)))   // never below the 44pt minimum target
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: UI.s(16), style: .continuous).fill(edgeColor).offset(y: pressed ? UI.s(2) : UI.s(6))
                    RoundedRectangle(cornerRadius: UI.s(16), style: .continuous).fill(color)
                    RoundedRectangle(cornerRadius: UI.s(16), style: .continuous).fill(LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center))
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
        self.padding(UI.s(padding))
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: UI.s(radius), style: .continuous))
            .background(RoundedRectangle(cornerRadius: UI.s(radius), style: .continuous).fill(Theme.panelEdge).offset(y: UI.s(5)))
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
