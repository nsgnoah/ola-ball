import SwiftUI

/// One match. Renders whatever stage the controller says we're in.
struct MatchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var controller: MatchController

    init(controller: MatchController) {
        _controller = State(initialValue: controller)
    }

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            switch controller.stage {
            case .handoff(let name):
                HandoffView(name: name) { controller.continueAfterHandoff() }
            case .intro(let round):
                RoundIntroView(controller: controller, round: round)
            case .answering:
                QuestionView(controller: controller)
            case .picking(let round):
                DeckPickView(controller: controller, round: round)
            case .roundReveal(let round):
                RoundRevealView(controller: controller, round: round)
            case .waiting:
                WaitingView(controller: controller) { dismiss() }
            case .finished:
                MatchOverView(controller: controller) { dismiss() }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.light)
        .onAppear { controller.start(announce: true) }
        .animation(.easeOut(duration: 0.2), value: controller.stage)
    }
}

/// Top strip shared by in-match screens: close, both players with crowns.
struct MatchHeader: View {
    let controller: MatchController
    var onClose: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let me = controller.me
        let mine = controller.state.player(me)
        let them = controller.partner
        HStack(spacing: 10) {
            Button {
                if let onClose { onClose() } else { dismiss() }
            } label: {
                Image(systemName: "xmark").font(.system(size: 13, weight: .black)).foregroundStyle(Theme.ink)
                    .frame(width: 34, height: 34)
                    .background(Theme.paperCard, in: Circle())
                    .overlay(Circle().stroke(Theme.rule, lineWidth: 1))
            }
            .accessibilityIdentifier("close-match")
            if let mine {
                side(mine, leading: true)
            }
            Text("VS").font(.condensed(12)).tracking(2).foregroundStyle(Theme.ink3)
            if let them {
                side(them, leading: false)
            } else {
                Text("Waiting for partner").font(.body(12)).foregroundStyle(Theme.ink3)
            }
        }
    }

    private func side(_ p: MatchPlayer, leading: Bool) -> some View {
        HStack(spacing: 6) {
            if leading { Avatar(name: p.name, world: p.world, size: 28) }
            VStack(alignment: leading ? .leading : .trailing, spacing: 1) {
                Text(p.name.uppercased()).font(.condensed(13)).tracking(1).foregroundStyle(Theme.ink).lineLimit(1)
                Crowns(count: controller.crowns(p.id), color: p.world.color)
            }
            if !leading { Avatar(name: p.name, world: p.world, size: 28) }
        }
        .frame(maxWidth: .infinity, alignment: leading ? .leading : .trailing)
    }
}

struct HandoffView: View {
    let name: String
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "iphone.gen3.radiowaves.left.and.right")
                .font(.system(size: 54, weight: .bold)).foregroundStyle(Theme.ink)
            Kicker("HAND THE PHONE TO", color: Theme.ink3)
            Text(name.uppercased()).font(.headline(64)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.5)
            Text("No peeking. Their questions are next.").font(.body(15)).foregroundStyle(Theme.ink2)
            Spacer()
            Button("I'm \(name), let's go") { Haptics.tap(); onContinue() }
                .buttonStyle(InkButtonStyle())
                .accessibilityIdentifier("handoff-continue")
        }
        .padding(20)
    }
}

struct RoundIntroView: View {
    let controller: MatchController
    let round: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            MatchHeader(controller: controller)
            Spacer()
            Kicker("ROUND \(round) OF \(MatchState.maxRounds) · \(MatchEngine.roundLabel(round))", color: Theme.ink3)
            if let deck = controller.deck {
                Text(deck.title.uppercased()).font(.headline(52)).foregroundStyle(deck.color).lineLimit(2).minimumScaleFactor(0.6)
                    .padding(.top, -6)
                HStack(spacing: 8) {
                    OlaBadge(size: 22)
                    Text(introLine(deck)).font(.body(15)).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true)
                }
                DeckTile(deck: deck)
            }
            HStack(spacing: 14) {
                fact("\(MatchState.questionsPerRound)", "QUESTIONS")
                fact("\(Int(MatchEngine.secondsPerQuestion))s", "EACH")
                fact(MatchEngine.tierName(MatchEngine.tiers(forRound: round).max() ?? 1), "TOP TIER")
            }
            Spacer()
            Button("Start round \(round)") { Haptics.heavy(); controller.beginAnswering() }
                .buttonStyle(InkButtonStyle())
                .accessibilityIdentifier("start-round")
        }
        .padding(20)
    }

    private func introLine(_ deck: Deck) -> String {
        let who = controller.partner?.name ?? "Your partner"
        switch round {
        case 1: return "\(who) picked this one for you. Warm-up questions. Deep breath."
        case 5: return "\(who) chose \(deck.title) for the last word. All legend-tier. No pressure."
        default: return "\(who) thinks you don't know \(deck.title). Time to find out."
        }
    }

    private func fact(_ v: String, _ l: String) -> some View {
        VStack(spacing: 1) {
            Text(v).font(.score(24)).foregroundStyle(Theme.ink)
            Text(l).font(.condensed(10)).tracking(1.4).foregroundStyle(Theme.ink3)
        }
        .frame(maxWidth: .infinity)
        .paperCard(padding: 10, radius: 12)
    }
}

struct WaitingView: View {
    let controller: MatchController
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            MatchHeader(controller: controller, onClose: onClose)
            Spacer()
            OlaBadge(size: 44)
            Kicker("THEIR MOVE", color: Theme.ink3)
            Text("\(controller.partner?.name.uppercased() ?? "YOUR PARTNER")'S TURN").font(.headline(44)).foregroundStyle(Theme.ink).lineLimit(2).minimumScaleFactor(0.6)
            Text(controller.transport.isPassAndPlay ? "Hand the phone over when they're ready." : "You'll get a notification when they've played. Go live your life.")
                .font(.body(15)).foregroundStyle(Theme.ink2)
            if let err = controller.error {
                Text(err).font(.body(13)).foregroundStyle(Theme.badInk)
            }
            RoundHistory(controller: controller)
            Spacer()
            Button("Back to matches") { onClose() }.buttonStyle(InkButtonStyle(outlined: true))
        }
        .padding(20)
    }
}

/// The scoreboard of completed rounds.
struct RoundHistory: View {
    let controller: MatchController

    var body: some View {
        let s = controller.state
        VStack(alignment: .leading, spacing: 8) {
            Kicker("SCORECARD", color: Theme.ink2)
            ForEach(s.rounds, id: \.number) { r in
                HStack(spacing: 8) {
                    Text("R\(r.number)").font(.condensed(13)).foregroundStyle(Theme.ink3).frame(width: 28, alignment: .leading)
                    ForEach(s.players) { p in
                        let deck = r.picks[p.id].flatMap(Decks.byID)
                        let res = r.results[p.id]
                        HStack(spacing: 6) {
                            if let deck { Image(systemName: deck.symbol).font(.system(size: 11, weight: .bold)).foregroundStyle(deck.color) }
                            Text(res.map { "\($0.score)" } ?? (deck == nil ? "—" : "…")).font(.score(18)).foregroundStyle(Theme.ink)
                            if s.roundWinner(r) == p.id { Image(systemName: "crown.fill").font(.system(size: 11)).foregroundStyle(p.world.color) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            if s.rounds.isEmpty { Text("No rounds yet.").font(.body(13)).foregroundStyle(Theme.ink3) }
        }
        .paperCard(padding: 14)
    }
}
