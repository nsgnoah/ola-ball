import SwiftUI

struct QuestionView: View {
    let controller: MatchController
    @State private var shakeAmount: CGFloat = 0
    @State private var confetti = false
    @State private var pop = false

    var body: some View {
        let deck = controller.deck
        let color = deck?.color ?? Theme.violet
        ZStack {
            GameBackground(top: color, bottom: color.mix(with: .black, by: 0.4))
            VStack(spacing: 12) {
                // Header row: deck, score
                HStack(spacing: 10) {
                    if let deck {
                        Text(((controller.state.mode == .teams ? (controller.currentMember?.name.uppercased() ?? "") + " · " : "") + deck.title.uppercased()))
                            .font(.label(13)).tracking(1).foregroundStyle(.white.opacity(0.9)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(controller.runningScore)").font(.score(28)).foregroundStyle(.white)
                            .contentTransition(.numericText()).animation(.spring(duration: 0.4), value: controller.runningScore)
                        Kicker("PTS", size: 10)
                    }
                }
                progressDots
                // Mascot + timer
                HStack(alignment: .center, spacing: 12) {
                    if let deck {
                        Mascot(deck: deck, mood: mascotMood, size: 92)
                            .id("\(controller.index)-\(mascotMood == .happy)-\(mascotMood == .sad)")
                    }
                    Spacer()
                    if let q = controller.currentQuestion {
                        VStack(alignment: .trailing, spacing: 4) {
                            Kicker("\(MatchEngine.tierName(q.tier)) · Q\(controller.index + 1) OF \(controller.questions.count)", size: 11)
                            if !controller.revealed {
                                TimerRing(start: controller.questionStart, duration: MatchEngine.secondsPerQuestion, size: 62, color: Theme.gold)
                            } else {
                                resultStamp
                            }
                        }
                    }
                }
                .frame(height: 96)

                if let q = controller.currentQuestion {
                    Text(q.prompt).font(.headline(26)).foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .panel(padding: 16)
                        .accessibilityIdentifier("question-prompt")
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
                        feedback(q).transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                Spacer(minLength: 0)
                if controller.revealed {
                    Button(controller.index + 1 >= controller.questions.count ? "See the round" : "Next question") {
                        Haptics.tap()
                        controller.nextQuestion()
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.gold))
                    .accessibilityIdentifier("next-question")
                }
            }
            .padding(18)
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

    private var mascotMood: Mascot.Mood {
        guard controller.revealed, let q = controller.currentQuestion else { return .think }
        return controller.selected == q.correctIndex ? .happy : .sad
    }

    private var resultStamp: some View {
        let correct = controller.selected == controller.currentQuestion?.correctIndex
        return Text(correct ? "+\(lastPoints)" : "✕")
            .font(.score(30))
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 4)
            .background(correct ? Theme.good : Theme.bad, in: Capsule())
            .rotationEffect(.degrees(correct ? -6 : 6))
            .scaleEffect(pop ? 1 : 0.4)
            .onAppear { withAnimation(.spring(duration: 0.35, bounce: 0.5)) { pop = true } }
            .onDisappear { pop = false }
    }

    private var lastPoints: Int {
        guard let q = controller.currentQuestion, controller.index < controller.timesMs.count else { return 0 }
        return MatchEngine.points(correct: controller.selected == q.correctIndex, elapsedMs: controller.timesMs[controller.index], streak: controller.streak)
    }

    private var progressDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<controller.questions.count, id: \.self) { i in
                let a = i < controller.answers.count ? controller.answers[i] : nil
                let done = i < controller.answers.count
                let right = done && a == controller.questions[i].correctIndex
                Capsule()
                    .fill(done ? (right ? Theme.good : Theme.bad) : (i == controller.index ? .white : .white.opacity(0.3)))
                    .frame(height: 7)
            }
        }
    }

    private func optionRow(_ i: Int, _ text: String, q: Question) -> some View {
        let isCorrect = i == q.correctIndex
        let isMine = controller.selected == i
        let showState = controller.revealed
        let face: Color = showState ? (isCorrect ? Theme.good : (isMine ? Theme.bad : .white)) : .white
        let edge: Color = showState ? (isCorrect ? Theme.goodDeep : (isMine ? Theme.badDeep : Theme.panelEdge)) : Theme.panelEdge
        let ink: Color = showState && (isCorrect || isMine) ? .white : Theme.ink
        return HStack(spacing: 12) {
            Text(["A", "B", "C", "D"][i])
                .font(.headline(18))
                .foregroundStyle(showState && (isCorrect || isMine) ? face : .white)
                .frame(width: 30, height: 30)
                .background(showState && (isCorrect || isMine) ? .white : Theme.violet, in: RoundedRectangle(cornerRadius: 9))
            Text(text).font(.bodyBold(16)).foregroundStyle(ink).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if showState && isCorrect { Image(systemName: "checkmark.circle.fill").font(.system(size: 20, weight: .black)).foregroundStyle(.white) }
            if showState && isMine && !isCorrect { Image(systemName: "xmark.circle.fill").font(.system(size: 20, weight: .black)).foregroundStyle(.white) }
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
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
