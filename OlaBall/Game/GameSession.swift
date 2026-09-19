import Foundation
import Observation

/// Drives one game: alternating possessions, scoring, tips, and XP. UI reads from this; engine does the math.
@Observable
final class GameSession {
    enum Possessor: Equatable { case user, opponent }

    enum Phase: Equatable {
        case choosing        // user picks a play
        case result          // showing the last play's outcome
        case driveOver       // user's drive summary
        case opponentDrive   // watching the other team
        case gameOver
    }

    enum Outcome: Equatable { case win, loss, tie }

    struct FieldState: Equatable {
        var ballX: Int          // absolute: 0 = user's goal line, 100 = opponent's goal line
        var firstDownX: Int?
        var possessor: Possessor
    }

    let userTeam: Team
    let opponentTeam: Team
    private let store: ProgressStore
    private var rng: any RandomNumberGenerator

    private(set) var userScore = 0
    private(set) var opponentScore = 0
    private(set) var possessions: [Possessor] = [.user, .opponent, .opponent, .user, .user, .opponent, .opponent, .user]
    private(set) var possessionIndex = 0
    private(set) var phase: Phase = .choosing
    private(set) var situation: Situation = .kickoff
    private(set) var drivePlays: [Play] = []
    private(set) var lastPlay: Play?
    private(set) var driveEnding: DriveEnding?
    private(set) var opponentDrive: DriveSummary?
    private(set) var opponentRevealed = 0
    private(set) var tip: Concept?
    private(set) var newlyLearned: [Concept] = []
    private(set) var outcome: Outcome?
    private(set) var lastScorer: Possessor?

    // Stats & rewards
    private(set) var xpEarned = 0
    private(set) var touchdowns = 0
    private(set) var fieldGoals = 0
    private(set) var firstDowns = 0
    private(set) var playsRun = 0
    private(set) var longestPlay = 0
    private(set) var bestDriveYards = 0
    private(set) var driveStartBallOn = 25

    private var nextStartBallOn = 25
    private var lastDriveWasScore = false

    init(userTeam: Team, opponentTeam: Team, store: ProgressStore, rng: any RandomNumberGenerator = SystemRandomNumberGenerator()) {
        self.userTeam = userTeam
        self.opponentTeam = opponentTeam
        self.store = store
        self.rng = rng
        beginPossession()
    }

    // MARK: - Derived state

    var quarter: Int { min(4, possessionIndex / 2 + 1) }
    var isOvertime: Bool { possessionIndex >= 8 }
    var periodLabel: String { isOvertime ? "OT" : "Q\(quarter)" }
    var currentPossessor: Possessor { possessions[min(possessionIndex, possessions.count - 1)] }
    var scoreDiff: Int { userScore - opponentScore }
    var seenConcepts: Set<String> { store.progress.seen }

    var availableCalls: [PlayCall] {
        if situation.down == 4 {
            var calls: [PlayCall] = [.run, .shortPass, .punt]
            if situation.canAttemptFieldGoal { calls.append(.fieldGoal) }
            return calls
        }
        return [.run, .shortPass, .deepPass]
    }

    var revealedOpponentPlays: [Play] {
        guard let opponentDrive else { return [] }
        return Array(opponentDrive.plays.prefix(opponentRevealed))
    }

    var opponentDriveFullyRevealed: Bool {
        guard let opponentDrive else { return true }
        return opponentRevealed >= opponentDrive.plays.count
    }

    var opponentSituation: Situation? {
        guard let opponentDrive else { return nil }
        if opponentRevealed == 0 { return .firstDown(at: opponentDrive.startBallOn) }
        return opponentDrive.plays[opponentRevealed - 1].after
    }

    var fieldState: FieldState {
        if phase == .opponentDrive, let opponentDrive {
            let last = revealedOpponentPlays.last
            let theirBall = last?.ballAfter ?? opponentDrive.startBallOn
            let marker: Int? = (last?.after).flatMap { $0.isGoalToGo ? nil : $0.firstDownMarker }
                ?? (last == nil ? Situation.firstDown(at: opponentDrive.startBallOn).firstDownMarker : nil)
            return FieldState(ballX: 100 - theirBall, firstDownX: marker.map { 100 - $0 }, possessor: .opponent)
        }
        if (phase == .result || phase == .driveOver), let lastPlay {
            let marker = lastPlay.after.flatMap { $0.isGoalToGo ? nil : $0.firstDownMarker }
            return FieldState(ballX: lastPlay.ballAfter, firstDownX: marker, possessor: .user)
        }
        return FieldState(ballX: situation.ballOn, firstDownX: situation.isGoalToGo ? nil : situation.firstDownMarker, possessor: .user)
    }

    var situationText: String {
        switch phase {
        case .opponentDrive:
            guard let s = opponentSituation else { return "Their drive is over" }
            return "\(s.downAndDistance) · Ball on \(s.spotText(own: "their", their: "your"))"
        case .gameOver:
            return "Final"
        default:
            if driveEnding != nil, phase != .choosing { return "Drive over" }
            return "\(situation.downAndDistance) · Ball on \(situation.spotText()) · \(situation.yardsToEndZone) to the end zone"
        }
    }

    // MARK: - Actions

    func call(_ call: PlayCall) {
        guard phase == .choosing else { return }
        let play = DriveEngine.runPlay(call, from: situation, voice: .you, using: &rng)
        drivePlays.append(play)
        lastPlay = play
        playsRun += 1
        longestPlay = max(longestPlay, play.yards)
        xpEarned += 2
        if play.gainedFirstDown, play.ending == nil {
            firstDowns += 1
            xpEarned += 10
        }
        if let ending = play.ending {
            driveEnding = ending
            if ending.isScore {
                userScore += ending.points
                lastScorer = .user
                if ending == .touchdown { touchdowns += 1; xpEarned += 100 }
                if ending == .fieldGoal { fieldGoals += 1; xpEarned += 50 }
            }
            nextStartBallOn = RulesEngine.nextStart(after: play)
            lastDriveWasScore = ending.isScore
            let driveYards = drivePlays.reduce(0) { $0 + $1.yards }
            bestDriveYards = max(bestDriveYards, driveYards)
        } else if let after = play.after {
            situation = after
        }
        phase = .result
        setTip(TipDirector.postPlay(play, seen: seenConcepts))
    }

    func next() {
        guard phase == .result else { return }
        if driveEnding != nil {
            phase = .driveOver
            tip = nil
        } else {
            phase = .choosing
            setTip(preCallTip())
        }
    }

    func continueAfterDrive() {
        guard phase == .driveOver || (phase == .opponentDrive && opponentDriveFullyRevealed) else { return }
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

    func revealNextOpponentPlay() {
        guard phase == .opponentDrive, let opponentDrive, opponentRevealed < opponentDrive.plays.count else { return }
        opponentRevealed += 1
        tip = nil
        if opponentRevealed == opponentDrive.plays.count { applyOpponentEnding() }
    }

    func skipOpponentDrive() {
        guard phase == .opponentDrive, let opponentDrive else { return }
        opponentRevealed = opponentDrive.plays.count
        tip = nil
        applyOpponentEnding()
    }

    func dismissTip() { tip = nil }

    // MARK: - Internals

    private func beginPossession() {
        driveEnding = nil
        drivePlays = []
        lastPlay = nil
        let afterScore = lastDriveWasScore
        let userHasBall = currentPossessor == .user
        if userHasBall {
            situation = .firstDown(at: nextStartBallOn)
            driveStartBallOn = situation.ballOn
            phase = .choosing
            let startTip = TipDirector.driveStart(userHasBall: true, afterScore: afterScore, quarter: quarter, isOvertime: isOvertime, seen: seenConcepts)
            setTip(startTip ?? preCallTip())
        } else {
            let start = Situation.firstDown(at: nextStartBallOn)
            opponentDrive = OpponentCoach.simulateDrive(from: start, using: &rng)
            opponentRevealed = 0
            phase = .opponentDrive
            setTip(TipDirector.driveStart(userHasBall: false, afterScore: afterScore, quarter: quarter, isOvertime: isOvertime, seen: seenConcepts))
        }
    }

    private func applyOpponentEnding() {
        guard let opponentDrive, let last = opponentDrive.plays.last else { return }
        if opponentDrive.ending.isScore {
            opponentScore += opponentDrive.ending.points
            lastScorer = .opponent
        }
        lastDriveWasScore = opponentDrive.ending.isScore
        nextStartBallOn = RulesEngine.nextStart(after: last)
    }

    private func preCallTip() -> Concept? {
        let ctx = TipDirector.Context(situation: situation, playsThisGame: playsRun, isFourthQuarter: quarter == 4 || isOvertime, scoreDiff: scoreDiff)
        return TipDirector.preCall(ctx, seen: seenConcepts)
    }

    private func setTip(_ concept: Concept?) {
        tip = concept
        guard let concept else { return }
        if store.markSeen(concept.id) {
            newlyLearned.append(concept)
            xpEarned += 15
        }
    }

    private func finishGame() {
        phase = .gameOver
        tip = nil
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
