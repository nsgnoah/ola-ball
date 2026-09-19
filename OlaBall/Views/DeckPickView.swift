import SwiftUI

/// You pick the deck your partner has to answer. Spin, or just tap the slice you want.
struct DeckPickView: View {
    let controller: MatchController
    let round: Int
    let target: Member

    var body: some View {
        let world = target.answers
        let decks = Decks.decks(in: world)
        let who = target.name
        ZStack {
            GameBackground(world: world)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    MatchHeader(controller: controller)
                    VStack(spacing: 4) {
                        Kicker("ROUND \(round) · \(MatchEngine.roundLabel(round))")
                        StickerText("WHAT DOES \(who.uppercased()) GET?", size: TypeScale.title)
                    }
                    .padding(.top, 6)
                    WheelView(decks: decks, onPick: { controller.pick($0) }, enabled: !controller.isSubmitting)
                        .id(target.id)
                    OlaSays(text: controller.state.mode == .teams
                            ? "\(who) answers \(world == .his ? "his" : "her") world. Spin, or tap a slice. Be kind. Or don't."
                            : "Spin for a suggestion, or tap the slice you want. Be kind. Or don't.")
                    if controller.isSubmitting { ProgressView().tint(.white) }
                }
                .padding(20)
            }
        }
    }
}
