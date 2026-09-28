import Testing
import Foundation
@testable import OlaBall

struct ContentTests {
    @Test func everyDeckIsWellFormed() {
        #expect(Decks.all.count == 18)
        for deck in Decks.all {
            #expect(deck.questions.count == 120, "\(deck.id) has \(deck.questions.count) questions")
            for t in 1...3 {
                #expect(deck.questions.filter { $0.tier == t }.count == 40, "\(deck.id) tier \(t)")
            }
            for q in deck.questions {
                #expect(q.wrong.count == 3, Comment(rawValue: q.id))
                #expect(!q.wrong.contains(q.correct), Comment(rawValue: q.id))
                #expect(Set(q.wrong).count == 3, Comment(rawValue: q.id))
                #expect(q.options.count == 4, Comment(rawValue: q.id))
                #expect(q.options[q.correctIndex] == q.correct, Comment(rawValue: q.id))
                #expect(!q.prompt.isEmpty && !q.correct.isEmpty, Comment(rawValue: q.id))
            }
        }
        let ids = Decks.all.flatMap { $0.questions.map(\.id) }
        #expect(Set(ids).count == ids.count)
        let prompts = Decks.all.flatMap { $0.questions.map(\.prompt) }
        #expect(Set(prompts).count == prompts.count, "duplicate prompts")
    }

    @Test func optionOrderIsStableAcrossDevices() {
        let q = Decks.all[0].questions[0]
        #expect(q.options == q.options)
        #expect(Decks.all.flatMap(\.questions).contains { $0.correctIndex != 0 }, "correct answer should not always be first")
    }
}

struct EngineTests {
    @Test func roundsEscalate() {
        #expect(MatchEngine.tiers(forRound: 1).max() == 2)
        #expect(MatchEngine.tiers(forRound: 5).allSatisfy { $0 == 3 })
        #expect(MatchEngine.tiers(forRound: 3).count == MatchState.questionsPerRound)
    }

    @Test func questionDrawIsDeterministicAndFresh() {
        let deck = HisWorld.football
        let a = MatchEngine.questions(deck: deck, round: 2, playerID: "x", seed: 99, excluding: [])
        let b = MatchEngine.questions(deck: deck, round: 2, playerID: "x", seed: 99, excluding: [])
        #expect(a.map(\.id) == b.map(\.id))
        #expect(a.count == MatchState.questionsPerRound)
        let used = Set(a.map(\.id))
        let c = MatchEngine.questions(deck: deck, round: 2, playerID: "x", seed: 99, excluding: used)
        #expect(Set(c.map(\.id)).isDisjoint(with: used))
        // Two members of one couple on the same deck get different questions.
        let d = MatchEngine.questions(deck: deck, round: 2, playerID: "y", seed: 99, excluding: [])
        #expect(a.map(\.id) != d.map(\.id))
    }

    @Test func drawPrefersQuestionsThisPhoneHasNotSeen() {
        let deck = HisWorld.football
        let a = MatchEngine.questions(deck: deck, round: 2, playerID: "x", seed: 99, excluding: [])
        // Same match seed, but this phone has already shown those seven: none of them come back.
        let b = MatchEngine.questions(deck: deck, round: 2, playerID: "x", seed: 99, excluding: [], seen: a.map(\.id))
        #expect(Set(b.map(\.id)).isDisjoint(with: a.map(\.id)))
        // Everything in the round's tiers seen: the draw cycles through the oldest first.
        let rookies = deck.questions.filter { $0.tier == 1 }.map(\.id)
        let c = MatchEngine.questions(deck: deck, round: 1, playerID: "x", seed: 99, excluding: [], seen: rookies + deck.questions.filter { $0.tier > 1 }.map(\.id))
        #expect(Array(c.prefix(5)).map(\.id) == Array(rookies.prefix(5)))
    }

    @Test func historyMovesSeenQuestionsToTheNewestEnd() {
        let h = QuestionHistory()
        h.record(["a", "b", "c"])
        h.record(["b", "d"])
        #expect(h.order == ["a", "c", "b", "d"])
    }

    @Test func scoringRewardsSpeedAndStreaks() {
        #expect(MatchEngine.points(correct: false, elapsedMs: 100, streak: 0) == 0)
        let fast = MatchEngine.points(correct: true, elapsedMs: 500, streak: 1)
        let slow = MatchEngine.points(correct: true, elapsedMs: 14_000, streak: 1)
        #expect(fast > slow)
        #expect(MatchEngine.points(correct: true, elapsedMs: 1000, streak: 3) > MatchEngine.points(correct: true, elapsedMs: 1000, streak: 1))
    }

    private static func result(_ score: Int, _ correct: Int) -> RoundResult {
        RoundResult(questionIDs: [], answers: [], timesMs: [], score: score, correct: correct)
    }

    @Test func matchFlowsToAWinner() {
        var s = MatchState(seed: 5, creator: .solo(id: "a", name: "Noah", world: .his))
        s.join(.solo(id: "b", name: "Sam", world: .hers))
        let am = "a/0", bm = "b/0"
        #expect(s.pendingPicks(for: "a")?.round == 1)
        #expect(s.pendingPicks(for: "a")?.targets.map(\.id) == [bm])
        s.pick(deckID: "football", forMember: bm, round: 1)     // a picks for b: from his world, since b answers his
        #expect(s.pendingAnswers(for: "b").first?.round == 1)
        #expect(s.pendingPicks(for: "b")?.round == 1)
        s.pick(deckID: "skincare", forMember: am, round: 1)
        for r in 1...3 {
            if r > 1 { s.pick(deckID: "football", forMember: bm, round: r); s.pick(deckID: "fashion", forMember: am, round: r) }
            s.record(Self.result(700, 7), forMember: am, round: r)
            s.record(Self.result(300, 3), forMember: bm, round: r)
        }
        #expect(s.crowns(for: "a") == 3)
        #expect(s.status == .finished)
        #expect(s.winnerID == "a")
    }

    @Test func couplesScoresAddUpAndPicksCoverBothMembers() {
        var s = MatchState(seed: 9, creator: .team(id: "a", members: [("Noah", .his), ("Sam", .hers)]), mode: .teams)
        s.join(.team(id: "b", members: [("Alex", .his), ("Jo", .hers)]))
        #expect(s.player("a")?.name == "Noah & Sam")
        #expect(s.member("a/0")?.answers == .his)
        #expect(s.member("a/1")?.answers == .hers)
        let picks = s.pendingPicks(for: "a")
        #expect(picks?.targets.map(\.id) == ["b/0", "b/1"])
        s.pick(deckID: "football", forMember: "b/0", round: 1)
        #expect(s.pendingPicks(for: "a")?.targets.map(\.id) == ["b/1"])
        s.pick(deckID: "skincare", forMember: "b/1", round: 1)
        #expect(s.pendingPicks(for: "a") == nil || s.pendingPicks(for: "a")?.round == 2)
        #expect(s.pendingAnswers(for: "b").map(\.member.id) == ["b/0", "b/1"])
        s.record(Self.result(400, 4), forMember: "b/0", round: 1)
        #expect(s.pendingAnswers(for: "b").map(\.member.id) == ["b/1"])
        s.record(Self.result(300, 3), forMember: "b/1", round: 1)
        #expect(s.pendingAnswers(for: "b").isEmpty)
        s.pick(deckID: "cars", forMember: "a/0", round: 1)
        s.pick(deckID: "divas", forMember: "a/1", round: 1)
        s.record(Self.result(500, 5), forMember: "a/0", round: 1)
        #expect(s.roundWinner(s.rounds[0]) == nil, "round not complete until every member has answered")
        s.record(Self.result(100, 1), forMember: "a/1", round: 1)
        #expect(s.rounds[0].score(for: s.player("a")!) == 600)
        #expect(s.rounds[0].score(for: s.player("b")!) == 700)
        #expect(s.roundWinner(s.rounds[0]) == "b")
    }

    @Test func tiesGiveNoCrown() {
        var s = MatchState(seed: 1, creator: .solo(id: "a", name: "A", world: .his)); s.join(.solo(id: "b", name: "B", world: .hers))
        s.pick(deckID: "cars", forMember: "b/0", round: 1); s.pick(deckID: "divas", forMember: "a/0", round: 1)
        s.record(Self.result(500, 5), forMember: "a/0", round: 1)
        s.record(Self.result(500, 5), forMember: "b/0", round: 1)
        #expect(s.roundWinner(s.rounds[0]) == nil)
        #expect(s.crowns(for: "a") == 0 && s.crowns(for: "b") == 0)
    }

    @Test func stateRoundTripsThroughJSON() throws {
        var s = MatchState(seed: 3, creator: .team(id: "a", members: [("A", .his), ("B", .hers)]), mode: .teams)
        s.join(.team(id: "b", members: [("C", .his), ("D", .hers)]))
        s.pick(deckID: "grill", forMember: "b/0", round: 1)
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(MatchState.self, from: data)
        #expect(back == s)
        #expect(data.count < 60_000)
    }
}

struct ControllerTests {
    final class MemoryTransport: MatchTransport {
        var state: MatchState
        var turn: String
        init(state: MatchState) { self.state = state; turn = state.players[0].id }
        var activePlayerID: String { turn }
        var activePlayerName: String { state.player(turn)?.name ?? "" }
        var activePlayerWorld: World { state.player(turn)?.world ?? .his }
        var isMyTurn: Bool { true }
        var isPassAndPlay: Bool { true }
        func submitTurn(_ s: MatchState) async throws { state = s; turn = s.turnPlayerID ?? turn }
        func save(_ s: MatchState) async throws { state = s }
    }

    /// An online (Game Center) transport: two separate phones, so it is nobody's "pass the phone".
    /// `isMyTurn` is whether the local side owns the turn, exactly as GameCenterTransport reports it.
    final class OnlineTransport: MatchTransport {
        var state: MatchState
        var localID: String
        var submissions = 0
        init(state: MatchState, localID: String) { self.state = state; self.localID = localID }
        var activePlayerID: String { localID }
        var activePlayerName: String { state.player(localID)?.name ?? "Noah" }
        var activePlayerWorld: World { state.player(localID)?.world ?? .his }
        var isMyTurn: Bool { state.turnPlayerID == nil || state.turnPlayerID == localID }
        var isPassAndPlay: Bool { false }
        func submitTurn(_ s: MatchState) async throws {
            submissions += 1
            state = s
            // Game Center hands the turn to the other participant regardless of what the payload says.
            state.turnPlayerID = s.players.first(where: { $0.id != localID })?.id
        }
        func save(_ s: MatchState) async throws { state = s }
    }

    /// The creator of an online match opens it before anyone has accepted. There is no opponent in
    /// the state yet, so there is nothing to pick and nothing to answer: the turn has to go over so
    /// the other side can join. Regression test for a match that was dead on arrival.
    @MainActor
    @Test func aNewOnlineMatchHandsTheFirstTurnOver() async throws {
        let seed = MatchState(seed: 42, creator: .solo(id: "a", name: "Noah", world: .his))
        let transport = OnlineTransport(state: seed, localID: "a")
        let c = MatchController(state: seed, transport: transport, history: QuestionHistory())

        c.start(announce: true)
        try await Task.sleep(for: .milliseconds(150))

        #expect(transport.submissions == 1, "the seed state must reach Game Center")
        #expect(transport.state.turnPlayerID != "a", "the turn must go to the opponent")
        #expect(c.stage == .waiting)
    }

    /// Drives a controller to the end. Side "a" answers everything right; side "b" always taps option 0.
    @MainActor
    private static func playOut(_ c: MatchController) async throws -> Int {
        c.start(announce: true)
        var guardCount = 0
        var trace: [String] = []
        while c.stage != .finished && guardCount < 1500 {
            guardCount += 1
            trace.append("\(c.me):\(c.stage)")
            if trace.count > 40 { trace.removeFirst() }
            switch c.stage {
            case .setupTeam:
                c.joinTeam(members: [("X", .his), ("Y", .hers)])
            case .picking(_, let target):
                c.pick(Decks.decks(in: target.answers)[guardCount % 6])
                try await Task.sleep(for: .milliseconds(20))
            case .handoff:
                c.continueAfterHandoff()
            case .intro:
                c.beginAnswering()
            case .answering:
                if c.revealed { c.nextQuestion() } else { c.select(c.me == "a" ? (c.currentQuestion?.correctIndex ?? 0) : 0) }
            case .roundReveal:
                c.acknowledgeReveal()
            case .waiting:
                try await Task.sleep(for: .milliseconds(20))
                c.start()
            case .finished:
                break
            }
        }
        if c.stage != .finished {
            Issue.record("stalled after \(guardCount) steps; rounds=\(c.state.rounds.count) status=\(c.state.status) turn=\(c.state.turnPlayerID ?? "-") trace=\(trace.suffix(12).joined(separator: " | "))")
        }
        return guardCount
    }

    @Test @MainActor func aWholePassAndPlayMatchCompletes() async throws {
        var s = MatchState(seed: 42, creator: .solo(id: "a", name: "Noah", world: .his)); s.join(.solo(id: "b", name: "Sam", world: .hers))
        let c = MatchController(state: s, transport: MemoryTransport(state: s), history: QuestionHistory())
        _ = try await Self.playOut(c)
        #expect(c.stage == .finished)
        #expect(c.state.status == .finished)
        #expect(c.state.winnerID == "a", "the side answering everything right should win")
        #expect(c.state.completedRounds.count >= 3)
    }

    @Test @MainActor func aCouplesMatchCompletesWithHandoffsBetweenMembers() async throws {
        var s = MatchState(seed: 7, creator: .team(id: "a", members: [("Noah", .his), ("Sam", .hers)]), mode: .teams)
        s.join(.team(id: "b", members: [("Alex", .his), ("Jo", .hers)]))
        let c = MatchController(state: s, transport: MemoryTransport(state: s), history: QuestionHistory())
        _ = try await Self.playOut(c)
        #expect(c.stage == .finished)
        #expect(c.state.winnerID == "a")
        // Every member of both couples answered every completed round.
        for r in c.state.completedRounds {
            #expect(r.results.count == 4, "round \(r.number) has \(r.results.count) results")
            #expect(r.picks.count == 4)
        }
        // Lanes were respected: each member's picked deck comes from the world they answer.
        for r in c.state.rounds {
            for (memberID, deckID) in r.picks {
                #expect(Decks.byID(deckID)?.world == c.state.member(memberID)?.answers, "\(memberID) got \(deckID)")
            }
        }
    }

    @Test @MainActor func aChallengedCoupleJoinsBeforePlaying() async throws {
        // The creator's phone made the match; this phone ("b") opens it and must set up its couple first.
        let s = MatchState(seed: 11, creator: .team(id: "a", members: [("Noah", .his), ("Sam", .hers)]), mode: .teams)
        let t = MemoryTransport(state: s)
        t.turn = "b"
        let c = MatchController(state: s, transport: t, history: QuestionHistory())
        c.start(announce: true)
        #expect(c.stage == .setupTeam)
        c.joinTeam(members: [("Alex", .his), ("Jo", .hers)])
        #expect(c.state.isReady)
        #expect(c.state.player("b")?.name == "Alex & Jo")
    }
}
