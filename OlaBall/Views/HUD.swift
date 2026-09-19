import SwiftUI

/// Field HUD pieces (night glass) and the shared paper components.

struct BroadcastPanel<Content: View>: View {
    var accent: Color? = nil
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 0) {
            if let accent { Rectangle().fill(accent).frame(width: 5) }
            content.frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.black.opacity(0.30))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }
}

/// A cream note card over the field: Ola's notes, results, calls.
struct PaperPanel<Content: View>: View {
    var accent: Color? = nil
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 0) {
            if let accent { Rectangle().fill(accent).frame(width: 6) }
            content.frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(Theme.paper)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 14, y: 8)
    }
}

struct Kicker: View {
    let text: String
    var color: Color = Theme.gold
    var size: CGFloat = 12

    init(_ text: String, color: Color = Theme.gold, size: CGFloat = 12) {
        self.text = text; self.color = color; self.size = size
    }

    var body: some View {
        Text(text).font(.condensed(size)).tracking(size * 0.16).textCase(.uppercase).foregroundStyle(color)
    }
}

struct StatusChip: View {
    let text: String
    let fill: Color
    let ink: Color

    var body: some View {
        Text(text)
            .font(.condensed(13))
            .tracking(1.6)
            .foregroundStyle(ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(fill, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}

struct BroadcastButtonStyle: ButtonStyle {
    var fill: Color = Theme.gold
    var ink: Color = Color(hex: "0B1220")
    var prominent = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline(20))
            .tracking(1)
            .textCase(.uppercase)
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                prominent
                    ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "FFD65C"), Theme.gold, Color(hex: "E8AE1E")], startPoint: .top, endPoint: .bottom))
                    : AnyShapeStyle(fill),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.white.opacity(prominent ? 0.25 : 0.15), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

/// The TV-style score bug: both teams, period, possession, plus a status row with the down and distance.
struct ScoreBug: View {
    let session: GameSession
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 0) {
                teamCell(session.userTeam, score: session.userScore, hasBall: session.userOnOffense && session.phase != .gameOver, leading: true)
                periodCell
                teamCell(session.opponentTeam, score: session.opponentScore, hasBall: !session.userOnOffense && session.phase != .gameOver, leading: false)
            }
            .frame(height: 54)
            .background(Color.black.opacity(0.32))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))

            HStack(spacing: 8) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .black))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .accessibilityIdentifier("close-game")
                Text(session.situationText)
                    .font(.condensed(14))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 10)
                    .frame(height: 30)
                    .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .accessibilityIdentifier("situation")
                Spacer(minLength: 4)
                statusChip
            }
        }
    }

    private var statusChip: some View {
        Group {
            switch session.phase {
            case .live:
                StatusChip(text: "LIVE", fill: Theme.bad, ink: .white)
            case .gameOver:
                StatusChip(text: "FINAL", fill: .white, ink: Theme.ink)
            default:
                if session.userOnOffense {
                    StatusChip(text: "YOUR BALL", fill: Theme.gold, ink: Theme.ink)
                } else {
                    StatusChip(text: "YOUR DEFENSE", fill: Theme.good, ink: Theme.ink)
                }
            }
        }
    }

    private var periodCell: some View {
        VStack(spacing: -2) {
            Text(session.periodLabel).font(.score(22)).foregroundStyle(Theme.gold)
            Text(session.phase == .gameOver ? "FINAL" : "QTR").font(.condensed(9)).tracking(1.5).foregroundStyle(Theme.textSecondary)
        }
        .frame(width: 52)
        .frame(maxHeight: .infinity)
        .background(Color.black.opacity(0.25))
    }

    private func teamCell(_ team: Team, score: Int, hasBall: Bool, leading: Bool) -> some View {
        HStack(spacing: 6) {
            if leading {
                Rectangle().fill(team.color).frame(width: 5)
                Monogram(team: team, size: 26).padding(.leading, 4)
                Text(team.abbreviation).font(.condensed(15)).tracking(1.5).foregroundStyle(.white)
                if hasBall { possession }
                Spacer(minLength: 2)
                scoreText(score).padding(.trailing, 10)
            } else {
                scoreText(score).padding(.leading, 10)
                Spacer(minLength: 2)
                if hasBall { possession }
                Text(team.abbreviation).font(.condensed(15)).tracking(1.5).foregroundStyle(.white)
                Monogram(team: team, size: 26).padding(.trailing, 4)
                Rectangle().fill(team.color).frame(width: 5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var possession: some View {
        Circle().fill(Theme.gold).frame(width: 7, height: 7)
    }

    private func scoreText(_ score: Int) -> some View {
        Text("\(score)")
            .font(.score(36))
            .foregroundStyle(.white)
            .contentTransition(.numericText())
            .animation(.spring(duration: 0.5), value: score)
    }
}

/// A club crest: the monogram letter on a team-color disc with a fine ring.
struct Monogram: View {
    let team: Team
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: [Art.swiftUI(team.color, brightness: 0.08), Art.swiftUI(team.color, brightness: -0.14)], startPoint: .top, endPoint: .bottom))
            Circle().stroke(.white.opacity(0.35), lineWidth: max(1, size * 0.035))
            Circle().stroke(.black.opacity(0.25), lineWidth: max(1, size * 0.02)).padding(size * 0.1)
            Text(team.monogram)
                .font(.headline(size * 0.6))
                .foregroundStyle(.white)
                .offset(y: size * 0.02)
                .shadow(color: .black.opacity(0.35), radius: size * 0.04, y: size * 0.03)
        }
        .frame(width: size, height: size)
    }
}

/// Coach Ola's badge: a gold disc with a headset. She's the voice on the other end of your headset.
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
