import SwiftUI

/// Both scores for a finished round, and who takes the crown.
struct RoundRevealView: View {
    let controller: MatchController
    let round: Int
    @State private var shown = false

    var body: some View {
        let s = controller.state
        let r = s.rounds[round - 1]
        let winner = s.roundWinner(r)
        let me = controller.me
        let iWon = winner == me
        VStack(alignment: .leading, spacing: 16) {
            MatchHeader(controller: controller)
            Spacer()
            Kicker("ROUND \(round) · \(MatchEngine.roundLabel(round))", color: Theme.ink3)
            Text(headline(winner: winner, me: me)).font(.headline(56)).foregroundStyle(winner.flatMap { s.player($0)?.world.color } ?? Theme.ink).lineLimit(2).minimumScaleFactor(0.5).padding(.top, -8)
            HStack(spacing: 12) {
                ForEach(s.players) { p in
                    let res = r.results[p.id]
                    let deck = r.picks[p.id].flatMap(Decks.byID)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Avatar(name: p.name, world: p.world, size: 28)
                            Text(p.name.uppercased()).font(.condensed(13)).tracking(1).foregroundStyle(Theme.ink).lineLimit(1)
                        }
                        Text("\(res?.score ?? 0)").font(.score(44)).foregroundStyle(Theme.ink)
                            .scaleEffect(shown ? 1 : 0.6).opacity(shown ? 1 : 0)
                        if let deck, let res {
                            HStack(spacing: 6) {
                                Image(systemName: deck.symbol).font(.system(size: 11, weight: .bold)).foregroundStyle(deck.color)
                                Text("\(res.correct)/\(res.questionIDs.count) · \(deck.title)").font(.body(12)).foregroundStyle(Theme.ink2).lineLimit(2)
                            }
                        }
                        if winner == p.id {
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill").font(.system(size: 12, weight: .bold))
                                Kicker("CROWN", color: p.world.color, size: 11)
                            }
                            .foregroundStyle(p.world.color)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .paperCard(padding: 14)
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(winner == p.id ? p.world.color : .clear, lineWidth: 3))
                }
            }
            HStack(spacing: 8) {
                OlaBadge(size: 22)
                Text(olaLine(iWon: iWon, tie: winner == nil)).font(.body(14)).foregroundStyle(Theme.ink2)
            }
            Spacer()
            Button(s.status == .finished ? "See the final" : "Continue") { Haptics.tap(); controller.acknowledgeReveal() }
                .buttonStyle(InkButtonStyle())
                .accessibilityIdentifier("reveal-continue")
        }
        .padding(20)
        .onAppear {
            withAnimation(.spring(duration: 0.6)) { shown = true }
            if winner == nil { SoundKit.shared.play(.swoosh) } else { SoundKit.shared.play(iWon ? .crown : .lose) }
        }
    }

    private func headline(winner: String?, me: String) -> String {
        guard let winner else { return "DEAD HEAT" }
        return winner == me ? "YOU TAKE IT" : "\(controller.state.player(winner)?.name.uppercased() ?? "THEY") TAKE IT"
    }

    private func olaLine(iWon: Bool, tie: Bool) -> String {
        if tie { return "Same score. Nobody gets the crown. Awkward." }
        return iWon ? "First to three crowns wins the match. Keep it up." : "They picked well. Pick better."
    }
}
