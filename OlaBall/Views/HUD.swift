import SwiftUI

// MARK: - Type scale and sticker text

/// The app's five text sizes. Nothing else.
enum TypeScale {
    static let display: CGFloat = 50   // one word on a screen
    static let title: CGFloat = 34     // screen titles
    static let heading: CGFloat = 24   // card headings, questions
    static let button: CGFloat = 20
    static let label: CGFloat = 13
}

/// Big condensed type with a single hard "print" offset underneath. The only text shadow in the app.
struct StickerText: View {
    let text: String
    var size: CGFloat = TypeScale.title
    var color: Color = .white
    var alignment: TextAlignment = .center

    init(_ text: String, size: CGFloat = TypeScale.title, color: Color = .white, alignment: TextAlignment = .center) {
        self.text = text; self.size = size; self.color = color; self.alignment = alignment
    }

    var body: some View {
        ZStack {
            Text(text).font(.headline(size)).foregroundStyle(Theme.ink.opacity(0.3)).offset(y: max(2, size * 0.055))
            Text(text).font(.headline(size)).foregroundStyle(color)
        }
        .multilineTextAlignment(alignment)
        .lineLimit(2)
        .minimumScaleFactor(0.5)
        // Without this the box stays sized for the unwrapped, unshrunk line, and a negative nudge
        // below it drags the wrapped text up through whatever is above it.
        .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Backgrounds

/// Every screen is a Stage: the backdrop fills the whole display, the content sits in a centered
/// phone-width column. On iPhone the column is the screen; on iPad (either orientation) the set
/// dressing surrounds it instead of the app shrinking into a letterboxed window.
enum Layout {
    /// The play column: the stage the game is composed on. Unconstrained on a phone, because there
    /// the screen *is* the column. On an iPad it keeps the phone's proportions at the canvas scale,
    /// so a screen that pins its header to the top and its button to the bottom composes the same
    /// way on both, instead of stranding its middle in a half-screen of empty space. The background
    /// still bleeds to every edge behind it.
    static var column: CGFloat { UI.isPad ? 430 * UI.scale : .infinity }
    static var columnHeight: CGFloat { UI.isPad ? 852 * UI.scale : .infinity }
}

struct Stage<Background: View, Content: View>: View {
    let background: Background
    let content: () -> Content
    init(_ background: Background, @ViewBuilder content: @escaping () -> Content) {
        self.background = background
        self.content = content
    }
    var body: some View {
        ZStack {
            background
            ZStack { content() }
                .frame(maxWidth: Layout.column, maxHeight: Layout.columnHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

/// A scrolling screen that centers its content when the content is shorter than the screen,
/// and scrolls normally when it is taller. Without this an iPad shows a top-heavy column
/// above a third of a screen of dead space.
struct StageScroll<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }
    var body: some View {
        GeometryReader { geo in
            ScrollView(showsIndicators: false) {
                content().frame(minHeight: geo.size.height)
            }
        }
    }
}

/// A screen with its header pinned to the top and its buttons pinned to the bottom. The middle sits
/// centred between them, exactly where a Spacer above and below it would put it, and scrolls when
/// it doesn't fit: an iPhone SE, the largest text size, a long question with Ola's verdict under it.
/// Without this the middle pushed the header up into the status bar and the button off the screen.
/// On a phone with room to spare nothing moves. The Android port's `PinnedColumn` is the same shape.
struct PinnedColumn<Top: View, Middle: View, Bottom: View>: View {
    let spacing: CGFloat
    let top: () -> Top
    let middle: () -> Middle
    let bottom: () -> Bottom

    init(spacing: CGFloat, @ViewBuilder top: @escaping () -> Top, @ViewBuilder middle: @escaping () -> Middle, @ViewBuilder bottom: @escaping () -> Bottom) {
        self.spacing = spacing
        self.top = top
        self.middle = middle
        self.bottom = bottom
    }

    var body: some View {
        VStack(spacing: spacing) {
            top()
            GeometryReader { geo in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: spacing) {
                        Spacer(minLength: 0)
                        middle()
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, minHeight: geo.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
                // Clip where the middle slides under the header and the buttons, but not at the
                // sides, where a shaking wrong answer and a winner's gold outline overhang the column.
                .scrollClipDisabled()
                .clipShape(ClipAboveAndBelow())
            }
            bottom()
        }
    }
}

extension PinnedColumn where Top == EmptyView {
    init(spacing: CGFloat, @ViewBuilder middle: @escaping () -> Middle, @ViewBuilder bottom: @escaping () -> Bottom) {
        self.init(spacing: spacing, top: { EmptyView() }, middle: middle, bottom: bottom)
    }
}

private struct ClipAboveAndBelow: Shape {
    func path(in rect: CGRect) -> Path { Path(rect.insetBy(dx: -rect.width, dy: 0)) }
}


/// Game-show backdrop: a solid color, sunburst rays turning slowly from above the top edge,
/// a halftone dot band rising from the bottom, paper grain over everything.
struct GameBackground: View {
    var top: Color
    var bottom: Color
    @State private var spin = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(world: World) {
        top = world == .his ? Theme.his : Theme.hers
        bottom = world == .his ? Theme.hisDeep : Theme.hersDeep
    }

    init(top: Color, bottom: Color) { self.top = top; self.bottom = bottom }

    /// Full-bleed color is pulled toward night so a whole screen of it reads as a stage, not a highlighter.
    private var base: Color { top.mix(with: Theme.night, by: 0.34) }

    var body: some View {
        ZStack {
            base
            Sunburst()
                .fill(.white.opacity(0.07))
                .rotationEffect(.degrees(spin ? 360 : 0), anchor: UnitPoint(x: 0.5, y: -0.08))
                .onAppear { if !reduceMotion { withAnimation(.linear(duration: 90).repeatForever(autoreverses: false)) { spin = true } } }
            Halftone().fill(Theme.nightDeep.opacity(0.28))
            Image(uiImage: Grain.image).resizable(resizingMode: .tile).opacity(0.12).blendMode(.overlay)
            RadialGradient(colors: [.clear, Theme.nightDeep.opacity(0.45)], center: .center, startRadius: 160, endRadius: 640)
        }
        .ignoresSafeArea()
    }
}

struct Sunburst: Shape {
    var rays = 18
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.minY - rect.height * 0.08)
        let radius = rect.height * 2.4
        let n = rays * 2
        let a = 2 * Double.pi / Double(n)
        for i in stride(from: 0, to: n, by: 2) {
            let a0 = Double(i) * a, a1 = a0 + a
            p.move(to: c)
            p.addLine(to: CGPoint(x: c.x + radius * cos(a0), y: c.y + radius * sin(a0)))
            p.addLine(to: CGPoint(x: c.x + radius * cos(a1), y: c.y + radius * sin(a1)))
            p.closeSubpath()
        }
        return p
    }
}

struct Halftone: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let spacing: CGFloat = 13
        let startY = rect.height * 0.58
        var y = startY
        var row = 0
        while y < rect.maxY + spacing {
            let t = (y - startY) / max(1, rect.maxY - startY)
            let r = 0.5 + 4.6 * t * t
            var x: CGFloat = row % 2 == 0 ? 0 : spacing / 2
            while x < rect.maxX + spacing {
                p.addEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
                x += spacing
            }
            y += spacing * 0.87
            row += 1
        }
        return p
    }
}

/// Paper grain, generated once and tiled.
enum Grain {
    static let image: UIImage = {
        let n = 96
        var rng = SeededRNG(seed: 99)
        return UIGraphicsImageRenderer(size: CGSize(width: n, height: n)).image { ctx in
            for y in 0..<n {
                for x in 0..<n where Int.random(in: 0..<3, using: &rng) == 0 {
                    let white = Float.random(in: 0..<1, using: &rng) > 0.5
                    ctx.cgContext.setFillColor(UIColor(white: white ? 1 : 0, alpha: CGFloat(Float.random(in: 0.25...1, using: &rng))).cgColor)
                    ctx.cgContext.fill(CGRect(x: x, y: y, width: 1, height: 1))
                }
            }
        }
    }()
}

// MARK: - Small pieces

/// Small caps label. Used for section titles and one-line context, nothing else.
struct Kicker: View {
    let text: String
    var color: Color = .white.opacity(0.85)
    var size: CGFloat = TypeScale.label
    /// Only the default white kickers get the lift. They sit on whatever deck colour the round
    /// happens to be, where a tight ink shadow keeps them readable on the pale ones. A kicker given
    /// its own colour is on a light panel, where the same shadow just smudges the letters.
    private let lifted: Bool

    init(_ text: String, color: Color? = nil, size: CGFloat = TypeScale.label) {
        self.text = text
        self.color = color ?? .white.opacity(0.85)
        self.size = size
        self.lifted = color == nil
    }

    var body: some View {
        Text(text).font(.label(size)).tracking(1.1).textCase(.uppercase).foregroundStyle(color)
            .shadow(color: lifted ? Theme.ink.opacity(0.45) : .clear, radius: 1, y: 1)
    }
}

struct WorldTag: View {
    let world: World
    var body: some View {
        Text(world.title.uppercased())
            .font(.label(11)).tracking(0.8)
            .foregroundStyle(.white)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(world.color, in: Capsule())
    }
}

/// A player's avatar: initial on a world-colored disc with a white rim.
struct Avatar: View {
    let name: String
    let world: World
    var size: CGFloat = 40

    var body: some View {
        let size = UI.s(self.size)
        ZStack {
            Circle().fill(world.color.mix(with: .black, by: 0.25)).offset(y: size * 0.06)
            Circle().fill(world.color)
            Circle().stroke(.white, lineWidth: max(2, size * 0.06))
            Text(String(name.prefix(1)).uppercased())
                .font(.logo(size * 0.58))
                .foregroundStyle(.white)
                .offset(y: size * 0.02)
        }
        .frame(width: size, height: size)
    }
}

struct Crowns: View {
    let count: Int
    var color: Color = Theme.gold
    var size: CGFloat = 16
    var empty: Color = Theme.ink.opacity(0.18)
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<MatchState.roundsToWin, id: \.self) { i in
                CrownIcon(filled: i < count, size: size + 4, empty: empty)
            }
        }
    }
}

/// Ola, the host: a brass disc with her initial.
struct OlaBadge: View {
    var size: CGFloat = 28
    var body: some View {
        let size = UI.s(self.size)
        ZStack {
            Circle().fill(Theme.goldDeep).offset(y: size * 0.07)
            Circle().fill(Theme.gold)
            Circle().stroke(Theme.goldDeep, lineWidth: max(1, size * 0.06)).padding(size * 0.12)
            Text("O").font(.logo(size * 0.56)).foregroundStyle(Theme.ink).offset(y: size * 0.02)
        }
        .frame(width: size, height: size)
    }
}

/// Speech bubble from Ola, with a tail.
struct OlaSays: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            OlaBadge(size: 30)
            Text(text).font(.body(15)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background(Theme.cream, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(alignment: .topLeading) {
                    Triangle().fill(Theme.cream).frame(width: 12, height: 10).rotationEffect(.degrees(-90)).offset(x: -9, y: 10)
                }
        }
    }
}

// MARK: - Mascots

/// Every deck has a little character: a soft body in the deck's color, big eyes, feet, and the deck's icon
/// pinned like a badge. Moods change the eyes and mouth. Idles with a slow breath, blinks, glances around.
struct Mascot: View {
    enum Mood { case idle, happy, sad, think }
    let deck: Deck
    var mood: Mood = .idle
    var size: CGFloat = 120

    @State private var breathe = false
    @State private var blink = false
    @State private var glance: CGFloat = 0
    /// The blink and glance timers reschedule themselves; without this they outlive the view.
    @State private var alive = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let size = UI.s(self.size)
        let body = deck.color
        let dark = body.mix(with: .black, by: 0.3)
        let light = body.mix(with: .white, by: 0.28)
        ZStack {
            // Ground shadow
            Ellipse().fill(.black.opacity(0.16)).frame(width: size * 0.62, height: size * 0.11).offset(y: size * 0.56)
            // Feet
            HStack(spacing: size * 0.14) {
                Capsule().fill(dark).frame(width: size * 0.2, height: size * 0.1)
                Capsule().fill(dark).frame(width: size * 0.2, height: size * 0.1)
            }
            .offset(y: size * 0.47)
            // Body
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.36, style: .continuous)
                    .fill(LinearGradient(colors: [light, body, dark], startPoint: .top, endPoint: .bottom))
                RoundedRectangle(cornerRadius: size * 0.36, style: .continuous)
                    .strokeBorder(.white.opacity(0.35), lineWidth: max(1.5, size * 0.02))
                    .mask(LinearGradient(colors: [.white, .clear], startPoint: .top, endPoint: .center))
                face(dark: dark)
                // Icon badge, pinned bottom-right
                ZStack {
                    Circle().fill(.white)
                    DeckIcon(deck: deck, fill: .white, ink: dark).padding(size * 0.035)
                }
                .frame(width: size * 0.28, height: size * 0.28)
                .overlay(Circle().stroke(dark.opacity(0.2), lineWidth: 1))
                .offset(x: size * 0.28, y: size * 0.28)
            }
            .frame(width: size * 0.82, height: size * 0.86)
            .scaleEffect(x: breathe ? 1.02 : 1, y: breathe ? 0.98 : 1.0, anchor: .bottom)
            .rotationEffect(.degrees(mood == .sad ? -3 : 0))
            .offset(y: mood == .happy && breathe ? -size * 0.06 : 0)
        }
        .frame(width: size, height: size * 1.15)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: mood == .happy ? 0.3 : 1.6).repeatForever(autoreverses: true)) { breathe = true }
            alive = true
            scheduleBlink()
            scheduleGlance()
        }
        .onDisappear { alive = false }
    }

    private func face(dark: Color) -> some View {
        VStack(spacing: size * 0.04) {
            HStack(spacing: size * 0.1) {
                eye()
                eye()
            }
            mouth(dark: dark)
        }
        .offset(y: -size * 0.06)
    }

    private func eye() -> some View {
        ZStack {
            Circle().fill(.white).frame(width: size * 0.2, height: size * 0.2)
            Circle().fill(Theme.ink).frame(width: size * 0.095)
                .offset(x: glance * size * 0.03 + (mood == .think ? size * 0.03 : 0), y: mood == .think ? -size * 0.025 : size * 0.01)
            Circle().fill(.white).frame(width: size * 0.035)
                .offset(x: -size * 0.02 + glance * size * 0.03, y: -size * 0.025)
        }
        .scaleEffect(y: blink ? 0.1 : (mood == .happy ? 0.45 : 1))
        .overlay(alignment: .top) {
            if mood == .sad {
                Capsule().fill(Theme.ink.opacity(0.85)).frame(width: size * 0.16, height: size * 0.03)
                    .rotationEffect(.degrees(12)).offset(y: -size * 0.04)
            }
        }
    }

    @ViewBuilder
    private func mouth(dark: Color) -> some View {
        switch mood {
        case .happy:
            Path { p in p.addArc(center: CGPoint(x: size * 0.11, y: 0), radius: size * 0.11, startAngle: .degrees(10), endAngle: .degrees(170), clockwise: false) }
                .fill(Theme.ink.opacity(0.85))
                .frame(width: size * 0.22, height: size * 0.12)
        case .sad:
            Path { p in p.addArc(center: CGPoint(x: size * 0.08, y: size * 0.09), radius: size * 0.08, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false) }
                .stroke(Theme.ink.opacity(0.85), style: StrokeStyle(lineWidth: max(2, size * 0.03), lineCap: .round))
                .frame(width: size * 0.16, height: size * 0.1)
        case .think:
            Capsule().fill(Theme.ink.opacity(0.85)).frame(width: size * 0.09, height: max(2, size * 0.03)).offset(x: size * 0.04)
        case .idle:
            Path { p in p.addArc(center: CGPoint(x: size * 0.08, y: 0), radius: size * 0.08, startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false) }
                .stroke(Theme.ink.opacity(0.85), style: StrokeStyle(lineWidth: max(2, size * 0.03), lineCap: .round))
                .frame(width: size * 0.16, height: size * 0.08)
        }
    }

    private func scheduleBlink() {
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Int.random(in: 2...5))) {
            guard alive else { return }
            withAnimation(.easeInOut(duration: 0.07)) { blink = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                guard alive else { return }
                withAnimation(.easeInOut(duration: 0.07)) { blink = false }
                scheduleBlink()
            }
        }
    }

    private func scheduleGlance() {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int.random(in: 1500...3800))) {
            guard alive else { return }
            withAnimation(.spring(duration: 0.4)) { glance = CGFloat([-1, 0, 1, 0].randomElement()!) }
            scheduleGlance()
        }
    }
}

/// Deck tile: color block with the mascot and the name.
struct DeckTile: View {
    let deck: Deck
    var compact = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(deck.color.mix(with: .black, by: 0.3)).offset(y: 5)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(colors: [deck.color.mix(with: .white, by: 0.1), deck.color], startPoint: .top, endPoint: .bottom))
            Mascot(deck: deck, size: compact ? 56 : 84)
                .frame(maxWidth: .infinity, alignment: .topTrailing)
                .padding(.trailing, 10).padding(.top, compact ? 4 : 8)
                .frame(maxHeight: .infinity, alignment: .top)
            VStack(alignment: .leading, spacing: 2) {
                StickerText(deck.title.uppercased(), size: compact ? 18 : 22, alignment: .leading)
                if !compact {
                    Text(deck.tagline).font(.bodyRegular(11)).foregroundStyle(.white.opacity(0.85)).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
        }
        .frame(height: compact ? 100 : 156)
    }
}

// MARK: - Timer ring and confetti

struct TimerRing: View {
    let start: Date
    let duration: Double
    var size: CGFloat = 56
    var color: Color = Theme.gold

    var body: some View {
        let size = UI.s(self.size)
        TimelineView(.animation(minimumInterval: 0.05)) { ctx in
            let elapsed = ctx.date.timeIntervalSince(start)
            let fraction = max(0, min(1, 1 - elapsed / duration))
            let left = max(0, Int(ceil(duration - elapsed)))
            ZStack {
                Circle().fill(.white)
                Circle().stroke(Theme.panelEdge, lineWidth: size * 0.1).padding(size * 0.08)
                Circle().trim(from: 0, to: fraction)
                    .stroke(fraction < 0.25 ? Theme.bad : color, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(size * 0.08)
                Text("\(left)").font(.artScore(size * 0.4)).foregroundStyle(Theme.ink)
            }
            .frame(width: size, height: size)
            .background(Circle().fill(Theme.panelEdge).offset(y: 3))
        }
    }
}

struct ConfettiBurst: View {
    private struct Particle { let angle: Double, speed: Double, size: CGFloat, hue: Double, spin: Double, delay: Double }
    private let particles: [Particle] = (0..<80).map { _ in
        Particle(angle: .random(in: 0...(2 * .pi)), speed: .random(in: 180...420), size: .random(in: 6...12), hue: .random(in: 0...1), spin: .random(in: -6...6), delay: .random(in: 0...0.15))
    }
    private let start = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion { EmptyView() } else { burst }
    }

    private var burst: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSince(start)
                let origin = CGPoint(x: size.width / 2, y: size.height * 0.4)
                for p in particles {
                    let life = t - p.delay
                    guard life > 0, life < 1.8 else { continue }
                    let x = origin.x + cos(p.angle) * p.speed * life * 0.7
                    let y = origin.y + sin(p.angle) * p.speed * life * 0.5 + 260 * life * life
                    let alpha = max(0, 1 - life / 1.8)
                    var rect = CGRect(x: x, y: y, width: p.size, height: p.size * 0.6)
                    rect = rect.offsetBy(dx: -p.size / 2, dy: -p.size / 2)
                    var c = ctx
                    c.translateBy(x: x, y: y)
                    c.rotate(by: .radians(p.spin * life))
                    c.translateBy(x: -x, y: -y)
                    c.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(Color(hue: p.hue, saturation: 0.85, brightness: 1).opacity(alpha)))
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

/// Shake modifier for wrong answers.
struct Shake: GeometryEffect {
    var amount: CGFloat = 10
    var shakes: CGFloat = 4
    var animatableData: CGFloat
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(animatableData * .pi * shakes), y: 0))
    }
}

/// The logo: two stacked world chips with a VS badge on the seam.
struct Wordmark: View {
    var scale: CGFloat = 1
    /// Geometry and lettering share this, so the chips grow with the words inside them.
    private var k: CGFloat { scale * UI.scale }

    var body: some View {
        ZStack {
            VStack(spacing: 8 * k) {
                chip("HIS WORLD", Theme.his)
                chip("HER WORLD", Theme.hers)
            }
            ZStack {
                Circle().fill(Theme.goldDeep).offset(y: 3 * k)
                Circle().fill(Theme.gold)
                Circle().stroke(Theme.ink, lineWidth: 3 * k)
                Text("VS").font(.logo(18 * k)).foregroundStyle(Theme.ink)
            }
            .frame(width: 48 * k, height: 48 * k)
            .rotationEffect(.degrees(-8))
        }
    }

    private func chip(_ text: String, _ color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18 * k, style: .continuous).fill(color.mix(with: .black, by: 0.3)).offset(y: 6 * k)
            RoundedRectangle(cornerRadius: 18 * k, style: .continuous).fill(color)
            RoundedRectangle(cornerRadius: 18 * k, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.18), .clear], startPoint: .top, endPoint: .center))
            RoundedRectangle(cornerRadius: 18 * k, style: .continuous).stroke(Theme.ink, lineWidth: 3 * k)
            Text(text).font(.logo(36 * k)).foregroundStyle(.white)
        }
        .frame(width: 270 * k, height: 66 * k)
    }
}

enum Art {
    static func lighter(_ c: Color, _ amount: CGFloat) -> Color { c.mix(with: .white, by: Double(amount)) }
    static func darker(_ c: Color, _ amount: CGFloat) -> Color { c.mix(with: .black, by: Double(amount)) }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}
