import Testing
@testable import OlaBall

struct RulesEngineTests {
    @Test func gainingTheDistanceIsAFirstDown() {
        let s = Situation(down: 2, yardsToGo: 7, ballOn: 30)
        let out = RulesEngine.apply(.gain(7), call: .run, to: s)
        #expect(out.firstDown)
        #expect(out.after == Situation(down: 1, yardsToGo: 10, ballOn: 37))
    }

    @Test func failingFourthDownIsATurnover() {
        let out = RulesEngine.apply(.gain(1), call: .run, to: Situation(down: 4, yardsToGo: 3, ballOn: 50))
        #expect(out.ending == .turnoverOnDowns)
    }

    @Test func reachingTheEndZoneIsATouchdown() {
        let out = RulesEngine.apply(.gain(4), call: .shortPass, to: Situation(down: 3, yardsToGo: 5, ballOn: 96))
        #expect(out.ending == .touchdown)
    }

    @Test func goalToGoAndFieldGoalMath() {
        #expect(Situation.firstDown(at: 94).downAndDistance == "1st & Goal")
        #expect(Situation.firstDown(at: 70).fieldGoalDistance == 47)
        #expect(!Situation.firstDown(at: 60).inFieldGoalRange)
    }

    @Test func puntTouchbackStartsAtTwenty() {
        let s = Situation(down: 4, yardsToGo: 8, ballOn: 60)
        let play = Play(before: s, call: .punt, result: .punt(45), after: nil, ending: .punt, gainedFirstDown: false, narration: "")
        #expect(RulesEngine.nextStart(after: play) == 20)
    }
}

struct PlaySimTests {
    static func run(_ plan: PlayPlan, los: Float, call: DefenseCall, seed: UInt64) -> PlaySim {
        var sim = PlaySim(los: los, plan: plan, defenseCall: call, seed: seed)
        var ticks = 0
        while !sim.isOver && ticks < 2000 { sim.tick(1.0 / 30.0); ticks += 1 }
        return sim
    }

    @Test func elevenOnEleven() {
        let players = PlaySim.presnapPlayers(los: 25, defenseCall: .balanced)
        #expect(players.filter { $0.side == .offense }.count == 11)
        #expect(players.filter { $0.side == .defense }.count == 11)
        #expect(players.filter { $0.role.isEligibleBallHandler }.count == 6)
    }

    @Test func everyPlayEnds() {
        var rng = SeededRNG(seed: 5)
        for i in 0..<200 {
            let los = Float(Int.random(in: 5...95, using: &rng))
            let call = DefenseCall.allCases[Int.random(in: 0..<4, using: &rng)]
            let plan = AIPlaycaller.offensePlan(for: .firstDown(at: Int(los)), against: call, using: &rng)
            let sim = PlaySimTests.run(plan, los: los, call: call, seed: UInt64(i))
            #expect(sim.isOver, "play \(i) never ended")
            if case .gain(let y) = sim.result! { #expect(y <= Int(100 - los) + 1) }
        }
    }

    @Test func deterministicForSameSeed() {
        var rng = SeededRNG(seed: 9)
        let plan = AIPlaycaller.offensePlan(for: .firstDown(at: 40), against: .balanced, using: &rng)
        let a = PlaySimTests.run(plan, los: 40, call: .balanced, seed: 77)
        let b = PlaySimTests.run(plan, los: 40, call: .balanced, seed: 77)
        #expect(a.result == b.result)
        #expect(a.events == b.events)
    }

    /// The bar: running into a crowd should be worse than running into a gap.
    @Test func runningIntoTheGapBeatsRunningIntoTheCrowd() {
        let los: Float = 30
        let players = PlaySim.presnapPlayers(los: los, defenseCall: .stackTheBox)
        let rb = players.first { $0.tag == "RB" }!
        // Stacked box walks the extra safety down on the right (+x). Left edge is the light side.
        let gapPath = [rb.pos, FieldPoint(-7, los - 1), FieldPoint(-9, los + 3), FieldPoint(-11, los + 15)]
        let crowdPath = [rb.pos, FieldPoint(4, los - 1), FieldPoint(6, los + 2), FieldPoint(7, los + 15)]
        func avg(_ path: [FieldPoint]) -> Double {
            var total = 0.0
            for seed in 0..<300 {
                let sim = PlaySimTests.run(PlayPlan(ballHandlerTag: "RB", path: path), los: los, call: .stackTheBox, seed: UInt64(seed))
                total += Double(sim.result?.yards ?? 0)
            }
            return total / 300
        }
        let gap = avg(gapPath), crowd = avg(crowdPath)
        #expect(gap >= 5, "gap average \(gap)")
        #expect(crowd < 3, "crowd average \(crowd)")
        #expect(gap > crowd + 3, "gap \(gap) vs crowd \(crowd)")
    }

    /// The bar: separation drives completions.
    @Test func openReceiversGetCaught() {
        let los: Float = 30
        let players = PlaySim.presnapPlayers(los: los, defenseCall: .stackTheBox)  // single deep safety, corners in man
        let z = players.first { $0.tag == "Z" }!
        // A sharp out-route toward the sideline creates separation against a lagging corner.
        let out = [z.pos, FieldPoint(z.pos.x, los + 5), FieldPoint(z.pos.x + 4, los + 6)]
        var caught = 0, seps: [Float] = []
        for seed in 0..<300 {
            let sim = PlaySimTests.run(PlayPlan(ballHandlerTag: "Z", path: out), los: los, call: .stackTheBox, seed: UInt64(seed))
            if sim.events.contains(where: { if case .caught = $0 { return true } else { return false } }) { caught += 1 }
            if let s = sim.analysis.separationAtCatch { seps.append(s) }
        }
        #expect(caught >= 150, "only \(caught)/300 caught; mean separation \(seps.reduce(0, +) / Float(max(1, seps.count)))")
    }

    @Test func blitzProducesSacksAgainstLongRoutes() {
        let los: Float = 40
        let players = PlaySim.presnapPlayers(los: los, defenseCall: .blitz)
        let x = players.first { $0.tag == "X" }!
        let go = [x.pos, FieldPoint(x.pos.x, los + 12), FieldPoint(x.pos.x + 2, los + 30)]
        var sacks = 0
        for seed in 0..<200 {
            let sim = PlaySimTests.run(PlayPlan(ballHandlerTag: "X", path: go), los: los, call: .blitz, seed: UInt64(seed))
            if sim.events.contains(.sack) { sacks += 1 }
        }
        #expect(sacks >= 40, "sacks \(sacks)/200")
    }
}

extension PlaySimTests {
    @Test func quickSlantBeatsTheBlitz() {
        let los: Float = 40
        let players = PlaySim.presnapPlayers(los: los, defenseCall: .blitz)
        let x = players.first { $0.tag == "X" }!
        let slant = [x.pos, FieldPoint(x.pos.x, los + 3), FieldPoint(x.pos.x + 8, los + 11)]
        var sacks = 0, caught = 0
        for seed in 0..<200 {
            let sim = PlaySimTests.run(PlayPlan(ballHandlerTag: "X", path: slant), los: los, call: .blitz, seed: UInt64(seed))
            if sim.events.contains(.sack) { sacks += 1 }
            if sim.events.contains(where: { if case .caught = $0 { return true } else { return false } }) { caught += 1 }
        }
        #expect(sacks < 30, "sacks \(sacks)/200")
        #expect(caught > 120, "caught \(caught)/200")
    }
}

struct TipDirectorTests {
    @Test func firstSnapTeachesTheObjective() {
        let ctx = TipDirector.Context(situation: .kickoff, defenseCall: .balanced, userOnOffense: true, playsThisGame: 0, isFourthQuarter: false, scoreDiff: 0)
        #expect(TipDirector.preSnap(ctx, seen: [])?.id == "objective")
        #expect(TipDirector.preSnap(ctx, seen: ["objective"])?.id == "drawThePlay")
    }

    @Test func everyConceptIsReachable() {
        let reachable: Set<String> = ["objective", "drawThePlay", "gaps", "notation", "thirdDown", "fourthDown", "fieldGoal", "punt", "theBox", "safeties", "blitz",
                                      "twoScores", "clutchTD", "clutchFG", "protectLead", "goalToGo", "redZone", "cornerbacks", "linemen", "defenseCalls",
                                      "touchdown", "missedFG", "turnoverOnDowns", "interception", "fumble", "firstDown", "sack", "incomplete", "sideline",
                                      "separation", "runPlay", "passPlay", "keeper", "defense", "overtime", "kickoff", "quarters"]
        for concept in Concept.all {
            #expect(reachable.contains(concept.id), "\(concept.id) is never surfaced")
        }
    }
}

struct GameSessionTests {
    @MainActor
    static func playWholeGame(seed: UInt64, store: ProgressStore) -> GameSession {
        let session = GameSession(userTeam: Team.all[0], opponentTeam: Team.all[1], store: store, seed: seed, autoplay: true)
        var frames = 0
        while session.phase != .gameOver && frames < 200_000 {
            session.advance(dt: 1.0 / 30.0)
            frames += 1
        }
        return session
    }

    @Test @MainActor func aFullGameFinishesAndAwardsXP() {
        let store = ProgressStore(progress: Progress())
        let session = GameSessionTests.playWholeGame(seed: 3, store: store)
        #expect(session.phase == .gameOver)
        #expect(session.outcome != nil)
        #expect(store.progress.games == 1)
        #expect(store.progress.xp == session.xpEarned)
        #expect(session.newlyLearned.count == GameSession.maxNewTipsPerGame)
        #expect(session.playsRun > 20)
    }

    @Test @MainActor func tipsKeepUnlockingAcrossGames() {
        let store = ProgressStore(progress: Progress())
        var counts: [Int] = []
        for seed in 10..<14 {
            _ = GameSessionTests.playWholeGame(seed: UInt64(seed), store: store)
            counts.append(store.progress.seen.count)
        }
        #expect(counts[3] > counts[0])
    }
}
