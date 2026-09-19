import SwiftUI

struct GameOverView: View {
    @Environment(ProgressStore.self) private var store
    let session: GameSession
    let onPlayAgain: () -> Void
    let onHome: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    Text(title).font(.display(34)).foregroundStyle(session.outcome == .win ? Theme.gold : Theme.textPrimary)
                    Text("\(session.userTeam.name) \(session.userScore), \(session.opponentTeam.name) \(session.opponentScore)")
                        .font(.body(16)).foregroundStyle(Theme.textSecondary)
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .card()

                HStack(spacing: 10) {
                    stat("\(session.touchdowns)", "TDs")
                    stat("\(session.firstDowns)", "1st downs")
                    stat("\(session.defensiveStops)", "stops")
                    stat("+\(session.xpEarned)", "XP")
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(store.rank.title).font(.display(16)).foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("\(store.progress.xp) XP").font(.label(13)).foregroundStyle(Theme.gold)
                    }
                    ProgressView(value: store.rankProgress).tint(Theme.gold)
                }
                .padding()
                .card()

                if !session.newlyLearned.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("New in your Playbook", systemImage: "book.closed.fill")
                            .font(.label(13)).foregroundStyle(Theme.gold)
                        ForEach(session.newlyLearned) { concept in
                            HStack(spacing: 10) {
                                Image(systemName: concept.symbol).foregroundStyle(Theme.good).frame(width: 22)
                                Text(concept.title).font(.body(15)).foregroundStyle(Theme.textPrimary)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
                }

                Button("Play again") {
                    Haptics.heavy()
                    onPlayAgain()
                }
                .buttonStyle(BigButtonStyle())
                Button("Back to home") { onHome() }
                    .buttonStyle(BigButtonStyle(fill: Theme.card, foreground: Theme.textPrimary))
            }
        }
    }

    private var title: String {
        switch session.outcome {
        case .win: return "YOU WIN!"
        case .loss: return "Tough loss"
        case .tie: return "Tie game"
        case nil: return "Final"
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.display(20)).foregroundStyle(Theme.textPrimary)
            Text(label).font(.label(11)).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .card()
    }
}
