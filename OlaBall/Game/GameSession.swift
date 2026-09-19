import Foundation
import Observation
import UIKit

/// One game, start to finish. Owns the 3D scene, the live simulation, scoring, tips and XP.
@Observable
final class GameSession {
    enum Possessor: Equatable { case user, opponent }
    enum Phase: Equatable { case presnap, live, result, kicking(PlayCall), driveOver, gameOver }
    enum Outcome: Equatable { case win, loss, tie }

    let userTeam: Team
    let opponentTeam: Team
    let fieldScene: StadiumScene
    private let store: ProgressStore
    private var rng: SeededRNG
    let autoplay: Bool

    // Game state
    private(set) var userScore = 0
    private(set) var opponentScore = 0
    private(set) var possessions: [Possessor] = [.user, .opponent, .opponent, .user, .user, .opponent, .opponent, .user]
    private(set) var possessionIndex = 0
    private(set) var phase: Phase = .presnap
    private(set) var situation: Situation = .kickoff
    private(set) var defenseCall: DefenseCall = .balanced
    private(set) var presnapPlayers: [SimPlayer] = []
    private(set) var sim: PlaySim?
    private(set) var drivePlays: [Play] = []
    private(set) var lastPlay: Play?
    private(set) var lastVerdict: PlayAnalyst.Verdict?
    private(set) var driveEnding: DriveEnding?
    private(set) var tip: Concept?
    private(set) var newlyLearned: [Concept] = []
    private(set) var outcome: Outcome?
    private(set) var pathPreviewLength: Float = 0
    private(set) var kickInProgress = false

    // Stats
    private(set) var xpEarned = 0
    private(set) var touchdowns = 0
    private(set) var fieldGoals = 0
    private(set) var firstDowns = 0
    private(set) var playsRun = 0
    private(set) var longestPlay = 0
    private(set) var bestDriveYards = 0
    private(set) var defensiveStops = 0

    private var nextStartBallOn = 25
    private var lastDriveWasScore = false
    private var holdTimer: Float = 0
    private var presnapDelay: Float = 0

    static let maxNewTipsPerGame = 8
    static let resultHold: Float = 2.8
    static let driveOverHold: Float = 3.0

    init(userTeam: Team, opponentTeam: Team, store: ProgressStore, seed: UInt64 = UInt64.random(in: 0...UInt64.max), autoplay: Bool = false) {
        self.userTeam = userTeam
        self.opponentTeam = opponentTeam
        self.store = store
        self.rng = SeededRNG(seed: seed)
        self.autoplay = autoplay
        self.fieldScene = StadiumScene(userTeam: userTeam, opponentTeam: opponentTeam)
        SoundKit.shared.setScene(crowd: 0.2)
        SoundKit.shared.setMusic(false)
        beginPossession()
    }

    // MARK: Derived

    var quarter: Int { min(4, possessionIndex / 2 + 1) }
    var isOvertime: Bool { possessionIndex >= 8 }
    var periodLabel: String { isOvertime ? "OT" : "Q\(quarter)" }
    var currentPossessor: Possessor { possessions[min(possessionIndex, possessions.count - 1)] }
    var userOnOffense: Bool { currentPossessor == .user }
    var scoreDiff: Int { userScore - opponentScore }
    var seenConcepts: Set<String> { store.progress.seen }
    var canDraw: Bool { phase == .presnap && userOnOffense && !autoplay }
    var needsDefenseCall: Bool { phase == .presnap && !userOnOffense && !autoplay }
    var isFourthDown: Bool { situation.down == 4 }
    var offenseTeam: Team { userOnOffense ? userTeam : opponentTeam }
    var defenseTeam: Team { userOnOffense ? opponentTeam : userTeam }

    var situationText: String {
        switch phase {
        case .gameOver: return "Final"
        default:
            let own = userOnOffense ? "your" : "their"
            let their = userOnOffense ? "their" : "your"
            return "\(situation.downAndDistance) · Ball on \(situation.spotText(own: own, their: their))"
        }
    }

    var drawHint: String {
        if pathPreviewLength > 0 { return "Let go to snap it." }
        if playsRun == 0 { return "Drag from the running back, the bigger ring, and draw where he should run." }
        if situation.down == 4 { return "Fourth down. Draw a play to go for it, or kick." }
        return "Your call. Drag from a ring and draw where they go."
    }

    // MARK: Frame loop

    /// Called every frame by the scene view.
    func advance(dt: Float) {
        SoundKit.shared.update(dt: dt)
        switch phase {
        case .presnap:
            fieldScene.idle(dt: dt)
            guard autoplay else { return }
            presnapDelay += dt
            if presnapDelay > 0.6 {
                presnapDelay = 0
                if userOnOffense {
                    if situation.down == 4 && !situation.inFieldGoalRange && situation.ballOn < 60 { beginKick(.punt); userKick(.punt, accuracy: 0.2) }
                    else if situation.down == 4 && situation.inFieldGoalRange && situation.yardsToGo > 2 { beginKick(.fieldGoal); userKick(.fieldGoal, accuracy: 0.1) }
                    else { startUserPlay(AIPlaycaller.offensePlan(for: situation, against: defenseCall, using: &rng)) }
                } else {
                    chooseDefense(DefenseCall.allCases[Int.random(in: 0..<4, using: &rng)])
                }
            }
        case .live:
            guard var live = sim, !kickInProgress else { return }
            if !live.isOver {
                live.tick(dt * fieldScene.timeScale)
                sim = live
                fieldScene.apply(live)
                fieldScene.aimCamera(at: live.ballPos, presnap: false, animated: false)
                if live.isOver {
                    holdTimer = 0
                    onSimFinished(live)
                }
            } else {
                holdTimer += dt
                if holdTimer > 0.9 { showResult() }
            }
        case .result:
            guard tip == nil || autoplay else { return }   // wait for a tap when a tip is up
            holdTimer += dt
            if holdTimer > (autoplay ? 0.4 : GameSession.resultHold) { continueFromResult() }
        case .driveOver:
            holdTimer += dt
            if holdTimer > (autoplay ? 0.4 : GameSession.driveOverHold) { continueAfterDrive() }
        default:
            break
        }
    }

    // MARK: User actions

    func previewPath(_ points: [FieldPoint]) {
        pathPreviewLength = PlayPlan(ballHandlerTag: "RB", path: points).pathLength
    }

    func startUserPlay(_ plan: PlayPlan) {
        guard phase == .presnap, userOnOffense else { return }
        startPlay(plan)
    }

    func chooseDefense(_ call: DefenseCall) {
        guard phase == .presnap, !userOnOffense else { return }
        defenseCall = call
        presnapPlayers = PlaySim.presnapPlayers(los: Float(situation.ballOn), defenseCall: call)
        fieldScene.layOut(players: presnapPlayers, los: Float(situation.ballOn), firstDownAt: situation.isGoalToGo ? nil : Float(situation.firstDownMarker), offenseIsUser: false)
        let plan = AIPlaycaller.offensePlan(for: situation, against: call, using: &rng)
        startPlay(plan)
    }

    func beginKick(_ kind: PlayCall) {
        guard phase == .presnap, userOnOffense, kind.isKick else { return }
        tip = nil
        phase = .kicking(kind)
    }

    func userKick(_ kind: PlayCall, accuracy: Double) {
        guard case .kicking = phase else { return }
        let result: PlayResultKind
        if kind == .fieldGoal {
            let d = situation.fieldGoalDistance
            result = accuracy <= Kicking.meterTargetWidth(distance: d) ? .fieldGoalMade(d) : .fieldGoalMissed(d)
        } else {
            result = .punt(Kicking.puntDistance(accuracy: accuracy))
        }
        performKick(kind, result: result)
    }

    func skipResult() {
        switch phase {
        case .result: continueFromResult()
        case .driveOver: continueAfterDrive()
        default: break
        }
    }

    func dismissTip() {
        tip = nil
        holdTimer = 0
    }

    // MARK: Play flow

    private func startPlay(_ plan: PlayPlan) {
        tip = nil
        pathPreviewLength = 0
        var live = PlaySim(los: Float(situation.ballOn), plan: plan, defenseCall: defenseCall, seed: rng.next())
        live.snap()
        sim = live
        fieldScene.showPath(plan.path, color: userOnOffense ? UIColor(red: 0.96, green: 0.77, blue: 0.26, alpha: 0.9) : UIColor.white.withAlphaComponent(0.5))
        phase = .live
        holdTimer = 0
        SoundKit.shared.play(.snap, volume: 0.8)
        SoundKit.shared.excite(0.12)
    }

    private func performKick(_ kind: PlayCall, result: PlayResultKind) {
        kickInProgress = true
        phase = .live
        SoundKit.shared.play(.kick, volume: 0.9)
        SoundKit.shared.excite(0.1)
        let los = Float(situation.ballOn)
        let made: Bool
        let distance: Float
        switch result {
        case .fieldGoalMade(let d): made = true; distance = Float(d)
        case .fieldGoalMissed(let d): made = false; distance = Float(d)
        case .punt(let n): made = true; distance = Float(n)
        default: made = false; distance = 0
        }
        fieldScene.clearPath()
        if autoplay {
            // Don't wait on SceneKit in tests
            kickInProgress = false
            finishPlay(result: result, call: kind, sim: nil)
            showResult()
            return
        }
        fieldScene.animateKick(from: los, distanceYards: distance, made: made, punt: kind == .punt) { [weak self] in
            guard let self else { return }
            self.kickInProgress = false
            self.finishPlay(result: result, call: kind, sim: nil)
            self.showResult()
        }
    }

    private func onSimFinished(_ live: PlaySim) {
        let call: PlayCall
        switch live.plan.kind {
        case .run, .keeper: call = .run
        case .pass: call = live.plan.pathLength > 18 ? .deepPass : .shortPass
        }
        finishPlay(result: live.result ?? .incomplete, call: call, sim: live)
    }

    private func finishPlay(result: PlayResultKind, call: PlayCall, sim: PlaySim?) {
        guard lastPlayResolved == false else { return }
        lastPlayResolved = true
        let outcome = RulesEngine.apply(result, call: call, to: situation)
        let voice: PlayAnalyst.Voice = userOnOffense ? .you : .them
        let verdict: PlayAnalyst.Verdict
        if let sim {
            verdict = PlayAnalyst.verdict(for: sim, result: result, gainedFirstDown: outcome.firstDown, ending: outcome.ending, perspective: voice, cast: cast(for: sim.plan))
        } else {
            verdict = kickVerdict(result: result, ending: outcome.ending)
        }
        let play = Play(before: situation, call: call, result: result, after: outcome.after, ending: outcome.ending, gainedFirstDown: outcome.firstDown, narration: verdict.why)
        lastPlay = play
        lastVerdict = verdict
        drivePlays.append(play)
        playsRun += 1
        playSounds(for: play, events: sim?.events ?? [])

        if userOnOffense {
            xpEarned += 2
            longestPlay = max(longestPlay, play.yards)
            if play.gainedFirstDown, play.ending == nil { firstDowns += 1; xpEarned += 10 }
        }
        if let ending = play.ending {
            driveEnding = ending
            if ending.isScore {
                if userOnOffense {
                    userScore += ending.points
                    if ending == .touchdown { touchdowns += 1; xpEarned += 100 }
                    if ending == .fieldGoal { fieldGoals += 1; xpEarned += 50 }
                } else {
                    opponentScore += ending.points
                }
            } else if !userOnOffense {
                defensiveStops += 1
                xpEarned += 25
            }
            nextStartBallOn = RulesEngine.nextStart(after: play)
            lastDriveWasScore = ending.isScore
            if userOnOffense { bestDriveYards = max(bestDriveYards, drivePlays.reduce(0) { $0 + $1.yards }) }
        } else if let after = play.after {
            situation = after
        }
        if userOnOffense || play.ending != nil {
            let events = sim?.events ?? []
            setTip(TipDirector.postPlay(play, events: events, userOnOffense: userOnOffense, seen: seenConcepts))
        }
    }

    private var lastPlayResolved = false

    /// Names for the play-by-play: the ball handler by last name, the quarterback by last name.
    private func cast(for plan: PlayPlan) -> PlayAnalyst.Cast {
        var c = PlayAnalyst.Cast()
        let roster = Roster.roster(for: offenseTeam)
        if let qb = roster["QB0"] { c.qb = qb.name }
        if let key = Roster.key(forOffenseTag: plan.ballHandlerTag), let e = roster[key] {
            c.runner = e.name
            c.receiver = e.name
        }
        return c
    }

    /// Display name for an offensive tag on the current offense ("Okafor").
    func playerName(tag: String) -> String? {
        guard let key = Roster.key(forOffenseTag: tag) else { return nil }
        return Roster.roster(for: offenseTeam)[key]?.name
    }

    /// The crowd and the field react from the user's point of view.
    private func playSounds(for play: Play, events: [PlaySim.Event]) {
        let kit = SoundKit.shared
        let mine = userOnOffense
        let caught = events.contains { if case .caught = $0 { return true } else { return false } }
        let tackled = events.contains { if case .tackle = $0 { return true } else { return false } }
        if caught { kit.play(.catchBall, volume: 0.8) }
        if events.contains(.sack) { kit.play(.bigHit, volume: 1.0) }
        else if tackled { kit.play(play.yards < 0 || play.yards >= 12 ? .bigHit : .thud, volume: 0.9) }
        switch play.ending {
        case .touchdown:
            kit.play(.touchdown, volume: mine ? 0.9 : 0.35)
            kit.play(mine ? .cheer : .groan, volume: 1.0)
            kit.excite(mine ? 0.6 : 0.25)
        case .fieldGoal:
            kit.play(mine ? .cheer : .groan, volume: 0.8)
            kit.excite(mine ? 0.4 : 0.15)
        case .missedFieldGoal:
            kit.play(mine ? .groan : .cheer, volume: 0.8)
        case .interception, .fumble, .turnoverOnDowns:
            kit.play(mine ? .groan : .cheer, volume: 1.0)
            kit.excite(mine ? 0.15 : 0.5)
        case .punt:
            break
        case nil:
            if play.gainedFirstDown {
                kit.play(.firstDown, volume: mine ? 0.8 : 0.3)
                if mine { kit.excite(0.25) }
            } else if play.result == .incomplete {
                kit.play(.incomplete, volume: mine ? 0.6 : 0.3)
            }
        }
        if play.call.isKick == false || play.ending == .missedFieldGoal {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { kit.play(.whistle, volume: 0.35) }
        }
    }

    private func kickVerdict(result: PlayResultKind, ending: DriveEnding?) -> PlayAnalyst.Verdict {
        switch result {
        case .fieldGoalMade(let d): return .init(headline: "It's good! +3", why: "Nailed the timing from \(d) yards. Three points on the board.", good: true, bad: false)
        case .fieldGoalMissed(let d): return .init(headline: "No good", why: "The \(d)-yard kick drifted wide. Hit the green zone next time.", good: false, bad: true)
        case .punt(let n):
            let touchback = situation.ballOn + n >= 100
            return .init(headline: "Punt", why: touchback ? "Into the end zone: a touchback. They start at their 20." : "\(n) yards of field flipped. They have a long way to go.", good: false, bad: false)
        default: return .init(headline: "", why: "", good: false, bad: false)
        }
    }

    private func showResult() {
        guard phase == .live else { return }
        phase = .result
        holdTimer = 0
        if let play = lastPlay {
            if play.ending == .touchdown { Haptics.success() }
            else if play.isBadForOffense == userOnOffense { Haptics.failure() }
            else if play.isGoodForOffense == userOnOffense { Haptics.success() }
        }
    }

    func continueFromResult() {
        guard phase == .result else { return }
        lastPlayResolved = false
        sim = nil
        if driveEnding != nil {
            phase = .driveOver
            holdTimer = 0
            tip = nil
        } else {
            setUpPresnap()
        }
    }

    func continueAfterDrive() {
        guard phase == .driveOver else { return }
        possessionIndex += 1
        if possessionIndex >= possessions.count {
            if userScore == opponentScore && possessions.count < 12 {
                possessions.append(contentsOf: [.user, .opponent])
            } else {
                finishGame()
                return
            }
        }
        beginPossession()
    }

    private func beginPossession() {
        driveEnding = nil
        drivePlays = []
        lastPlay = nil
        lastVerdict = nil
        lastPlayResolved = false
        situation = .firstDown(at: nextStartBallOn)
        let startTip = TipDirector.driveStart(userHasBall: userOnOffense, afterScore: lastDriveWasScore, quarter: quarter, isOvertime: isOvertime, seen: seenConcepts)
        setUpPresnap(startTip: startTip)
    }

    private func setUpPresnap(startTip: Concept? = nil) {
        phase = .presnap
        holdTimer = 0
        presnapDelay = 0
        pathPreviewLength = 0
        lastPlayResolved = false
        sim = nil
        if userOnOffense {
            defenseCall = AIPlaycaller.defenseCall(for: situation, using: &rng)
        } else {
            defenseCall = .balanced
        }
        presnapPlayers = PlaySim.presnapPlayers(los: Float(situation.ballOn), defenseCall: defenseCall)
        fieldScene.layOut(players: presnapPlayers, los: Float(situation.ballOn), firstDownAt: situation.isGoalToGo ? nil : Float(situation.firstDownMarker), offenseIsUser: userOnOffense)
        fieldScene.aimCamera(at: FieldPoint(0, Float(situation.ballOn)), presnap: true, animated: true)
        if userOnOffense && playsRun == 0 { fieldScene.emphasize(tag: "RB", among: presnapPlayers) }

        // Opponent 4th-down decisions are automatic.
        if !userOnOffense && situation.down == 4 {
            let goForIt = situation.yardsToGo <= 2 && situation.ballOn >= 50 && !situation.inFieldGoalRange
            if situation.inFieldGoalRange {
                let d = situation.fieldGoalDistance
                let made = Double.random(in: 0..<1, using: &rng) < Kicking.fieldGoalProbability(distance: d)
                tip = nil
                performKick(.fieldGoal, result: made ? .fieldGoalMade(d) : .fieldGoalMissed(d))
                return
            } else if !goForIt {
                tip = nil
                performKick(.punt, result: .punt(Int.random(in: 36...50, using: &rng)))
                return
            }
        }
        let ctx = TipDirector.Context(situation: situation, defenseCall: defenseCall, userOnOffense: userOnOffense, playsThisGame: playsRun, isFourthQuarter: quarter == 4 || isOvertime, scoreDiff: scoreDiff)
        setTip(startTip ?? TipDirector.preSnap(ctx, seen: seenConcepts))
    }

    private func setTip(_ concept: Concept?) {
        guard let concept else { tip = nil; return }
        if seenConcepts.contains(concept.id) { tip = nil; return }   // tips only fire the first time
        guard newlyLearned.count < GameSession.maxNewTipsPerGame else { tip = nil; return }
        store.markSeen(concept.id)
        newlyLearned.append(concept)
        xpEarned += 15
        tip = concept
        holdTimer = 0
    }

    private func finishGame() {
        phase = .gameOver
        tip = nil
        SoundKit.shared.play(.whistle, volume: 0.6)
        if userScore > opponentScore { SoundKit.shared.play(.cheer, volume: 1.0); SoundKit.shared.play(.touchdown, volume: 0.7); SoundKit.shared.excite(0.6) }
        let result: Outcome
        if userScore > opponentScore { result = .win; xpEarned += 150 }
        else if userScore < opponentScore { result = .loss; xpEarned += 40 }
        else { result = .tie; xpEarned += 75 }
        outcome = result
        store.addXP(xpEarned)
        let stored: ProgressStore.GameResult = result == .win ? .win : (result == .loss ? .loss : .tie)
        store.recordGame(result: stored, touchdowns: touchdowns, bestDriveYards: bestDriveYards)
    }
}
