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
                ScoreBug(session: session) {
                    if session.phase == .gameOver { dismiss() } else { showQuitConfirm = true }
                }
                .padding(.horizontal, 12)
                .padding(.top, 2)
                Spacer()
                bottomPanel
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }

            if session.phase == .gameOver {
                gameOverOverlay
            }

            if showConfetti {
                ConfettiView().allowsHitTesting(false).transition(.opacity)
            }
        }
        .preferredColorScheme(.dark)
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

    // MARK: Bottom panel

    @ViewBuilder
    private var bottomPanel: some View {
        switch session.phase {
        case .presnap:
            presnapPanel
        case .live:
            EmptyView()
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

    private var presnapPanel: some View {
        VStack(spacing: 8) {
            if let tip = session.tip {
                TipCardView(concept: tip, isNew: true) { session.dismissTip() }
            }
            if session.userOnOffense {
                BroadcastPanel(accent: Theme.gold) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "eye.fill").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.gold)
                            Kicker(session.defenseCall.callout.uppercased())
                        }
                        Text(session.drawHint)
                            .font(.body(15))
                            .foregroundStyle(.white)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("draw-hint")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
                .allowsHitTesting(false)
                if session.isFourthDown {
                    HStack(spacing: 8) {
                        Button {
                            Haptics.tap(); session.beginKick(.punt)
                        } label: {
                            Label("Punt", systemImage: "arrow.up.to.line")
                        }
                        .buttonStyle(BroadcastButtonStyle(fill: Color.black.opacity(0.55), ink: .white, prominent: false))
                        .accessibilityIdentifier("kick-punt")
                        if session.situation.canAttemptFieldGoal {
                            Button {
                                Haptics.tap(); session.beginKick(.fieldGoal)
                            } label: {
                                Label("Field goal · \(session.situation.fieldGoalDistance) yds", systemImage: "target")
                            }
                            .buttonStyle(BroadcastButtonStyle())
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
        VStack(spacing: 8) {
            if let verdict = session.lastVerdict {
                PaperPanel(accent: headlineColor(verdict)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verdict.headline)
                            .font(.headline(session.lastPlay?.ending != nil ? 40 : 34))
                            .foregroundStyle(headlineColor(verdict))
                            .accessibilityIdentifier("result-headline")
                        Text(verdict.why)
                            .font(.body(15))
                            .foregroundStyle(Theme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
            }
            if let tip = session.tip {
                TipCardView(concept: tip, isNew: true) { session.dismissTip() }
            }
            Kicker(session.tip == nil ? "TAP TO CONTINUE" : "TAP ✕ OR ANYWHERE TO CONTINUE", color: .white.opacity(0.75), size: 11)
                .padding(.top, 2)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if session.tip != nil { session.dismissTip() }
            session.skipResult()
        }
    }

    private func headlineColor(_ v: PlayAnalyst.Verdict) -> Color {
        let goodForUser = session.userOnOffense ? v.good : v.bad
        let badForUser = session.userOnOffense ? v.bad : v.good
        if goodForUser { return session.lastPlay?.ending?.isScore == true && session.userOnOffense ? Theme.gold : Theme.goodInk }
        if badForUser { return Theme.badInk }
        return Theme.ink
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
        VStack(spacing: 6) {
            if let ending = session.driveEnding {
                PaperPanel(accent: driveColor(ending)) {
                    VStack(alignment: .leading, spacing: 4) {
                        Kicker("DRIVE OVER", color: Theme.ink3)
                        Text(driveTitle(ending)).font(.headline(32)).foregroundStyle(driveColor(ending))
                        Text(driveSubtitle(ending)).font(.body(14)).foregroundStyle(Theme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                }
            }
            Kicker("TAP TO CONTINUE", color: .white.opacity(0.75), size: 11)
        }
        .contentShape(Rectangle())
        .onTapGesture { session.skipResult() }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("drive-over")
    }

    private func driveColor(_ ending: DriveEnding) -> Color {
        if session.userOnOffense { return ending.isScore ? Theme.gold : Theme.ink }
        return ending.isScore ? Theme.badInk : Theme.goodInk
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
            Theme.background.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 0) {
                Color.clear.frame(height: 90)
                GameOverView(session: session, onPlayAgain: playAgain, onHome: { dismiss() })
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.paper, in: UnevenRoundedRectangle(topLeadingRadius: 28, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 28, style: .continuous))
                    .ignoresSafeArea(edges: .bottom)
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
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
    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Kicker("THEIR BALL", color: Theme.bad)
                Text("Pick your defense").font(.headline(20)).foregroundStyle(.white)
                Spacer()
            }
            .padding(.horizontal, 4)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(DefenseCall.allCases) { call in
                    Button {
                        Haptics.tap()
                        session.chooseDefense(call)
                    } label: {
                        PaperPanel(accent: Theme.goodInk) {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Image(systemName: call.symbol).font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.goodInk)
                                    Text(call.title.uppercased()).font(.headline(18)).foregroundStyle(Theme.ink)
                                        .lineLimit(1).minimumScaleFactor(0.8)
                                }
                                Text(call.subtitle).font(.body(12)).foregroundStyle(Theme.ink2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(minHeight: 84, alignment: .topLeading)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("defense-\(call.rawValue)")
                }
            }
        }
    }
}
