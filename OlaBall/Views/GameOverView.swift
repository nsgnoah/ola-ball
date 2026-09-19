import SwiftUI

struct GameOverView: View {
    @Environment(ProgressStore.self) private var store
    let session: GameSession
    let onPlayAgain: () -> Void
    let onHome: () -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                VStack(spacing: 6) {
                    Kicker("FINAL", color: Theme.ink3)
                    Text(title)
                        .font(.headline(72))
                        .foregroundStyle(session.outcome == .win ? session.userTeam.color : Theme.ink)
                        .padding(.top, -8)
                    HStack(spacing: 16) {
                        scoreSide(session.userTeam, score: session.userScore, leading: true)
                        Rectangle().fill(Theme.rule).frame(width: 1, height: 40)
                        scoreSide(session.opponentTeam, score: session.opponentScore, leading: false)
                    }
                }
                .frame(maxWidth: .infinity)
                .paperCard(padding: 18)

                HStack(spacing: 0) {
                    stat("\(session.touchdowns)", "TOUCHDOWNS")
                    divider
                    stat("\(session.firstDowns)", "1ST DOWNS")
                    divider
                    stat("\(session.defensiveStops)", "STOPS")
                    divider
                    stat("+\(session.xpEarned)", "XP")
                }
                .paperCard(padding: 12)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(store.rank.title.uppercased()).font(.condensed(15)).tracking(1.5).foregroundStyle(Theme.ink)
                        Spacer()
                        Text("\(store.progress.xp) XP").font(.condensed(13)).tracking(1).foregroundStyle(Theme.ink3)
                    }
                    ProgressView(value: store.rankProgress).tint(Theme.ink)
                    if let next = store.nextRank {
                        Text("\(next.minXP - store.progress.xp) XP to \(next.title)").font(.body(12)).foregroundStyle(Theme.ink3)
                    }
                }
                .paperCard(padding: 14)

                if !session.newlyLearned.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            OlaBadge(size: 20)
                            Kicker("NEW IN YOUR PLAYBOOK", color: Theme.ink2)
                        }
                        ForEach(session.newlyLearned) { concept in
                            HStack(spacing: 10) {
                                Image(systemName: concept.symbol).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.paper)
                                    .frame(width: 26, height: 26).background(Theme.ink, in: RoundedRectangle(cornerRadius: 7))
                                Text(concept.title).font(.bodyBold(15)).foregroundStyle(Theme.ink)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .paperCard(padding: 14)
                }

                Button("Play again") {
                    Haptics.heavy()
                    onPlayAgain()
                }
                .buttonStyle(InkButtonStyle())
                .accessibilityLabel("Play again")
                .accessibilityIdentifier("play-again")
                Button("Back to home") { onHome() }
                    .buttonStyle(InkButtonStyle(outlined: true))
                    .accessibilityLabel("Back to home")
                    .accessibilityIdentifier("back-to-home")
            }
            .padding(.bottom, 20)
        }
    }

    private var title: String {
        switch session.outcome {
        case .win: return "YOU WIN"
        case .loss: return "TOUGH ONE"
        case .tie: return "TIE GAME"
        case nil: return "FINAL"
        }
    }

    private func scoreSide(_ team: Team, score: Int, leading: Bool) -> some View {
        HStack(spacing: 10) {
            if leading {
                Monogram(team: team, size: 34)
                Text(team.abbreviation).font(.condensed(15)).tracking(1.5).foregroundStyle(Theme.ink2)
                Text("\(score)").font(.score(44)).foregroundStyle(Theme.ink)
            } else {
                Text("\(score)").font(.score(44)).foregroundStyle(Theme.ink)
                Text(team.abbreviation).font(.condensed(15)).tracking(1.5).foregroundStyle(Theme.ink2)
                Monogram(team: team, size: 34)
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.rule).frame(width: 1, height: 30)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value).font(.score(26)).foregroundStyle(Theme.ink)
            Text(label).font(.condensed(10)).tracking(1.3).foregroundStyle(Theme.ink3)
        }
        .frame(maxWidth: .infinity)
    }
}
