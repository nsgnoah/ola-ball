import SwiftUI

/// Shared paper-and-ink pieces.

struct Kicker: View {
    let text: String
    var color: Color = Theme.ink3
    var size: CGFloat = 12

    init(_ text: String, color: Color = Theme.ink3, size: CGFloat = 12) {
        self.text = text; self.color = color; self.size = size
    }

    var body: some View {
        Text(text).font(.condensed(size)).tracking(size * 0.16).textCase(.uppercase).foregroundStyle(color)
    }
}

/// A small pill that names a world.
struct WorldTag: View {
    let world: World
    var body: some View {
        Text(world.title.uppercased())
            .font(.condensed(11)).tracking(1.5)
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(world.color, in: Capsule())
    }
}

/// A player's avatar: initial on a world-colored disc.
struct Avatar: View {
    let name: String
    let world: World
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [world.color.opacity(0.95), world.color.opacity(0.7)], startPoint: .top, endPoint: .bottom))
            Circle().stroke(.white.opacity(0.4), lineWidth: max(1, size * 0.03))
            Text(String(name.prefix(1)).uppercased())
                .font(.headline(size * 0.55))
                .foregroundStyle(.white)
                .offset(y: size * 0.02)
        }
        .frame(width: size, height: size)
    }
}

/// A crown row: filled for rounds won.
struct Crowns: View {
    let count: Int
    var color: Color = Theme.ink
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<MatchState.roundsToWin, id: \.self) { i in
                Image(systemName: i < count ? "crown.fill" : "crown")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(i < count ? color : Theme.ink3.opacity(0.5))
            }
        }
    }
}

/// Ola, the host. A gold disc with a headset.
struct OlaBadge: View {
    var size: CGFloat = 28
    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Color(hex: "FFD65C"), Theme.gold], startPoint: .top, endPoint: .bottom))
            Circle().stroke(.white.opacity(0.5), lineWidth: 1)
            Image(systemName: "headphones").font(.system(size: size * 0.5, weight: .black)).foregroundStyle(Theme.ink)
        }
        .frame(width: size, height: size)
    }
}

/// Deck tile used wherever a deck is shown.
struct DeckTile: View {
    let deck: Deck
    var compact = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [Art.lighter(deck.color, 0.06), Art.darker(deck.color, 0.16)], startPoint: .topLeading, endPoint: .bottomTrailing))
            GeometryReader { geo in
                Path { p in
                    p.move(to: CGPoint(x: geo.size.width * 0.55, y: 0))
                    p.addLine(to: CGPoint(x: geo.size.width, y: 0))
                    p.addLine(to: CGPoint(x: geo.size.width * 0.45, y: geo.size.height))
                    p.addLine(to: CGPoint(x: 0, y: geo.size.height))
                    p.closeSubpath()
                }
                .fill(.white.opacity(0.07))
            }
            VStack(alignment: .leading, spacing: 0) {
                Image(systemName: deck.symbol).font(.system(size: compact ? 18 : 24, weight: .bold)).foregroundStyle(.white.opacity(0.95))
                Spacer(minLength: 6)
                Text(deck.title.uppercased()).font(.headline(compact ? 18 : 22)).foregroundStyle(.white).lineLimit(2).minimumScaleFactor(0.7)
                if !compact {
                    Text(deck.tagline).font(.body(12)).foregroundStyle(.white.opacity(0.8)).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(compact ? 10 : 14)
        }
        .frame(height: compact ? 92 : 150)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 8, y: 5)
    }
}

enum Art {
    static func lighter(_ c: Color, _ amount: CGFloat) -> Color { shift(c, amount) }
    static func darker(_ c: Color, _ amount: CGFloat) -> Color { shift(c, -amount) }
    private static func shift(_ c: Color, _ delta: CGFloat) -> Color {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(c).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return Color(UIColor(hue: h, saturation: s, brightness: min(1, max(0, b + delta)), alpha: a))
    }
}

extension Haptics {
    static func answer(correct: Bool) {
        if correct { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        else { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}
