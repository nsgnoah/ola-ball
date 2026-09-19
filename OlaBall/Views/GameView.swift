import SwiftUI

struct GameView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ProgressStore.self) private var store
    @State private var session: GameSession
    @State private var showConfetti = false
    @State private var showQuitConfirm = false

    init(session: GameSession) {
        _session = State(initialValue: session)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 12) {
                topBar
                ScoreboardView(session: session)
                FieldView(ballX: session.fieldState.ballX,
                          firstDownX: session.fieldState.firstDownX,
                          userTeam: session.userTeam,
                          opponentTeam: session.opponentTeam,
                          possessor: session.fieldState.possessor)
                    .frame(height: 110)
                Text(session.situationText)
                    .font(.label(13)).foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal)
            .padding(.bottom, 8)

            if showConfetti {
                ConfettiView().allowsHitTesting(false).transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.18), value: session.phase)
        .onChange(of: session.lastPlay?.id) { _, _ in
            guard let play = session.lastPlay else { return }
            if play.ending == .touchdown { celebrate() }
            else if play.isBadForOffense { Haptics.failure() }
            else if play.isGoodForOffense { Haptics.success() }
        }
        .onChange(of: session.opponentRevealed) { _, _ in
            guard let last = session.revealedOpponentPlays.last else { return }
            if last.ending?.isScore == true { Haptics.failure() }
            else if last.ending?.isTurnover == true { celebrate() }
        }
        .confirmationDialog("Leave this game?", isPresented: $showQuitConfirm, titleVisibility: .visible) {
            Button("Leave game", role: .destructive) { dismiss() }
            Button("Keep playing", role: .cancel) {}
        } message: {
            Text("Progress from an unfinished game isn't saved.")
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                if session.phase == .gameOver { dismiss() } else { showQuitConfirm = true }
            } label: {
                Image(systemName: "xmark").font(.label(14)).foregroundStyle(Theme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Theme.card, in: Circle())
            }
            Spacer()
            Text("Call the Shots").font(.label(13)).foregroundStyle(Theme.gold)
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch session.phase {
        case .choosing:
            choosing
        case .result:
            result
        case .driveOver:
            driveOver
        case .opponentDrive:
            OpponentDriveView(session: session)
        case .gameOver:
            GameOverView(session: session, onPlayAgain: playAgain, onHome: { dismiss() })
        }
    }

    private var choosing: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 12) {
                if let tip = session.tip {
                    TipCardView(concept: tip, isNew: session.newlyLearned.contains(tip)) { session.dismissTip() }
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Text(session.situation.down == 4 ? "4th down. What's the call, coach?" : "What's the call, coach?")
                    .font(.display(20)).foregroundStyle(Theme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(session.availableCalls) { call in
                    CallButton(call: call, situation: session.situation) {
                        session.call(call)
                    }
                }
            }
        }
    }

    private var result: some View {
        VStack(spacing: 14) {
            if let play = session.lastPlay {
                VStack(spacing: 8) {
                    Text(play.headline)
                        .font(.display(play.ending != nil ? 34 : 28))
                        .foregroundStyle(play.isBadForOffense ? Theme.bad : (play.isGoodForOffense ? Theme.good : Theme.textPrimary))
                        .multilineTextAlignment(.center)
                    Text(play.narration)
                        .font(.body(16)).foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .card()

                if let tip = session.tip {
                    TipCardView(concept: tip, isNew: session.newlyLearned.contains(tip)) { session.dismissTip() }
                }
            }
            Spacer(minLength: 0)
            Button(session.driveEnding == nil ? "Next play" : "Continue") {
                Haptics.tap()
                session.next()
            }
            .buttonStyle(BigButtonStyle())
        }
    }

    private var driveOver: some View {
        VStack(spacing: 14) {
            if let ending = session.driveEnding {
                VStack(spacing: 10) {
                    Text(driveTitle(ending)).font(.display(26)).foregroundStyle(ending.isScore ? Theme.gold : Theme.textPrimary)
                    Text(driveSubtitle(ending)).font(.body(15)).foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 18) {
                        miniStat("\(session.drivePlays.count)", "plays")
                        miniStat("\(session.drivePlays.reduce(0) { $0 + $1.yards })", "yards")
                        miniStat("\(session.drivePlays.filter(\.gainedFirstDown).count)", "first downs")
                    }
                    .padding(.top, 4)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .card()
            }
            Spacer(minLength: 0)
            Button("Now the other team's turn") {
                Haptics.tap()
                session.continueAfterDrive()
            }
            .buttonStyle(BigButtonStyle())
        }
    }

    private func miniStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.display(20)).foregroundStyle(Theme.textPrimary)
            Text(label).font(.label(11)).foregroundStyle(Theme.textSecondary)
        }
    }

    private func driveTitle(_ ending: DriveEnding) -> String {
        switch ending {
        case .touchdown: return "Touchdown drive! +7"
        case .fieldGoal: return "Field goal. +3"
        case .missedFieldGoal: return "Missed kick"
        case .punt: return "Punted it away"
        case .turnoverOnDowns: return "Came up short"
        case .interception: return "Intercepted"
        case .fumble: return "Fumbled it away"
        }
    }

    private func driveSubtitle(_ ending: DriveEnding) -> String {
        let them = session.opponentTeam.name
        switch ending {
        case .touchdown, .fieldGoal: return "You kick off. The \(them) start their drive at their 25."
        case .missedFieldGoal: return "The \(them) take over where the kick was attempted."
        case .punt: return "The \(them) take over deep in their own territory."
        case .turnoverOnDowns, .interception, .fumble: return "The \(them) take over right there. Time for your defense to step up."
        }
    }

    private func celebrate() {
        Haptics.success()
        withAnimation { showConfetti = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation { showConfetti = false }
        }
    }

    private func playAgain() {
        var rng = SystemRandomNumberGenerator()
        let opponent = Team.randomOpponent(for: session.userTeam, using: &rng)
        session = GameSession(userTeam: session.userTeam, opponentTeam: opponent, store: store)
    }
}
