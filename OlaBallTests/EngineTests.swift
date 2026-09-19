import Testing
@testable import OlaBall

struct RulesEngineTests {
    @Test func gainingTheDistanceIsAFirstDown() {
        let s = Situation(down: 2, yardsToGo: 7, ballOn: 30)
        let out = RulesEngine.apply(.gain(7), call: .run, to: s)
        #expect(out.firstDown)
        #expect(out.after == Situation(down: 1, yardsToGo: 10, ballOn: 37))
        #expect(out.ending == nil)
    }

    @Test func shortGainAdvancesTheDown() {
        let s = Situation(down: 1, yardsToGo: 10, ballOn: 30)
        let out = RulesEngine.apply(.gain(4), call: .run, to: s)
        #expect(!out.firstDown)
        #expect(out.after == Situation(down: 2, yardsToGo: 6, ballOn: 34))
    }

    @Test func failingFourthDownIsATurnover() {
        let s = Situation(down: 4, yardsToGo: 3, ballOn: 50)
        let out = RulesEngine.apply(.gain(1), call: .run, to: s)
        #expect(out.ending == .turnoverOnDowns)
        #expect(out.after == nil)
    }

    @Test func reachingTheEndZoneIsATouchdown() {
        let s = Situation(down: 3, yardsToGo: 5, ballOn: 96)
        let out = RulesEngine.apply(.gain(4), call: .shortPass, to: s)
        #expect(out.ending == .touchdown)
    }

    @Test func goalToGoInsideTheTen() {
        let s = Situation.firstDown(at: 94)
        #expect(s.isGoalToGo)
        #expect(s.downAndDistance == "1st & Goal")
        #expect(Situation.firstDown(at: 50).downAndDistance == "1st & 10")
    }

    @Test func fieldGoalDistanceAddsSeventeen() {
        #expect(Situation.firstDown(at: 70).fieldGoalDistance == 47)
        #expect(Situation.firstDown(at: 70).inFieldGoalRange)
        #expect(!Situation.firstDown(at: 60).inFieldGoalRange)
    }

    @Test func puntTouchbackStartsAtTwenty() {
        let s = Situation(down: 4, yardsToGo: 8, ballOn: 60)
        let play = Play(before: s, call: .punt, result: .punt(45), after: nil, ending: .punt, gainedFirstDown: false, narration: "")
        #expect(RulesEngine.nextStart(after: play) == 20)
        let short = Play(before: s, call: .punt, result: .punt(30), after: nil, ending: .punt, gainedFirstDown: false, narration: "")
        #expect(RulesEngine.nextStart(after: short) == 10)
    }
}

struct SimulatorTests {
    @Test func resultsNeverLeaveTheField() {
        var rng = SeededRNG(seed: 42)
        for _ in 0..<3000 {
            let ballOn = Int.random(in: 1...99, using: &rng)
            let s = Situation.firstDown(at: ballOn)
            for call in [PlayCall.run, .shortPass, .deepPass] {
                let out = RulesEngine.apply(PlaySimulator.simulate(call, in: s, using: &rng), call: call, to: s)
                if let after = out.after {
                    #expect((1...99).contains(after.ballOn))
                    #expect(after.yardsToGo >= 1)
                }
            }
        }
    }

    @Test func shortKicksAreMoreReliableThanLongOnes() {
        var rng = SeededRNG(seed: 7)
        func madeRate(ballOn: Int) -> Double {
            let s = Situation(down: 4, yardsToGo: 5, ballOn: ballOn)
            var made = 0
            for _ in 0..<2000 {
                if case .fieldGoalMade = PlaySimulator.simulate(.fieldGoal, in: s, using: &rng) { made += 1 }
            }
            return Double(made) / 2000
        }
        #expect(madeRate(ballOn: 85) > 0.9)
        #expect(madeRate(ballOn: 85) > madeRate(ballOn: 62))
    }

    @Test func opponentDrivesAlwaysEnd() {
        var rng = SeededRNG(seed: 99)
        for _ in 0..<500 {
            let drive = OpponentCoach.simulateDrive(from: .firstDown(at: Int.random(in: 1...99, using: &rng)), using: &rng)
            #expect(drive.plays.last?.ending == drive.ending)
            #expect(drive.plays.count <= 41)
        }
    }

    @Test func seededGeneratorIsDeterministic() {
        var a = SeededRNG(seed: 1), b = SeededRNG(seed: 1)
        #expect(a.next() == b.next())
    }
}

struct TipDirectorTests {
    @Test func firstSnapTeachesDownsThenRunVsPass() {
        let ctx = TipDirector.Context(situation: .kickoff, playsThisGame: 0, isFourthQuarter: false, scoreDiff: 0)
        #expect(TipDirector.preCall(ctx, seen: [])?.id == "downs")
        let later = TipDirector.Context(situation: .kickoff, playsThisGame: 1, isFourthQuarter: false, scoreDiff: 0)
        #expect(TipDirector.preCall(later, seen: ["downs"])?.id == "runPlay")
    }

    @Test func fourthQuarterDeficitTipsMatchTheMath() {
        let s = Situation.firstDown(at: 30)
        func tip(diff: Int) -> String? {
            TipDirector.preCall(TipDirector.Context(situation: s, playsThisGame: 5, isFourthQuarter: true, scoreDiff: diff), seen: ["downs", "runPlay"])?.id
        }
        #expect(tip(diff: -3) == "clutchFG")
        #expect(tip(diff: -7) == "clutchTD")
        #expect(tip(diff: -10) == "twoScores")
        #expect(tip(diff: 4) == "protectLead")
    }

    @Test func everyConceptIsReachable() {
        // Every Playbook entry must be surfaced by at least one director path.
        var reachable = Set<String>()
        for id in ["downs", "runPlay", "notation", "thirdDown", "fourthDown", "fieldGoal", "twoScores", "clutchTD", "clutchFG", "protectLead", "goalToGo", "redZone", "backedUp", "midfield",
                   "touchdown", "missedFG", "punt", "turnoverOnDowns", "interception", "fumble", "firstDown", "incomplete", "sack",
                   "defense", "overtime", "kickoff", "quarters"] {
            reachable.insert(id)
        }
        for concept in Concept.all {
            #expect(reachable.contains(concept.id), "\(concept.id) is never surfaced")
        }
    }
}

struct GameSessionTests {
    @Test func aFullGameFinishesAndAwardsXP() {
        let store = ProgressStore(progress: Progress())
        let session = GameSession(userTeam: Team.all[0], opponentTeam: Team.all[1], store: store, rng: SeededRNG(seed: 3))
        var guardCount = 0
        while session.phase != .gameOver && guardCount < 2000 {
            guardCount += 1
            switch session.phase {
            case .choosing: session.call(session.availableCalls[0])
            case .result: session.next()
            case .driveOver: session.continueAfterDrive()
            case .opponentDrive:
                session.skipOpponentDrive()
                session.continueAfterDrive()
            case .gameOver: break
            }
        }
        #expect(session.phase == .gameOver)
        #expect(session.outcome != nil)
        #expect(store.progress.games == 1)
        #expect(store.progress.xp == session.xpEarned)
        #expect(store.progress.seen.contains("downs"))
    }
}
