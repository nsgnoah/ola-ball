import SwiftUI

// MARK: - Backgrounds

/// Saturated world-colored background with a diagonal stripe pattern and a soft vignette.
struct GameBackground: View {
    var top: Color
    var bottom: Color

    init(world: World) {
        top = world == .his ? Theme.his : Theme.hers
        bottom = world == .his ? Theme.hisDeep : Theme.hersDeep
    }

    init(top: Color, bottom: Color) { self.top = top; self.bottom = bottom }

    var body: some View {
        ZStack {
            LinearGradient(colors: [top, bottom], startPoint: .top, endPoint: .bottom)
            Stripes().fill(.white.opacity(0.06))
            RadialGradient(colors: [.white.opacity(0.18), .clear], center: .top, startRadius: 0, endRadius: 420)
        }
        .ignoresSafeArea()
    }
}

struct Stripes: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let step: CGFloat = 46
        var x: CGFloat = -rect.height
        while x < rect.width + rect.height {
            p.move(to: CGPoint(x: x, y: rect.maxY))
            p.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            p.addLine(to: CGPoint(x: x + rect.height + step / 2, y: rect.minY))
            p.addLine(to: CGPoint(x: x + step / 2, y: rect.maxY))
            p.closeSubpath()
            x += step
        }
        return p
    }
}

// MARK: - Small pieces

struct Kicker: View {
    let text: String
    var color: Color = .white.opacity(0.8)
    var size: CGFloat = 13

    init(_ text: String, color: Color = .white.opacity(0.8), size: CGFloat = 13) {
        self.text = text; self.color = color; self.size = size
    }

    var body: some View {
        Text(text).font(.label(size)).tracking(1.2).textCase(.uppercase).foregroundStyle(color)
    }
}

struct WorldTag: View {
    let world: World
    var body: some View {
        Text(world.title.uppercased())
            .font(.label(11)).tracking(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(world.color, in: Capsule())
    }
}

/// A player's avatar: initial on a world-colored disc with a white rim.
struct Avatar: View {
    let name: String
    let world: World
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle().fill(world.color.mix(with: .black, by: 0.25)).offset(y: size * 0.06)
            Circle().fill(world.color)
            Circle().stroke(.white, lineWidth: max(2, size * 0.06))
            Text(String(name.prefix(1)).uppercased())
                .font(.headline(size * 0.58))
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
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<MatchState.roundsToWin, id: \.self) { i in
                Image(systemName: i < count ? "crown.fill" : "crown")
                    .font(.system(size: size, weight: .black))
                    .foregroundStyle(i < count ? Theme.gold : .white.opacity(0.45))
                    .shadow(color: i < count ? Theme.goldDeep.opacity(0.6) : .clear, radius: 0, y: 1.5)
            }
        }
    }
}

/// Ola, the host: a gold disc with a headset.
struct OlaBadge: View {
    var size: CGFloat = 28
    var body: some View {
        ZStack {
            Circle().fill(Theme.goldDeep).offset(y: size * 0.07)
            Circle().fill(Theme.gold)
            Image(systemName: "headphones").font(.system(size: size * 0.5, weight: .black)).foregroundStyle(Theme.ink)
        }
        .frame(width: size, height: size)
    }
}

/// Speech bubble from Ola.
struct OlaSays: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            OlaBadge(size: 30)
            Text(text).font(.body(15)).foregroundStyle(Theme.ink).fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Theme.cream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

// MARK: - Mascots

/// Every deck has a little character. Simple shapes, a face, and moods, in the deck's color.
struct Mascot: View {
    enum Mood { case idle, happy, sad, think }
    let deck: Deck
    var mood: Mood = .idle
    var size: CGFloat = 120

    @State private var bob = false
    @State private var blink = false
    @State private var glance: CGFloat = 0

    var body: some View {
        let body = deck.color
        let dark = body.mix(with: .black, by: 0.28)
        let light = body.mix(with: .white, by: 0.35)
        ZStack {
            // Shadow on the ground
            Ellipse().fill(.black.opacity(0.18)).frame(width: size * 0.7, height: size * 0.14).offset(y: size * 0.52)
            VStack(spacing: 0) {
                ZStack {
                    // Body blob
                    RoundedRectangle(cornerRadius: size * 0.34, style: .continuous)
                        .fill(LinearGradient(colors: [light, body, dark], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: size * 0.82, height: size * 0.9)
                    // Belly
                    Ellipse().fill(.white.opacity(0.22)).frame(width: size * 0.5, height: size * 0.36).offset(y: size * 0.22)
                    // Accessory badge on the belly
                    Image(systemName: deck.symbol)
                        .font(.system(size: size * 0.16, weight: .black))
                        .foregroundStyle(dark)
                        .offset(y: size * 0.24)
                    // Eyes
                    HStack(spacing: size * 0.14) {
                        eye(dark: dark)
                        eye(dark: dark)
                    }
                    .offset(y: -size * 0.14 + (mood == .happy ? -size * 0.02 : 0))
                    // Brows for moods
                    if mood == .sad || mood == .think {
                        HStack(spacing: size * 0.16) {
                            Capsule().fill(dark).frame(width: size * 0.16, height: size * 0.035).rotationEffect(.degrees(mood == .sad ? 18 : -10))
                            Capsule().fill(dark).frame(width: size * 0.16, height: size * 0.035).rotationEffect(.degrees(mood == .sad ? -18 : 6))
                        }
                        .offset(y: -size * 0.3)
                    }
                    // Mouth
                    mouth(dark: dark).offset(y: size * 0.02)
                    // Blush when happy
                    if mood == .happy {
                        HStack(spacing: size * 0.34) {
                            Circle().fill(Theme.hers.opacity(0.45)).frame(width: size * 0.12)
                            Circle().fill(Theme.hers.opacity(0.45)).frame(width: size * 0.12)
                        }
                        .offset(y: -size * 0.02)
                    }
                }
                .scaleEffect(y: mood == .happy ? 1.04 : 1)
                .rotationEffect(.degrees(mood == .sad ? -4 : 0))
            }
            .offset(y: bob ? -size * 0.05 : size * 0.02)
        }
        .frame(width: size, height: size * 1.15)
        .onAppear {
            withAnimation(.easeInOut(duration: mood == .happy ? 0.35 : 1.3).repeatForever(autoreverses: true)) { bob = true }
            scheduleBlink()
            scheduleGlance()
        }
    }

    private func eye(dark: Color) -> some View {
        ZStack {
            Ellipse().fill(.white).frame(width: size * 0.2, height: size * 0.24)
            Circle().fill(Theme.ink).frame(width: size * 0.1).offset(x: glance * size * 0.03, y: size * 0.02)
            Circle().fill(.white).frame(width: size * 0.035).offset(x: -size * 0.02 + glance * size * 0.03, y: -size * 0.02)
        }
        .scaleEffect(y: blink ? 0.08 : (mood == .happy ? 0.55 : 1), anchor: .center)
        .overlay {
            if mood == .happy {
                Capsule().fill(dark).frame(width: size * 0.2, height: size * 0.04).offset(y: -size * 0.04)
            }
        }
    }

    @ViewBuilder
    private func mouth(dark: Color) -> some View {
        switch mood {
        case .happy:
            Path { p in
                p.addArc(center: .zero, radius: size * 0.13, startAngle: .degrees(10), endAngle: .degrees(170), clockwise: false)
            }
            .fill(dark)
            .frame(width: size * 0.3, height: size * 0.15)
            .offset(y: size * 0.04)
        case .sad:
            Path { p in
                p.addArc(center: .zero, radius: size * 0.09, startAngle: .degrees(200), endAngle: .degrees(340), clockwise: false)
            }
            .stroke(dark, style: StrokeStyle(lineWidth: size * 0.035, lineCap: .round))
            .frame(width: size * 0.2, height: size * 0.1)
            .offset(y: size * 0.14)
        case .think:
            Capsule().fill(dark).frame(width: size * 0.1, height: size * 0.035).offset(x: size * 0.05, y: size * 0.08)
        case .idle:
            Path { p in
                p.addArc(center: .zero, radius: size * 0.1, startAngle: .degrees(20), endAngle: .degrees(160), clockwise: false)
            }
            .stroke(dark, style: StrokeStyle(lineWidth: size * 0.035, lineCap: .round))
            .frame(width: size * 0.2, height: size * 0.1)
            .offset(y: size * 0.06)
        }
    }

    private func scheduleBlink() {
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(Int.random(in: 2...5))) {
            withAnimation(.easeInOut(duration: 0.08)) { blink = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.easeInOut(duration: 0.08)) { blink = false }
                scheduleBlink()
            }
        }
    }

    private func scheduleGlance() {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(Int.random(in: 1200...3500))) {
            withAnimation(.spring(duration: 0.4)) { glance = CGFloat([-1, 0, 1, 0].randomElement()!) }
            scheduleGlance()
        }
    }
}

/// Deck tile: color block with the mascot peeking and the name.
struct DeckTile: View {
    let deck: Deck
    var compact = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(deck.color.mix(with: .black, by: 0.3)).offset(y: 6)
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(colors: [deck.color.mix(with: .white, by: 0.12), deck.color], startPoint: .top, endPoint: .bottom))
            Stripes().fill(.white.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            Mascot(deck: deck, size: compact ? 56 : 84)
                .frame(maxWidth: .infinity, alignment: .topTrailing)
                .padding(.trailing, 8).padding(.top, compact ? 4 : 10)
                .frame(maxHeight: .infinity, alignment: .top)
            VStack(alignment: .leading, spacing: 2) {
                Text(deck.title.uppercased()).font(.headline(compact ? 18 : 22)).foregroundStyle(.white).lineLimit(2).minimumScaleFactor(0.7)
                    .shadow(color: .black.opacity(0.25), radius: 0, y: 1.5)
                if !compact {
                    Text(deck.tagline).font(.bodyRegular(11)).foregroundStyle(.white.opacity(0.85)).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
        }
        .frame(height: compact ? 100 : 156)
    }
}

// MARK: - Timer ring and confetti

struct TimerRing: View {
    let start: Date
    let duration: Double
    var size: CGFloat = 64
    var color: Color = Theme.gold

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { ctx in
            let elapsed = ctx.date.timeIntervalSince(start)
            let fraction = max(0, min(1, 1 - elapsed / duration))
            let left = max(0, Int(ceil(duration - elapsed)))
            ZStack {
                Circle().stroke(.white.opacity(0.25), lineWidth: size * 0.12)
                Circle().trim(from: 0, to: fraction)
                    .stroke(fraction < 0.25 ? Theme.bad : color, style: StrokeStyle(lineWidth: size * 0.12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(left)").font(.score(size * 0.42)).foregroundStyle(.white)
            }
            .frame(width: size, height: size)
        }
    }
}

struct ConfettiBurst: View {
    private struct Particle { let angle: Double, speed: Double, size: CGFloat, hue: Double, spin: Double, delay: Double }
    private let particles: [Particle] = (0..<80).map { _ in
        Particle(angle: .random(in: 0...(2 * .pi)), speed: .random(in: 180...420), size: .random(in: 6...12), hue: .random(in: 0...1), spin: .random(in: -6...6), delay: .random(in: 0...0.15))
    }
    private let start = Date()

    var body: some View {
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

enum Art {
    static func lighter(_ c: Color, _ amount: CGFloat) -> Color { c.mix(with: .white, by: Double(amount)) }
    static func darker(_ c: Color, _ amount: CGFloat) -> Color { c.mix(with: .black, by: Double(amount)) }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}
