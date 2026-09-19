import SwiftUI

struct OpponentDriveView: View {
    let session: GameSession

    var body: some View {
        VStack(spacing: 12) {
            if let tip = session.tip {
                TipCardView(concept: tip, isNew: session.newlyLearned.contains(tip)) { session.dismissTip() }
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(session.opponentTeam.emoji) \(session.opponentTeam.name) have the ball")
                        .font(.display(17)).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("Your defense").font(.label(11)).foregroundStyle(Theme.textSecondary)
                }
                if session.revealedOpponentPlays.isEmpty {
                    Text("They start at their own \(session.opponentDrive?.startBallOn ?? 25). Tap to watch each play.")
                        .font(.body(15)).foregroundStyle(Theme.textSecondary)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(Array(session.revealedOpponentPlays.enumerated()), id: \.element.id) { index, play in
                                    let isLast = index == session.revealedOpponentPlays.count - 1
                                    HStack(alignment: .top, spacing: 8) {
                                        Text(play.before.downAndDistance)
                                            .font(.label(11)).foregroundStyle(Theme.textSecondary)
                                            .frame(width: 58, alignment: .leading)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(opponentHeadline(play))
                                                .font(.label(14))
                                                .foregroundStyle(play.isBadForOffense ? Theme.good : (play.isGoodForOffense ? Theme.bad : Theme.textPrimary))
                                            if isLast {
                                                Text(play.narration).font(.body(14)).foregroundStyle(Theme.textSecondary)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                        }
                                    }
                                    .id(play.id)
                                    .opacity(isLast ? 1 : 0.6)
                                }
                            }
                        }
                        .frame(maxHeight: 190)
                        .onChange(of: session.opponentRevealed) { _, _ in
                            if let last = session.revealedOpponentPlays.last {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()

            Spacer(minLength: 0)

            if session.opponentDriveFullyRevealed, let drive = session.opponentDrive {
                Text(endingText(drive.ending))
                    .font(.display(18))
                    .foregroundStyle(drive.ending.isScore ? Theme.bad : Theme.good)
                    .multilineTextAlignment(.center)
                Button("Your ball") {
                    Haptics.tap()
                    session.continueAfterDrive()
                }
                .buttonStyle(BigButtonStyle())
            } else {
                HStack(spacing: 10) {
                    Button("Skip to result") {
                        session.skipOpponentDrive()
                    }
                    .buttonStyle(BigButtonStyle(fill: Theme.card, foreground: Theme.textPrimary))
                    .frame(maxWidth: 150)
                    Button("Next play") {
                        Haptics.tap()
                        session.revealNextOpponentPlay()
                    }
                    .buttonStyle(BigButtonStyle())
                }
            }
        }
    }

    private func opponentHeadline(_ play: Play) -> String {
        if let ending = play.ending {
            switch ending {
            case .touchdown: return "They score a touchdown. +7"
            case .fieldGoal: return "Field goal is good. +3"
            case .missedFieldGoal: return "Field goal missed!"
            case .punt: return "They punt"
            case .turnoverOnDowns: return "Stopped on 4th down!"
            case .interception: return "INTERCEPTION! Your defense takes it"
            case .fumble: return "FUMBLE! Your defense recovers"
            }
        }
        if play.gainedFirstDown { return "\(play.call.title), +\(play.yards). First down." }
        switch play.result {
        case .incomplete: return "Pass incomplete"
        case .sack(let l): return "Sacked for −\(l)!"
        default:
            let y = play.yards
            return "\(play.call.title), \(y >= 0 ? "+\(y)" : "−\(-y)")"
        }
    }

    private func endingText(_ ending: DriveEnding) -> String {
        switch ending {
        case .touchdown: return "They scored. Your turn to answer."
        case .fieldGoal: return "They got 3. Your turn."
        case .missedFieldGoal: return "Missed! Great break for you."
        case .punt: return "Your defense held. They punt."
        case .turnoverOnDowns: return "Huge stop on 4th down!"
        case .interception, .fumble: return "Turnover! Your defense came up big."
        }
    }
}
