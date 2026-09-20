import SwiftUI

/// Both scores for a finished round, and who takes the crown.
struct RoundRevealView: View {
    let controller: MatchController
    let round: Int
    @State private var shown = false
    @State private var crownPop = false

    var body: some View {
        let s = controller.state
        let r = s.rounds[round - 1]
        let winner = s.roundWinner(r)
        let me = controller.me
        let iWon = winner == me
        let winnerWorld = winner.flatMap { s.player($0)?.world }
        ZStack {
            if let w = winnerWorld { GameBackground(world: w) } else { GameBackground(top: Theme.violet, bottom: Theme.violetDeep) }
            VStack(spacing: 14) {
                MatchHeader(controller: controller)
                Spacer()
                Kicker("ROUND \(round) · \(MatchEngine.roundLabel(round))")
                if winner != nil {
                    CrownIcon(size: 84)
                        .scaleEffect(crownPop ? 1 : 0.2).rotationEffect(.degrees(crownPop ? 0 : -30))
                }
                StickerText(headline(winner: winner, me: me), size: TypeScale.title)
                    .padding(.top, -6)
                HStack(spacing: 12) {
                    ForEach(s.players) { p in
                        VStack(spacing: 6) {
                            if p.isTeam {
                                SideAvatars(player: p, size: 30)
                                Text(p.name.uppercased()).font(.label(11)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.6)
                                Text("\(r.score(for: p))").font(.score(40)).foregroundStyle(Theme.ink)
                                    .scaleEffect(shown ? 1 : 0.6).opacity(shown ? 1 : 0)
                                ForEach(p.members) { m in
                                    let res = r.results[m.id]
                                    let deck = r.picks[m.id].flatMap(Decks.byID)
                                    HStack(spacing: 5) {
                                        if let deck { DeckIcon(deck: deck, fill: .white, ink: deck.color).frame(width: 14, height: 14) }
                                        Text(m.name).font(.bodyBold(11)).foregroundStyle(Theme.ink).lineLimit(1)
                                        Spacer(minLength: 2)
                                        Text(res.map { "\($0.score)" } ?? "—").font(.score(14)).foregroundStyle(Theme.ink2)
                                    }
                                }
                            } else {
                                let res = r.results[p.members[0].id]
                                let deck = r.picks[p.members[0].id].flatMap(Decks.byID)
                                if let deck { Mascot(deck: deck, mood: winner == p.id ? .happy : (winner == nil ? .idle : .sad), size: 64) }
                                HStack(spacing: 6) {
                                    Avatar(name: p.name, world: p.world, size: 24)
                                    Text(p.name.uppercased()).font(.label(12)).foregroundStyle(Theme.ink).lineLimit(1)
                                }
                                Text("\(res?.score ?? 0)").font(.score(44)).foregroundStyle(Theme.ink)
                                    .scaleEffect(shown ? 1 : 0.6).opacity(shown ? 1 : 0)
                                if let deck, let res {
                                    Text("\(res.correct)/\(res.questionIDs.count) · \(deck.title)").font(.bodyRegular(11)).foregroundStyle(Theme.ink2).lineLimit(2).multilineTextAlignment(.center)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .panel(padding: 12)
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(winner == p.id ? Theme.gold : .clear, lineWidth: 4))
                    }
                }
                OlaSays(text: olaLine(iWon: iWon, tie: winner == nil))
                Spacer()
                Button(s.status == .finished ? "See the final" : "Continue") { Haptics.tap(); controller.acknowledgeReveal() }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.gold))
                    .accessibilityIdentifier("reveal-continue")
            }
            .padding(20)
            if iWon { ConfettiBurst() }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.6)) { shown = true }
            withAnimation(.spring(duration: 0.7, bounce: 0.5).delay(0.1)) { crownPop = true }
            if winner == nil { SoundKit.shared.play(.swoosh) } else { SoundKit.shared.play(iWon ? .crown : .lose) }
        }
    }

    private func headline(winner: String?, me: String) -> String {
        guard let winner else { return "DEAD HEAT" }
        return winner == me ? "YOU TAKE IT" : "\(controller.state.player(winner)?.name.uppercased() ?? "THEY") TAKES IT"
    }

    private func olaLine(iWon: Bool, tie: Bool) -> String {
        if tie { return "Same score. Nobody gets the crown. Awkward." }
        return iWon ? "First to three crowns wins the match. Keep it up." : "They picked well. Pick better."
    }
}
