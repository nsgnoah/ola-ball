import SwiftUI

/// You pick the deck your partner has to answer. From your world, naturally.
struct DeckPickView: View {
    let controller: MatchController
    let round: Int
    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let myWorld = controller.state.player(controller.me)?.world ?? .his
        let decks = Decks.decks(in: myWorld)
        let who = controller.partner?.name ?? "your partner"
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                MatchHeader(controller: controller)
                Kicker("ROUND \(round) · \(MatchEngine.roundLabel(round))", color: Theme.ink3).padding(.top, 6)
                Text("WHAT DOES \(who.uppercased()) GET?").font(.headline(40)).foregroundStyle(Theme.ink).lineLimit(2).minimumScaleFactor(0.6).padding(.top, -6)
                HStack(spacing: 8) {
                    OlaBadge(size: 22)
                    Text("Pick from \(myWorld.title.lowercased()). Be kind, or don't.").font(.body(14)).foregroundStyle(Theme.ink2)
                }
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(decks) { deck in
                        Button {
                            Haptics.heavy()
                            controller.pick(deck)
                        } label: {
                            DeckTile(deck: deck)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("deck-\(deck.id)")
                        .disabled(controller.isSubmitting)
                    }
                }
                if controller.isSubmitting {
                    HStack { Spacer(); ProgressView().tint(Theme.ink); Spacer() }
                }
            }
            .padding(20)
        }
    }
}
