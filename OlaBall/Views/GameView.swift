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
            FieldSceneView(session: session)
                .ignoresSafeArea()
                .id(ObjectIdentifier(session))

            VStack(spacing: 0) {
                topBar.padding(.horizontal).padding(.top, 4)
                ScoreboardView(session: session).padding(.horizontal).padding(.top, 6)
                Spacer()
                bottomPanel
                    .padding(.horizontal)
                    .padding(.bottom, 10)
            }

            if session.phase == .gameOver {
                gameOverOverlay
            }

            if showConfetti {
                ConfettiView().allowsHitTesting(false).transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: session.phase)
        .onChange(of: session.lastPlay?.id) { _, _ in
            guard let play = session.lastPlay else { return }
            let userScored = play.ending == .touchdown && session.userOnOffense
            let userTakeaway = (play.ending?.isTurnover ?? false) && !session.userOnOffense
            if userScored || userTakeaway { celebrate() }
        }
        .confirmationDialog("Leave this game?", isPresented: $showQuitConfirm, titleVisibility: .visible) {
            Button("Leave game", role: .destructive) { dismiss() }
            Button("Keep playing", role: .cancel) {}
        } message: {
            Text("Progress from an unfinished game isn't saved.")
        }
    }

    // MARK: Chrome

    private var topBar: some View {
        HStack {
            Button {
                if session.phase == .gameOver { dismiss() } else { showQuitConfirm = true }
            } label: {
                Image(systemName: "xmark").font(.label(14)).foregroundStyle(Theme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Theme.card.opacity(0.9), in: Circle())
            }
            .accessibilityIdentifier("close-game")
            Spacer()
            if session.phase == .live {
                Text("LIVE").font(.label(12)).foregroundStyle(.white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Theme.bad, in: Capsule())
            } else {
                Text(session.userOnOffense ? "YOUR BALL" : "YOUR DEFENSE").font(.label(12))
                    .foregroundStyle(session.userOnOffense ? Theme.gold : Theme.good)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Theme.card.opacity(0.9), in: Capsule())
            }
            Spacer()
            Color.clear.frame(width: 36, height: 36)
        }
    }

    // MARK: Bottom panel

    @ViewBuilder
    private var bottomPanel: some View {
        switch session.phase {
        case .presnap:
            presnapPanel
        case .live:
            situationPill
        case .result:
            resultPanel
        case .kicking(let kind):
            kickPanel(kind)
        case .driveOver:
            driveOverPanel
        case .gameOver:
            EmptyView()
        }
    }

    private var situationPill: some View {
        Text(session.situationText)
            .font(.label(13)).foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 14).padding(.vertical, 8)
            .background(Theme.card.opacity(0.92), in: Capsule())
            .accessibilityIdentifier("situation")
    }

    private var presnapPanel: some View {
        VStack(spacing: 10) {
            if let tip = session.tip {
                TipCardView(concept: tip, isNew: true) { session.dismissTip() }
            }
            situationPill
            if session.userOnOffense {
                VStack(spacing: 6) {
                    Label(session.defenseCall.callout, systemImage: "eye.fill")
                        .font(.label(13)).foregroundStyle(Theme.gold)
                    Text(session.drawHint)
                        .font(.body(14)).foregroundStyle(Theme.textPrimary)
                        .accessibilityIdentifier("draw-hint")
                }
                .padding(.vertical, 10).padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .background(Theme.card.opacity(0.92), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                if session.isFourthDown {
                    HStack(spacing: 10) {
                        Button {
                            Haptics.tap(); session.beginKick(.punt)
                        } label: {
                            Label("Punt", systemImage: "arrow.up.to.line")
                        }
                        .buttonStyle(BigButtonStyle(fill: Theme.card, foreground: Theme.textPrimary))
                        .accessibilityIdentifier("kick-punt")
                        if session.situation.canAttemptFieldGoal {
                            Button {
                                Haptics.tap(); session.beginKick(.fieldGoal)
                            } label: {
                                Label("Field Goal · \(session.situation.fieldGoalDistance) yds", systemImage: "target")
                            }
                            .buttonStyle(BigButtonStyle())
                            .accessibilityIdentifier("kick-fieldGoal")
                        }
                    }
                }
            } else {
                DefenseCallView(session: session)
            }
        }
    }

    private var resultPanel: some View {
        VStack(spacing: 10) {
            if let verdict = session.lastVerdict {
                VStack(spacing: 6) {
                    Text(verdict.headline)
                        .font(.display(session.lastPlay?.ending != nil ? 32 : 26))
                        .foregroundStyle(headlineColor(verdict))
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("result-headline")
                    Text(verdict.why)
                        .font(.body(15)).foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 12).padding(.horizontal, 14)
                .frame(maxWidth: .infinity)
                .background(Theme.card.opacity(0.94), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            if let tip = session.tip {
                TipCardView(concept: tip, isNew: true) { session.dismissTip() }
            }
            Text(session.tip == nil ? "Tap to continue" : "Tap ✕ or anywhere to continue")
                .font(.label(12)).foregroundStyle(Theme.textSecondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if session.tip != nil { session.dismissTip() }
            session.skipResult()
        }
    }

    private func headlineColor(_ v: PlayAnalyst.Verdict) -> Color {
        // Color from the user's point of view
        let goodForUser = session.userOnOffense ? v.good : v.bad
        let badForUser = session.userOnOffense ? v.bad : v.good
        if goodForUser { return session.lastPlay?.ending?.isScore == true && session.userOnOffense ? Theme.gold : Theme.good }
        if badForUser { return Theme.bad }
        return Theme.textPrimary
    }

    private func kickPanel(_ kind: PlayCall) -> some View {
        let s = session.situation
        let isFG = kind == .fieldGoal
        let width = isFG ? Kicking.meterTargetWidth(distance: s.fieldGoalDistance) : 0.3
        let title = isFG ? "\(s.fieldGoalDistance)-yard field goal" : "Punt"
        let subtitle = isFG ? "Tap KICK when the needle is in the green. This one is \(Kicking.oddsText(distance: s.fieldGoalDistance))." : "Tap in the green for a long punt. Anywhere else still gets it away."
        return KickMeterView(title: title, subtitle: subtitle, targetWidth: width) { accuracy in
            session.userKick(kind, accuracy: accuracy)
        }
    }

    private var driveOverPanel: some View {
        VStack(spacing: 8) {
            if let ending = session.driveEnding {
                Text(driveTitle(ending)).font(.display(24)).foregroundStyle(driveColor(ending))
                Text(driveSubtitle(ending)).font(.body(14)).foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Tap to continue").font(.label(12)).foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, 14).padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(Theme.card.opacity(0.94), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .contentShape(Rectangle())
        .onTapGesture { session.skipResult() }
        .accessibilityIdentifier("drive-over")
    }

    private func driveColor(_ ending: DriveEnding) -> Color {
        if session.userOnOffense { return ending.isScore ? Theme.gold : Theme.textPrimary }
        return ending.isScore ? Theme.bad : Theme.good
    }

    private func driveTitle(_ ending: DriveEnding) -> String {
        let them = session.opponentTeam.name
        if session.userOnOffense {
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
        switch ending {
        case .touchdown: return "The \(them) score. +7 for them"
        case .fieldGoal: return "They kick a field goal. +3"
        case .missedFieldGoal: return "They missed!"
        case .punt: return "Your defense held. They punt"
        case .turnoverOnDowns: return "Huge stop on 4th down!"
        case .interception: return "INTERCEPTION! Your ball"
        case .fumble: return "FUMBLE! Your ball"
        }
    }

    private func driveSubtitle(_ ending: DriveEnding) -> String {
        let them = session.opponentTeam.name
        if session.userOnOffense {
            switch ending {
            case .touchdown, .fieldGoal: return "You kick off. The \(them) start at their 25. Now pick your defense."
            case .missedFieldGoal: return "The \(them) take over where the kick was attempted."
            case .punt: return "The \(them) take over deep in their own territory."
            default: return "The \(them) take over right there. Time for your defense."
            }
        }
        switch ending {
        case .touchdown, .fieldGoal: return "Your turn to answer. You start at your 25."
        default: return "Your ball. Go make something happen."
        }
    }

    private var gameOverOverlay: some View {
        ZStack {
            Theme.background.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 0) {
                Color.clear.frame(height: 60)
                GameOverView(session: session, onPlayAgain: playAgain, onHome: { dismiss() })
                    .padding(.horizontal)
            }
        }
        .transition(.opacity)
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
        session = GameSession(userTeam: session.userTeam, opponentTeam: opponent, store: store, autoplay: session.autoplay)
    }
}

struct DefenseCallView: View {
    let session: GameSession
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 8) {
            Text("Their ball. Pick your defense:")
                .font(.display(16)).foregroundStyle(Theme.textPrimary)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(DefenseCall.allCases) { call in
                    Button {
                        Haptics.tap()
                        session.chooseDefense(call)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: call.symbol).foregroundStyle(Theme.good)
                                Text(call.title).font(.display(15)).foregroundStyle(Theme.textPrimary)
                            }
                            Text(call.subtitle).font(.body(12)).foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
                        .background(Theme.card.opacity(0.94), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("defense-\(call.rawValue)")
                }
            }
        }
    }
}
