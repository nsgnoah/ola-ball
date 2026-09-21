import SwiftUI

/// One match. Renders whatever stage the controller says we're in.
struct MatchView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var controller: MatchController

    init(controller: MatchController) {
        _controller = State(initialValue: controller)
    }

    var body: some View {
        // No Stage here on purpose: every screen below brings its own full-bleed Stage. Nesting one
        // Stage inside another clips the inner background to the outer play column, which shows up
        // on an iPad as a seam down both sides of the screen.
        Group {
            switch controller.stage {
            case .setupTeam:
                JoinTeamView(controller: controller) { dismiss() }
            case .handoff(let name):
                HandoffView(name: name) { controller.continueAfterHandoff() }
            case .intro(let round):
                RoundIntroView(controller: controller, round: round)
            case .answering:
                QuestionView(controller: controller)
            case .picking(let round, let target):
                DeckPickView(controller: controller, round: round, target: target)
            case .roundReveal(let round):
                RoundRevealView(controller: controller, round: round)
            case .waiting:
                WaitingView(controller: controller) { dismiss() }
            case .finished:
                MatchOverView(controller: controller) { dismiss() }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { controller.start(announce: true) }
        .animation(.easeOut(duration: 0.25), value: controller.stage)
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
                Glyph(kind: .close, size: 15, weight: 18)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.2), in: Circle())
            }
            .accessibilityIdentifier("close-match")
            .accessibilityLabel("Close match")
            if let mine { side(mine, leading: true) }
            Text("VS").font(.headline(18)).foregroundStyle(Theme.gold)
                .shadow(color: Theme.ink.opacity(0.6), radius: 1, y: 1)
            if let them {
                side(them, leading: false)
            } else {
                Text("Waiting for partner").font(.body(12)).foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private func side(_ p: MatchPlayer, leading: Bool) -> some View {
        HStack(spacing: 6) {
            if leading { SideAvatars(player: p, size: 30) }
            VStack(alignment: leading ? .leading : .trailing, spacing: 1) {
                Text(p.name.uppercased()).font(.label(11)).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                Crowns(count: controller.crowns(p.id), size: 12, empty: .white.opacity(0.5))
            }
            if !leading { SideAvatars(player: p, size: 30) }
        }
        .frame(maxWidth: .infinity, alignment: leading ? .leading : .trailing)
    }
}

struct HandoffView: View {
    let name: String
    let onContinue: () -> Void
    @State private var bounce = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Stage(GameBackground(top: Theme.violet, bottom: Theme.violetDeep)) {
            VStack(spacing: 18) {
                Spacer()
                HandoffIcon(size: 96)
                    .rotationEffect(.degrees(bounce ? 6 : -6))
                    .onAppear { if !reduceMotion { withAnimation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true)) { bounce = true } } }
                Kicker("HAND THE PHONE TO")
                StickerText(name.uppercased(), size: TypeScale.display)
                OlaSays(text: "No peeking. Their questions are next.")
                Spacer()
                Button(name.contains("&") ? "We're ready" : "I'm \(name), let's go") { Haptics.tap(); onContinue() }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.gold))
                    .accessibilityIdentifier("handoff-continue")
            }
            .padding(20)
        }
    }
}

struct RoundIntroView: View {
    let controller: MatchController
    let round: Int

    var body: some View {
        let deck = controller.deck
        Stage(GameBackground(top: deck?.color ?? Theme.violet, bottom: (deck?.color ?? Theme.violet).mix(with: .black, by: 0.35))) {
            VStack(spacing: 14) {
                MatchHeader(controller: controller)
                Spacer()
                if let deck {
                    Mascot(deck: deck, mood: .think, size: 170)
                    if controller.state.mode == .teams, let m = controller.currentMember {
                        StickerText("\(m.name.uppercased()), YOU'RE UP", size: TypeScale.heading, color: Theme.gold)
                    }
                    Kicker("ROUND \(round) OF \(MatchState.maxRounds) · \(MatchEngine.roundLabel(round))")
                    StickerText(deck.title.uppercased(), size: TypeScale.title)
                        .padding(.top, UI.s(-6))
                    OlaSays(text: introLine(deck))
                }
                HStack(spacing: 10) {
                    fact("\(MatchState.questionsPerRound)", "QUESTIONS")
                    fact("\(Int(MatchEngine.secondsPerQuestion))s", "EACH")
                    fact(MatchEngine.tierName(MatchEngine.tiers(forRound: round).max() ?? 1), "TOP TIER")
                }
                Spacer()
                Button("Start round \(round)") { Haptics.heavy(); controller.beginAnswering() }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.gold))
                    .accessibilityIdentifier("start-round")
            }
            .padding(20)
        }
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
        VStack(spacing: 0) {
            Text(v).font(.score(26)).foregroundStyle(Theme.ink)
            Text(l).font(.label(10)).tracking(1).foregroundStyle(Theme.ink2)
        }
        .frame(maxWidth: .infinity)
        .panel(padding: 10, radius: 14)
    }
}

struct WaitingView: View {
    let controller: MatchController
    let onClose: () -> Void
    /// Picked once. Chosen inside `body` it changed on every redraw, so the mascot flickered
    /// through decks whenever anything else on the screen moved.
    @State private var companion = Decks.all.randomElement()
    @State private var confirmLeave = false

    /// The last turn failed to reach Game Center. It is still only on this phone.
    private var unsent: Bool { controller.error != nil }

    var body: some View {
        Stage(GameBackground(top: Theme.violet, bottom: Theme.violetDeep)) {
            VStack(spacing: 16) {
                MatchHeader(controller: controller, onClose: attemptClose)
                Spacer()
                if let companion { Mascot(deck: companion, mood: unsent ? .sad : .think, size: 130) }
                // Saying "their turn" when the upload failed is simply untrue: the move never left
                // this phone. Say what actually happened.
                Kicker(unsent ? "STILL ON THIS PHONE" : "THEIR MOVE")
                StickerText(unsent ? "NOT SENT YET" : "\(controller.partner?.name.uppercased() ?? "YOUR PARTNER")'S TURN", size: TypeScale.title)
                OlaSays(text: unsent
                        ? "Your last turn didn't reach them. Try again when you have a signal."
                        : (controller.transport.isPassAndPlay ? "Hand the phone over when they're ready." : "You'll get a notification when they've played. Go live your life."))
                if let err = controller.error {
                    VStack(spacing: 8) {
                        Text(err).font(.body(13)).foregroundStyle(Theme.gold)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        Button("Try again") { controller.retrySubmit() }
                            .buttonStyle(ChunkyButtonStyle(color: Theme.gold, height: 48, fontSize: 18))
                            .accessibilityIdentifier("retry-submit")
                    }
                    .padding(.horizontal, 8)
                }
                RoundHistory(controller: controller)
                Spacer()
                Button("Back to matches") { attemptClose() }
                    .buttonStyle(ChunkyButtonStyle(color: .white, edge: Theme.panelEdge, ink: Theme.ink))
            }
            .padding(20)
        }
        .confirmationDialog("This round hasn't been sent", isPresented: $confirmLeave, titleVisibility: .visible) {
            Button("Try again") { controller.retrySubmit() }
            Button("Leave and lose it", role: .destructive) { onClose() }
            Button("Stay", role: .cancel) {}
        } message: {
            Text("Your answers are only on this phone. Leaving now means playing the round again.")
        }
    }

    /// Leaving with an unsent turn throws the round away, so say so rather than letting it vanish.
    private func attemptClose() {
        if unsent { confirmLeave = true } else { onClose() }
    }
}

/// The scoreboard of completed rounds.
struct RoundHistory: View {
    let controller: MatchController

    var body: some View {
        let s = controller.state
        VStack(alignment: .leading, spacing: 8) {
            Kicker("SCORECARD", color: Theme.ink2, size: 11)
            ForEach(s.rounds, id: \.number) { r in
                HStack(spacing: 8) {
                    Text("R\(r.number)").font(.label(12)).foregroundStyle(Theme.ink2).frame(width: 28, alignment: .leading)
                    ForEach(s.players) { p in
                        let picked = p.members.contains { r.picks[$0.id] != nil }
                        let done = p.members.allSatisfy { r.results[$0.id] != nil }
                        HStack(spacing: 6) {
                            ForEach(p.members) { m in
                                if let deck = r.picks[m.id].flatMap(Decks.byID) {
                                    DeckIcon(deck: deck, fill: .white, ink: deck.color).frame(width: 16, height: 16)
                                }
                            }
                            Text(done ? "\(r.score(for: p))" : (picked ? "…" : "—")).font(.score(20)).foregroundStyle(Theme.ink)
                            if s.roundWinner(r) == p.id { CrownIcon(size: 15) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            if s.rounds.isEmpty { Text("No rounds yet.").font(.body(13)).foregroundStyle(Theme.ink2) }
        }
        .panel(padding: 14)
    }
}
