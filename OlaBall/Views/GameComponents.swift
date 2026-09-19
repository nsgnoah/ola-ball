import SwiftUI

struct ScoreboardView: View {
    let session: GameSession

    var body: some View {
        HStack(spacing: 10) {
            teamPill(session.userTeam, score: session.userScore, hasBall: session.currentPossessor == .user && session.phase != .gameOver)
            VStack(spacing: 2) {
                Text(session.periodLabel).font(.display(18)).foregroundStyle(Theme.gold)
                Text(session.phase == .gameOver ? "FINAL" : "QTR").font(.label(10)).foregroundStyle(Theme.textSecondary)
            }
            .frame(width: 54)
            teamPill(session.opponentTeam, score: session.opponentScore, hasBall: session.currentPossessor == .opponent && session.phase != .gameOver)
        }
    }

    private func teamPill(_ team: Team, score: Int, hasBall: Bool) -> some View {
        HStack(spacing: 8) {
            Text(team.emoji).font(.system(size: 20))
            Text(team.name).font(.label(13)).foregroundStyle(Theme.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            Text("\(score)")
                .font(.display(26)).foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.5), value: score)
            if hasBall {
                Text("🏈").font(.system(size: 11))
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(team.color.opacity(0.35), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct TipCardView: View {
    let concept: Concept
    let isNew: Bool
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: concept.symbol).foregroundStyle(Theme.gold)
                Text(isNew ? "COACH'S TIP · NEW" : "COACH'S TIP").font(.label(11)).foregroundStyle(Theme.gold)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark").font(.label(12)).foregroundStyle(Theme.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .accessibilityIdentifier("dismiss-tip")
            }
            Text(concept.title).font(.display(18)).foregroundStyle(Theme.textPrimary)
            Text(concept.body).font(.body(15)).foregroundStyle(Theme.textSecondary).fixedSize(horizontal: false, vertical: true)
            if isNew {
                Label("Added to your Playbook", systemImage: "book.closed.fill")
                    .font(.label(12)).foregroundStyle(Theme.good)
            }
        }
        .padding(14)
        .background(Theme.cardElevated, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.gold.opacity(0.6), lineWidth: 1.5))
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
