import SwiftUI

/// The pick wheel. Spin it and fate suggests a deck; tap a slice to overrule fate.
struct WheelView: View {
    let decks: [Deck]
    let onPick: (Deck) -> Void
    var enabled: Bool = true

    @State private var rotation: Double = 0
    @State private var spinning = false
    @State private var landed: Deck?
    @State private var tickTask: Task<Void, Never>?
    private var k: CGFloat { UI.scale }   // the wheel grows with the canvas

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var sliceAngle: Double { 360 / Double(max(1, decks.count)) }

    var body: some View {
        VStack(spacing: 14) {
            ZStack(alignment: .top) {
                wheel
                    .rotationEffect(.degrees(rotation))
                // Pointer
                ZStack {
                    Triangle().fill(Theme.panelEdge).frame(width: 34, height: 30).offset(y: 3)
                    Triangle().fill(.white).frame(width: 34, height: 30)
                }
                .rotationEffect(.degrees(180))
                .offset(y: -8)
                // Hub
                ZStack {
                    Circle().fill(Theme.ink.opacity(0.35)).frame(width: 74, height: 74).offset(y: 4)
                    Circle().fill(.white).frame(width: 74, height: 74)
                    Glyph(kind: .star, size: 30 / UI.scale, color: Theme.violet)   // the whole wheel is already scaled by k
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(width: 320, height: 320)
            .scaleEffect(k)
            .frame(width: 320 * k, height: 320 * k)

            if let landed {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Mascot(deck: landed, mood: .happy, size: 54)
                        VStack(alignment: .leading, spacing: 2) {
                            Kicker("THE WHEEL SAYS", color: Theme.ink2, size: 11)
                            Text(landed.title.uppercased()).font(.headline(TypeScale.heading)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        Spacer(minLength: 0)
                    }
                    HStack(spacing: 10) {
                        Button("Spin again") { spin() }
                            .buttonStyle(ChunkyButtonStyle(color: .white, edge: Theme.panelEdge, ink: Theme.ink, height: 52, fontSize: 20))
                            .disabled(spinning || !enabled)
                        Button("Lock it in") { Haptics.heavy(); onPick(landed) }
                            .buttonStyle(ChunkyButtonStyle(color: Theme.good, ink: .white, height: 52, fontSize: 20))
                            .disabled(spinning || !enabled)
                            .accessibilityIdentifier("lock-in")
                    }
                }
                .panel(padding: 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Button {
                    spin()
                } label: {
                    HStack(spacing: 10) {
                        Glyph(kind: .spin, size: 22, color: Theme.ink, weight: 14)
                        Text("Spin the wheel")
                    }
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.gold))
                .disabled(spinning || !enabled)
                .accessibilityIdentifier("spin")
            }
        }
        .animation(.spring(duration: 0.4), value: landed?.id)
    }

    private var wheel: some View {
        ZStack {
            Circle().fill(Theme.ink.opacity(0.35)).offset(y: 8)
            Circle().fill(.white)
            ForEach(Array(decks.enumerated()), id: \.element.id) { i, deck in
                let start = Angle.degrees(Double(i) * sliceAngle - 90 - sliceAngle / 2)
                let end = Angle.degrees(Double(i + 1) * sliceAngle - 90 - sliceAngle / 2)
                Slice(start: start, end: end)
                    .fill(deck.color.mix(with: Theme.ink, by: 0.14))
                    .padding(8)
                Slice(start: start, end: end)
                    .stroke(.white, lineWidth: 4)
                    .padding(8)
                // Icon at the slice's mid-radius, tappable to choose outright.
                sliceButton(deck, index: i)
            }
            Circle().stroke(.white, lineWidth: 8).padding(4)
        }
    }

    private func sliceButton(_ deck: Deck, index i: Int) -> some View {
        let mid: Double = Double(i) * sliceAngle - 90
        let r: CGFloat = 108
        let dx: CGFloat = r * CGFloat(cos(mid * .pi / 180))
        let dy: CGFloat = r * CGFloat(sin(mid * .pi / 180))
        return Button {
            guard enabled, !spinning else { return }
            Haptics.heavy()
            onPick(deck)
        } label: {
            DeckIcon(deck: deck, fill: .white, ink: Art.darker(deck.color, 0.45))
                .frame(width: 40, height: 40)
                .frame(width: 64, height: 64)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("deck-\(deck.id)")
        .accessibilityLabel(deck.title)
        .rotationEffect(.degrees(-rotation))   // counter-rotate the icon about its own center so it stays upright
        .offset(x: dx, y: dy)
    }

    private func spin() {
        guard !spinning, !decks.isEmpty else { return }
        spinning = true
        landed = nil
        Haptics.heavy()
        let target = Int.random(in: 0..<decks.count)
        // Land the target slice under the pointer at the top: slice i is centered at i*slice degrees clockwise from the top,
        // so rotating the wheel by -(i*slice) brings it up. Add whole turns for drama and a little wobble.
        // Reduce Motion turns the spin into a decision, not a ride: the wheel steps straight to the
        // slice it picked. This is the largest movement in the app, so honouring the setting matters.
        let turns = reduceMotion ? 0 : Double(Int.random(in: 4...6))
        let wobble = reduceMotion ? 0 : Double.random(in: -sliceAngle * 0.3...sliceAngle * 0.3)
        let final = turns * 360 - Double(target) * sliceAngle + wobble
        let base = rotation.truncatingRemainder(dividingBy: 360)
        let duration = reduceMotion ? 0.3 : 3.4
        withAnimation(.timingCurve(0.12, 0.85, 0.2, 1.0, duration: duration)) {
            rotation = rotation - base + final
        }
        // Ticks that slow down with the wheel.
        tickTask?.cancel()
        tickTask = Task {
            var t = 0.0
            while t < duration - 0.3 {
                let progress = t / duration
                let interval = 0.045 + 0.35 * pow(progress, 2.2)
                try? await Task.sleep(for: .seconds(interval))
                if Task.isCancelled { return }
                Haptics.tick()
                SoundKit.shared.play(.tick, volume: 0.35)
                t += interval
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.05) {
            spinning = false
            SoundKit.shared.play(.correct, volume: 0.6)
            Haptics.success()
            landed = decks[target]
        }
    }
}

struct Slice: Shape {
    let start: Angle
    let end: Angle
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        p.move(to: c)
        p.addArc(center: c, radius: min(rect.width, rect.height) / 2, startAngle: start, endAngle: end, clockwise: false)
        p.closeSubpath()
        return p
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
