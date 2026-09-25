import SwiftUI

struct QuestionView: View {
    let controller: MatchController
    @State private var shakeAmount: CGFloat = 0
    @State private var confetti = false
    @State private var pop = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let deck = controller.deck
        let color = deck?.color ?? Theme.violet
        Stage(GameBackground(top: color, bottom: color.mix(with: .black, by: 0.4))) {
            ScrollViewReader { scroll in
                PinnedColumn(spacing: 12) {
                    header(deck: deck)
                    progressDots
                } middle: {
                    if let q = controller.currentQuestion, let deck {
                        questionCard(q, deck: deck).id(ScrollMark.card)
                        VStack(spacing: 10) {
                            ForEach(Array(q.options.enumerated()), id: \.offset) { i, option in
                                Button {
                                    controller.select(i)
                                } label: {
                                    optionRow(i, option, q: q)
                                }
                                .buttonStyle(.plain)
                                .allowsHitTesting(!controller.revealed)
                                .accessibilityIdentifier("option-\(i)")
                                .modifier(Shake(animatableData: (controller.revealed && controller.selected == i && i != q.correctIndex) ? shakeAmount : 0))
                            }
                        }
                        if controller.revealed {
                            feedback(q).id(ScrollMark.verdict).transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                } bottom: {
                    if controller.revealed {
                        Button(controller.index + 1 >= controller.questions.count ? "See the round" : "Next question") {
                            Haptics.tap()
                            controller.nextQuestion()
                        }
                        .buttonStyle(ChunkyButtonStyle(color: Theme.gold))
                        .accessibilityIdentifier("next-question")
                    }
                }
                .padding(20)
                // Only moves on a screen too short for the whole question. Ola's verdict lands under
                // the options, out of sight there, so a reveal scrolls down to it; each new question
                // starts back at the top. Where everything fits there is nowhere to scroll.
                .onChange(of: controller.revealed) { _, revealed in
                    guard revealed else { return }
                    // After the reveal's own spring: while it runs the content is still growing
                    // and there is nothing below to scroll to yet.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation(reduceMotion ? nil : .spring(duration: 0.4)) { scroll.scrollTo(ScrollMark.verdict, anchor: .bottom) }
                    }
                }
                .onChange(of: controller.index) { scroll.scrollTo(ScrollMark.card, anchor: .top) }
            }
            if confetti { ConfettiBurst().transition(.opacity) }
        }
        .animation(.spring(duration: 0.3), value: controller.revealed)
        .onChange(of: controller.revealed) { _, revealed in
            guard revealed, let q = controller.currentQuestion else { return }
            if controller.selected == q.correctIndex {
                withAnimation { confetti = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { withAnimation { confetti = false } }
            } else {
                withAnimation(.linear(duration: 0.45)) { shakeAmount = 1 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { shakeAmount = 0 }
            }
        }
    }

    private enum ScrollMark: Hashable { case card, verdict }

    // MARK: Pieces

    private func header(deck: Deck?) -> some View {
        HStack(spacing: 10) {
            if let deck {
                HStack(spacing: 8) {
                    DeckIcon(deck: deck, fill: .white, ink: deck.color).padding(4)
                        .frame(width: UI.s(26), height: UI.s(26)).background(.white, in: Circle())
                    Text(controller.state.mode == .teams ? (controller.currentMember?.name.uppercased() ?? "") : deck.title.uppercased())
                        .font(.label(TypeScale.label)).tracking(0.8).foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.7)
                }
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(controller.runningScore)").font(.score(26)).foregroundStyle(Theme.ink)
                    .contentTransition(.numericText()).animation(.spring(duration: 0.4), value: controller.runningScore)
                Text("PTS").font(.label(10)).foregroundStyle(Theme.ink2)
            }
            .padding(.horizontal, UI.s(12)).frame(height: UI.s(34))
            .background(.white, in: Capsule())
            .background(Capsule().fill(Theme.panelEdge).offset(y: 3))
        }
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<controller.questions.count, id: \.self) { i in
                let a = i < controller.answers.count ? controller.answers[i] : nil
                let done = i < controller.answers.count
                let right = done && a == controller.questions[i].correctIndex
                Capsule()
                    .fill(done ? (right ? Theme.good : Theme.bad) : (i == controller.index ? .white : .white.opacity(0.3)))
                    .frame(height: 6)
            }
        }
    }

    /// The question card with the mascot peeking over its top edge and the timer on its corner.
    private func questionCard(_ q: Question, deck: Deck) -> some View {
        ZStack(alignment: .top) {
            VStack(spacing: 8) {
                Kicker("\(MatchEngine.tierName(q.tier)) · \(controller.index + 1) of \(controller.questions.count)", color: Art.darker(deck.color, 0.5), size: 12)   // the deck colour itself is too pale on cream
                Text(q.prompt).font(.headline(TypeScale.heading)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("question-prompt")
            }
            .padding(.horizontal, UI.s(18))
            .padding(.top, UI.s(50))          // clearance for the mascot peeking over the card
            .padding(.bottom, UI.s(18))
            .frame(maxWidth: .infinity)
            .panel(padding: 0)
            .padding(.top, UI.s(56))

            Mascot(deck: deck, mood: mascotMood, size: 84)
                .id("\(controller.index)-\(mascotMood == .happy)-\(mascotMood == .sad)")
        }
        .overlay(alignment: .topTrailing) {
            Group {
                if controller.revealed {
                    resultStamp
                } else {
                    TimerRing(start: controller.questionStart, duration: MatchEngine.secondsPerQuestion, size: 54, color: deck.color)
                }
            }
            .offset(x: UI.s(-6), y: UI.s(30))
        }
    }

    private var mascotMood: Mascot.Mood {
        guard controller.revealed, let q = controller.currentQuestion else { return .think }
        return controller.selected == q.correctIndex ? .happy : .sad
    }

    private var resultStamp: some View {
        let correct = controller.selected == controller.currentQuestion?.correctIndex
        return Text(correct ? "+\(lastPoints)" : "✕")
            .font(.score(24))
            .foregroundStyle(.white)
            .padding(.horizontal, UI.s(12)).frame(height: UI.s(40))
            .background(correct ? Theme.good : Theme.bad, in: Capsule())
            .background(Capsule().fill((correct ? Theme.goodDeep : Theme.badDeep)).offset(y: 3))
            .rotationEffect(.degrees(correct ? -6 : 6))
            .scaleEffect(pop ? 1 : 0.4)
            .onAppear { withAnimation(.spring(duration: 0.35, bounce: 0.5)) { pop = true } }
            .onDisappear { pop = false }
    }

    private var lastPoints: Int {
        guard let q = controller.currentQuestion, controller.index < controller.timesMs.count else { return 0 }
        return MatchEngine.points(correct: controller.selected == q.correctIndex, elapsedMs: controller.timesMs[controller.index], streak: controller.streak)
    }

    private func optionRow(_ i: Int, _ text: String, q: Question) -> some View {
        let isCorrect = i == q.correctIndex
        let isMine = controller.selected == i
        let showState = controller.revealed
        let lit = showState && (isCorrect || isMine)
        let face: Color = lit ? (isCorrect ? Theme.good : Theme.bad) : .white
        let edge: Color = lit ? (isCorrect ? Theme.goodDeep : Theme.badDeep) : Theme.panelEdge
        let ink: Color = lit ? .white : Theme.ink
        return HStack(spacing: 12) {
            Text(["A", "B", "C", "D"][i])
                .font(.headline(18))
                .foregroundStyle(lit ? face : Theme.ink)
                .frame(width: UI.s(34), height: UI.s(34))
                .background(lit ? .white : Theme.cream, in: Circle())
            Text(text).font(.bodyBold(18)).foregroundStyle(ink).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if lit {
                Glyph(kind: isCorrect ? .check : .close, size: 16, weight: 18)
            }
        }
        .padding(.horizontal, UI.s(12)).padding(.vertical, UI.s(12))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(edge).offset(y: 5)
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(face)
            }
        )
    }

    private func feedback(_ q: Question) -> some View {
        let correct = controller.selected == q.correctIndex
        let timedOut = controller.selected == nil
        let line = timedOut ? "Time!" : (correct ? ["Nailed it.", "Yes.", "Look at you.", "Correct, obviously."].randomElement()! : ["Nope.", "Not that one.", "Close. Not really."].randomElement()!)
        var text = line
        if !correct { text += " It's \(q.correct)." }
        if let fact = q.fact { text += " \(fact)" }
        if correct && controller.streak >= 2 { text += " Streak ×\(controller.streak)!" }
        return OlaSays(text: text)
    }
}
