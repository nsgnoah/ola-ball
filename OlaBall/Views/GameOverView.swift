import SwiftUI

struct GameOverView: View {
    @Environment(ProgressStore.self) private var store
    let session: GameSession
    let onPlayAgain: () -> Void
    let onHome: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                VStack(spacing: 8) {
                    Kicker("FINAL", color: Theme.gold)
                    Text(title)
                        .font(.system(size: 46, weight: .black))
                        .tracking(-1)
                        .foregroundStyle(session.outcome == .win ? Theme.gold : .white)
                        .shadow(color: .black.opacity(0.5), radius: 10, y: 4)
                    HStack(spacing: 14) {
                        scoreSide(session.userTeam, score: session.userScore, leading: true)
                        Rectangle().fill(.white.opacity(0.25)).frame(width: 1, height: 30)
                        scoreSide(session.opponentTeam, score: session.opponentScore, leading: false)
                    }
                }
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
                .background(Color.black.opacity(0.30))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(alignment: .top) { Rectangle().fill(Theme.gold).frame(height: 3) }

                HStack(spacing: 0) {
                    stat("\(session.touchdowns)", "TOUCHDOWNS")
                    divider
                    stat("\(session.firstDowns)", "1ST DOWNS")
                    divider
                    stat("\(session.defensiveStops)", "STOPS")
                    divider
                    stat("+\(session.xpEarned)", "XP")
                }
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.30))
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                BroadcastPanel(accent: Theme.gold) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(store.rank.title.uppercased()).font(.system(size: 13, weight: .black)).tracking(1.5).foregroundStyle(.white)
                            Spacer()
                            Text("\(store.progress.xp) XP").font(.system(size: 12, weight: .black)).tracking(1).foregroundStyle(Theme.gold)
                        }
                        ProgressView(value: store.rankProgress).tint(Theme.gold)
                        if let next = store.nextRank {
                            Text("\(next.minXP - store.progress.xp) XP to \(next.title)").font(.body(12)).foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }

                if !session.newlyLearned.isEmpty {
                    BroadcastPanel(accent: Theme.good) {
                        VStack(alignment: .leading, spacing: 7) {
                            Kicker("NEW IN YOUR PLAYBOOK", color: Theme.good)
                            ForEach(session.newlyLearned) { concept in
                                HStack(spacing: 10) {
                                    Image(systemName: concept.symbol).font(.system(size: 13, weight: .bold)).foregroundStyle(Theme.good).frame(width: 22)
                                    Text(concept.title).font(.body(15)).foregroundStyle(.white)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                }

                Button("Play again") {
                    Haptics.heavy()
                    onPlayAgain()
                }
                .buttonStyle(BroadcastButtonStyle())
                .accessibilityLabel("Play again")
                .accessibilityIdentifier("play-again")
                Button("Back to home") { onHome() }
                    .buttonStyle(BroadcastButtonStyle(fill: Color.black.opacity(0.55), ink: .white, prominent: false))
                    .accessibilityLabel("Back to home")
                    .accessibilityIdentifier("back-to-home")
            }
        }
    }

    private var title: String {
        switch session.outcome {
        case .win: return "YOU WIN!"
        case .loss: return "TOUGH LOSS"
        case .tie: return "TIE GAME"
        case nil: return "FINAL"
        }
    }

    private func scoreSide(_ team: Team, score: Int, leading: Bool) -> some View {
        HStack(spacing: 8) {
            if leading {
                Monogram(team: team, size: 26)
                Text(team.abbreviation).font(.system(size: 13, weight: .black)).tracking(1.5).foregroundStyle(.white.opacity(0.85))
                Text("\(score)").font(.system(size: 30, weight: .black)).foregroundStyle(.white)
            } else {
                Text("\(score)").font(.system(size: 30, weight: .black)).foregroundStyle(.white)
                Text(team.abbreviation).font(.system(size: 13, weight: .black)).tracking(1.5).foregroundStyle(.white.opacity(0.85))
                Monogram(team: team, size: 26)
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.15)).frame(width: 1, height: 28)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.display(20)).foregroundStyle(.white)
            Text(label).font(.system(size: 9, weight: .black)).tracking(1.2).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}
