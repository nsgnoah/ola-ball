import SwiftUI

struct MatchOverView: View {
    @Environment(LocalMatchStore.self) private var localMatches
    @Environment(ProfileStore.self) private var profiles
    let controller: MatchController
    let onClose: () -> Void
    @State private var rematchID: String?
    @State private var pop = false

    var body: some View {
        let s = controller.state
        let me = controller.me
        let winner = s.winnerID
        let iWon = winner == me
        let winnerWorld = winner.flatMap { s.player($0)?.world }
        ZStack {
            if let w = winnerWorld { GameBackground(world: w) } else { GameBackground(top: Theme.violet, bottom: Theme.violetDeep) }
            VStack(spacing: 14) {
                MatchHeader(controller: controller, onClose: onClose)
                Spacer()
                Kicker("FINAL")
                Image(systemName: "trophy.fill").font(.system(size: 76, weight: .black)).foregroundStyle(Theme.gold)
                    .shadow(color: Theme.goldDeep, radius: 0, y: 5)
                    .scaleEffect(pop ? 1 : 0.2).rotationEffect(.degrees(pop ? 0 : 20))
                Text(winner == nil ? "IT'S A TIE" : (iWon ? "YOU WIN" : "\(s.player(winner!)?.name.uppercased() ?? "THEY") WINS"))
                    .font(.headline(70)).foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .shadow(color: .black.opacity(0.3), radius: 0, y: 3)
                    .padding(.top, -8)
                    .accessibilityIdentifier("match-over")
                HStack(spacing: 12) {
                    ForEach(s.players) { p in
                        VStack(spacing: 6) {
                            SideAvatars(player: p, size: 40)
                            Text(p.name.uppercased()).font(.label(13)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.6)
                            Crowns(count: s.crowns(for: p.id), size: 15)
                            Text("\(controller.total(p.id))").font(.score(36)).foregroundStyle(Theme.ink)
                            Kicker("TOTAL POINTS", color: Theme.ink3, size: 10)
                        }
                        .frame(maxWidth: .infinity)
                        .panel(padding: 14)
                        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(winner == p.id ? Theme.gold : .clear, lineWidth: 4))
                    }
                }
                OlaSays(text: winner == nil ? "Identical. Suspicious. Run it back." : (iWon ? "Bragging rights are yours until the rematch." : "Rematch. Immediately. Don't let this stand."))
                Spacer()
                if controller.transport.isPassAndPlay, let p = profiles.profile, let partner = s.partner(of: s.players[0].id) {
                    Button("Rematch") {
                        Haptics.heavy()
                        if s.mode == .teams {
                            let a = s.players[0].members.map { (name: $0.name, lane: $0.answers) }
                            let b = partner.members.map { (name: $0.name, lane: $0.answers) }
                            rematchID = localMatches.createTeams(ours: a, theirs: b)
                        } else {
                            rematchID = localMatches.create(me: p, partnerName: partner.name, partnerWorld: partner.world)
                        }
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.gold))
                    .accessibilityIdentifier("rematch")
                }
                Button("Back to matches") { onClose() }
                    .buttonStyle(ChunkyButtonStyle(color: .white, edge: Theme.panelEdge, ink: Theme.ink, height: 52, fontSize: 22))
                    .accessibilityIdentifier("back-to-matches")
            }
            .padding(20)
            if iWon { ConfettiBurst() }
        }
        .onAppear {
            withAnimation(.spring(duration: 0.7, bounce: 0.5).delay(0.1)) { pop = true }
            SoundKit.shared.play(iWon ? .fanfare : (winner == nil ? .swoosh : .lose))
        }
        .fullScreenCover(item: $rematchID) { id in
            if let state = localMatches.matches[id] {
                MatchView(controller: MatchController(state: state, transport: PassAndPlayTransport(id: id, state: state, store: localMatches)))
                    .environment(localMatches)
                    .environment(profiles)
            }
        }
    }
}
