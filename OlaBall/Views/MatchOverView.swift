import SwiftUI

struct MatchOverView: View {
    @Environment(LocalMatchStore.self) private var localMatches
    @Environment(ProfileStore.self) private var profiles
    let controller: MatchController
    let onClose: () -> Void
    @State private var rematchID: String?

    var body: some View {
        let s = controller.state
        let me = controller.me
        let winner = s.winnerID
        let iWon = winner == me
        VStack(alignment: .leading, spacing: 16) {
            MatchHeader(controller: controller, onClose: onClose)
            Spacer()
            Kicker("FINAL", color: Theme.ink3)
            Text(winner == nil ? "IT'S A TIE" : (iWon ? "YOU WIN" : "\(s.player(winner!)?.name.uppercased() ?? "THEY") WIN"))
                .font(.headline(72)).foregroundStyle(winner.flatMap { s.player($0)?.world.color } ?? Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.5).padding(.top, -10)
                .accessibilityIdentifier("match-over")
            HStack(spacing: 12) {
                ForEach(s.players) { p in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Avatar(name: p.name, world: p.world, size: 28)
                            Text(p.name.uppercased()).font(.condensed(13)).tracking(1).foregroundStyle(Theme.ink).lineLimit(1)
                        }
                        Crowns(count: s.crowns(for: p.id), color: p.world.color)
                        Text("\(controller.total(p.id))").font(.score(36)).foregroundStyle(Theme.ink)
                        Kicker("TOTAL POINTS", color: Theme.ink3, size: 10)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .paperCard(padding: 14)
                }
            }
            HStack(spacing: 8) {
                OlaBadge(size: 22)
                Text(winner == nil ? "Identical. Suspicious. Run it back." : (iWon ? "Bragging rights are yours until the rematch." : "Rematch. Immediately. Don't let this stand."))
                    .font(.body(14)).foregroundStyle(Theme.ink2)
            }
            Spacer()
            if controller.transport.isPassAndPlay, let p = profiles.profile, let partner = s.partner(of: s.players[0].id) {
                Button("Rematch") {
                    Haptics.heavy()
                    rematchID = localMatches.create(me: p, partnerName: partner.name, partnerWorld: partner.world)
                }
                .buttonStyle(InkButtonStyle())
                .accessibilityIdentifier("rematch")
            }
            Button("Back to matches") { onClose() }.buttonStyle(InkButtonStyle(outlined: true))
                .accessibilityIdentifier("back-to-matches")
        }
        .padding(20)
        .onAppear { SoundKit.shared.play(iWon ? .fanfare : (winner == nil ? .swoosh : .lose)) }
        .navigationDestination(item: $rematchID) { id in
            if let state = localMatches.matches[id] {
                MatchView(controller: MatchController(state: state, transport: PassAndPlayTransport(id: id, state: state, store: localMatches)))
            }
        }
    }
}
