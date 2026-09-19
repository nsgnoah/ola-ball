import SwiftUI

struct QuestionView: View {
    let controller: MatchController

    var body: some View {
        let deck = controller.deck
        let color = deck?.color ?? Theme.ink
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                if let deck {
                    Image(systemName: deck.symbol).font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                        .frame(width: 28, height: 28).background(deck.color, in: RoundedRectangle(cornerRadius: 8))
                    Text(deck.title.uppercased()).font(.condensed(13)).tracking(1.5).foregroundStyle(Theme.ink)
                }
                Spacer()
                Text("\(controller.runningScore)").font(.score(22)).foregroundStyle(Theme.ink)
                    .contentTransition(.numericText()).animation(.spring(duration: 0.4), value: controller.runningScore)
                Kicker("PTS", color: Theme.ink3, size: 10)
            }
            progressDots(color: color)
            if !controller.revealed {
                TimerBar(start: controller.questionStart, duration: MatchEngine.secondsPerQuestion, color: color)
            } else {
                Rectangle().fill(Theme.rule).frame(height: 6).clipShape(Capsule())
            }
            if let q = controller.currentQuestion {
                VStack(alignment: .leading, spacing: 6) {
                    Kicker("\(MatchEngine.tierName(q.tier)) · Q\(controller.index + 1) OF \(controller.questions.count)", color: color)
                    Text(q.prompt).font(.headline(30)).foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("question-prompt")
                }
                .padding(.top, 4)
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
                    }
                }
                if controller.revealed {
                    feedback(q)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            Spacer(minLength: 0)
            if controller.revealed {
                Button(controller.index + 1 >= controller.questions.count ? "See the round" : "Next question") {
                    Haptics.tap()
                    controller.nextQuestion()
                }
                .buttonStyle(InkButtonStyle())
                .accessibilityIdentifier("next-question")
            }
        }
        .padding(20)
        .animation(.spring(duration: 0.3), value: controller.revealed)
    }

    private func progressDots(color: Color) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<controller.questions.count, id: \.self) { i in
                let a = i < controller.answers.count ? controller.answers[i] : nil
                let done = i < controller.answers.count
                let right = done && a == controller.questions[i].correctIndex
                Capsule()
                    .fill(done ? (right ? Theme.goodInk : Theme.badInk) : (i == controller.index ? color : Theme.rule))
                    .frame(height: 5)
            }
        }
    }

    private func optionRow(_ i: Int, _ text: String, q: Question) -> some View {
        let isCorrect = i == q.correctIndex
        let isMine = controller.selected == i
        let showState = controller.revealed
        let fill: Color = showState ? (isCorrect ? Theme.goodInk : (isMine ? Theme.badInk : Theme.paperCard)) : Theme.paperCard
        let ink: Color = showState && (isCorrect || isMine) ? .white : Theme.ink
        return HStack(spacing: 12) {
            Text(["A", "B", "C", "D"][i])
                .font(.headline(16))
                .foregroundStyle(showState && (isCorrect || isMine) ? fill : .white)
                .frame(width: 28, height: 28)
                .background(showState && (isCorrect || isMine) ? .white : Theme.ink, in: RoundedRectangle(cornerRadius: 7))
            Text(text).font(.bodyBold(16)).foregroundStyle(ink).multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if showState && isCorrect { Image(systemName: "checkmark.circle.fill").foregroundStyle(.white) }
            if showState && isMine && !isCorrect { Image(systemName: "xmark.circle.fill").foregroundStyle(.white) }
        }
        .padding(.horizontal, 12).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(showState && (isCorrect || isMine) ? .clear : Theme.rule, lineWidth: 1))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 3)
    }

    private func feedback(_ q: Question) -> some View {
        let correct = controller.selected == q.correctIndex
        let timedOut = controller.selected == nil
        return HStack(alignment: .top, spacing: 10) {
            OlaBadge(size: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(timedOut ? "Time!" : (correct ? ["Nailed it.", "Yes.", "Look at you.", "Correct, obviously."].randomElement()! : ["Nope.", "Not that one.", "Close. Not really."].randomElement()!))
                    .font(.headline(20)).foregroundStyle(correct ? Theme.goodInk : Theme.badInk)
                if !correct { Text("Answer: \(q.correct)").font(.bodyBold(14)).foregroundStyle(Theme.ink) }
                if let fact = q.fact { Text(fact).font(.body(13)).foregroundStyle(Theme.ink2).fixedSize(horizontal: false, vertical: true) }
                if correct && controller.streak >= 2 { Kicker("STREAK ×\(controller.streak)", color: Theme.goodInk, size: 11) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard(padding: 12, radius: 12)
    }
}

/// A bar that drains over the question's time limit.
struct TimerBar: View {
    let start: Date
    let duration: Double
    let color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { ctx in
            let elapsed = ctx.date.timeIntervalSince(start)
            let fraction = max(0, min(1, 1 - elapsed / duration))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.rule)
                    Capsule().fill(fraction < 0.25 ? Theme.badInk : color).frame(width: geo.size.width * fraction)
                }
            }
            .frame(height: 6)
        }
    }
}
