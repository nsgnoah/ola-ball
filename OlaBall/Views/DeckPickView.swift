import SwiftUI

/// You pick the deck your partner has to answer. Spin, or just tap the slice you want.
struct DeckPickView: View {
    let controller: MatchController
    let round: Int

    var body: some View {
        let myWorld = controller.state.player(controller.me)?.world ?? .his
        let decks = Decks.decks(in: myWorld)
        let who = controller.partner?.name ?? "your partner"
        ZStack {
            GameBackground(world: myWorld)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    MatchHeader(controller: controller)
                    VStack(spacing: 4) {
                        Kicker("ROUND \(round) · \(MatchEngine.roundLabel(round))")
                        Text("WHAT DOES \(who.uppercased()) GET?")
                            .font(.headline(38)).foregroundStyle(.white)
                            .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.6)
                            .shadow(color: .black.opacity(0.25), radius: 0, y: 2)
                    }
                    .padding(.top, 6)
                    WheelView(decks: decks, onPick: { controller.pick($0) }, enabled: !controller.isSubmitting)
                    OlaSays(text: "Spin for a suggestion, or tap the slice you want. Be kind. Or don't.")
                    if controller.isSubmitting { ProgressView().tint(.white) }
                }
                .padding(20)
            }
        }
    }
}
