import SwiftUI

struct TipCardView: View {
    let concept: Concept
    let isNew: Bool
    let onDismiss: () -> Void

    var body: some View {
        PaperPanel(accent: Theme.gold) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    OlaBadge(size: 24)
                    Kicker(isNew ? "COACH OLA · NEW" : "COACH OLA", color: Theme.ink2)
                    Spacer()
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark").font(.system(size: 12, weight: .black)).foregroundStyle(Theme.ink3)
                            .frame(width: 28, height: 28)
                    }
                    .accessibilityIdentifier("dismiss-tip")
                }
                Text(concept.title).font(.headline(24)).foregroundStyle(Theme.ink)
                Text(concept.body).font(.body(15)).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true)
                if isNew {
                    HStack(spacing: 6) {
                        Image(systemName: "book.closed.fill").font(.system(size: 11, weight: .bold))
                        Kicker("ADDED TO YOUR PLAYBOOK", color: Theme.goodInk, size: 11)
                    }
                    .foregroundStyle(Theme.goodInk)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }
}

struct ConfettiView: View {
    private struct Particle {
        let x: CGFloat, delay: Double, speed: Double, size: CGFloat, hue: Double, drift: CGFloat
    }
    private let particles: [Particle] = (0..<70).map { _ in
        Particle(x: .random(in: 0...1), delay: .random(in: 0...1.2), speed: .random(in: 0.9...1.6), size: .random(in: 6...11), hue: .random(in: 0...1), drift: .random(in: -40...40))
    }
    private let start = Date()

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { ctx, size in
                let t = timeline.date.timeIntervalSince(start)
                for p in particles {
                    let life = (t - p.delay) * p.speed
                    guard life > 0, life < 2.4 else { continue }
                    let y = -20 + CGFloat(life / 2.4) * (size.height + 40)
                    let x = p.x * size.width + p.drift * CGFloat(sin(life * 3))
                    let rect = CGRect(x: x, y: y, width: p.size, height: p.size * 0.6)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(Color(hue: p.hue, saturation: 0.8, brightness: 1)))
                }
            }
        }
        .ignoresSafeArea()
    }
}

