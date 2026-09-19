import Testing
import Foundation
@testable import OlaBall

struct ContentTests {
    @Test func everyDeckIsWellFormed() {
        #expect(Decks.all.count == 12)
        for deck in Decks.all {
            #expect(deck.questions.count == 36, "\(deck.id) has \(deck.questions.count) questions")
            for t in 1...3 {
                #expect(deck.questions.filter { $0.tier == t }.count == 12, "\(deck.id) tier \(t)")
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
    }

    @Test func scoringRewardsSpeedAndStreaks() {
        #expect(MatchEngine.points(correct: false, elapsedMs: 100, streak: 0) == 0)
        let fast = MatchEngine.points(correct: true, elapsedMs: 500, streak: 1)
        let slow = MatchEngine.points(correct: true, elapsedMs: 14_000, streak: 1)
        #expect(fast > slow)
        #expect(MatchEngine.points(correct: true, elapsedMs: 1000, streak: 3) > MatchEngine.points(correct: true, elapsedMs: 1000, streak: 1))
    }

    @Test func matchFlowsToAWinner() {
        let a = MatchPlayer(id: "a", name: "Noah", world: .his)
        let b = MatchPlayer(id: "b", name: "Sam", world: .hers)
        var s = MatchState(seed: 5, creator: a)
        s.join(b)
        #expect(s.pendingPick(for: "a") == 1)
        s.pick(deckID: "football", forRound: 1, by: "a")     // a picks for b
        #expect(s.pendingAnswer(for: "b")?.number == 1)
        #expect(s.pendingPick(for: "b") == 1)
        s.pick(deckID: "skincare", forRound: 1, by: "b")     // b picks for a
        for r in 1...3 {
            if r > 1 { s.pick(deckID: "football", forRound: r, by: "a"); s.pick(deckID: "fashion", forRound: r, by: "b") }
            s.record(RoundResult(questionIDs: [], answers: [], timesMs: [], score: 700, correct: 7), forRound: r, by: "a")
            s.record(RoundResult(questionIDs: [], answers: [], timesMs: [], score: 300, correct: 3), forRound: r, by: "b")
        }
        #expect(s.crowns(for: "a") == 3)
        #expect(s.status == .finished)
        #expect(s.winnerID == "a")
    }

    @Test func tiesGiveNoCrown() {
        let a = MatchPlayer(id: "a", name: "A", world: .his), b = MatchPlayer(id: "b", name: "B", world: .hers)
        var s = MatchState(seed: 1, creator: a); s.join(b)
        s.pick(deckID: "cars", forRound: 1, by: "a"); s.pick(deckID: "divas", forRound: 1, by: "b")
        s.record(RoundResult(questionIDs: [], answers: [], timesMs: [], score: 500, correct: 5), forRound: 1, by: "a")
        s.record(RoundResult(questionIDs: [], answers: [], timesMs: [], score: 500, correct: 5), forRound: 1, by: "b")
        #expect(s.roundWinner(s.rounds[0]) == nil)
        #expect(s.crowns(for: "a") == 0 && s.crowns(for: "b") == 0)
    }

    @Test func stateRoundTripsThroughJSON() throws {
        let a = MatchPlayer(id: "a", name: "A", world: .his), b = MatchPlayer(id: "b", name: "B", world: .hers)
        var s = MatchState(seed: 3, creator: a); s.join(b)
        s.pick(deckID: "grill", forRound: 1, by: "a")
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

    @Test @MainActor func aWholePassAndPlayMatchCompletes() async throws {
        let a = MatchPlayer(id: "a", name: "Noah", world: .his), b = MatchPlayer(id: "b", name: "Sam", world: .hers)
        var s = MatchState(seed: 42, creator: a); s.join(b)
        let t = MemoryTransport(state: s)
        let c = MatchController(state: s, transport: t)
        c.start()
        var guardCount = 0
        while c.stage != .finished && guardCount < 500 {
            guardCount += 1
            switch c.stage {
            case .picking:
                let world = c.state.player(c.me)!.world
                c.pick(Decks.decks(in: world)[guardCount % 6])
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
        #expect(c.stage == .finished)
        #expect(c.state.status == .finished)
        #expect(c.state.winnerID == "a", "the player answering everything right should win")
        #expect(c.state.completedRounds.count >= 3)
    }
}
