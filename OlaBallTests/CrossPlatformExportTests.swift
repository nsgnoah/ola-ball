import Testing
import Foundation
@testable import OlaBall

/// The cross-platform contract, written out by the Swift code so the Android port can prove it
/// computes the same thing.
///
/// - `content/assets/decks.json`: every deck and question. The Android app ships this file as an
///   asset and loads it at launch; the iOS app still compiles the Swift source, and this test keeps
///   the two in step.
/// - `content/golden/engine.json`: SplitMix64 streams, string hashes, bounded draws, shuffles,
///   question draws, scores. The Kotlin unit tests replay every one of these.
/// - `content/golden/match-state.json`: one `MatchState` exactly as Swift's JSONEncoder writes it.
///
/// Running the tests regenerates the files. If a file on disk differs from what the code produces,
/// the test rewrites it and then fails once, so a content or rules change cannot ship on one
/// platform only: commit the regenerated file and the next run is green.
struct CrossPlatformExportTests {
    static let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()

    struct QuestionExport: Codable {
        let id: String, tier: Int, prompt: String, correct: String, wrong: [String], fact: String?
        /// Derived from `id` by the seeded shuffle; exported so Android can check its shuffle.
        let options: [String], correctIndex: Int
    }
    struct DeckExport: Codable { let id: String, world: String, title: String, tagline: String, colorHex: String, questions: [QuestionExport] }
    struct ContentExport: Codable { let version: Int, decks: [DeckExport] }

    struct Golden: Codable {
        struct RNGStream: Codable { let seed: UInt64, values: [UInt64] }
        struct Hash: Codable { let string: String, hash: Int }
        /// `Int.random(in: 0..<upperBound, using: &rng)` drawn `values.count` times from one generator.
        struct Bounded: Codable { let seed: UInt64, upperBound: Int, values: [Int] }
        /// `Array(0..<count).shuffled(using: &rng)`.
        struct Shuffle: Codable { let seed: UInt64, count: Int, order: [Int] }
        struct Draw: Codable { let deck: String, round: Int, playerID: String, seed: UInt64, excluding: [String], seen: [String], questionIDs: [String] }
        struct Points: Codable { let correct: Bool, elapsedMs: Int, streak: Int, points: Int }
        struct Score: Codable { let deck: String, round: Int, playerID: String, seed: UInt64, answers: [Int?], timesMs: [Int], score: Int, correct: Int }
        let rng: [RNGStream], hashes: [Hash], bounded: [Bounded], shuffles: [Shuffle], draws: [Draw], points: [Points], scores: [Score]
    }

    /// What the Kotlin side must compute from `match-state.json` once decoded.
    struct MatchStateFacts: Codable {
        let crowns: [String: Int], totals: [String: Int], status: String, winnerID: String?
        let pendingAnswersFor: [String: [String]]      // player id -> member ids
        let pendingPicksFor: [String: [String]]        // player id -> target member ids
        let usedQuestionIDs: [String]
    }

    private static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return e
    }

    /// Writes `data` to `path` if it differs, and reports whether it did.
    @discardableResult
    private static func sync(_ data: Data, to relative: String) throws -> Bool {
        let url = repo.appendingPathComponent(relative)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let existing = try? Data(contentsOf: url)
        if existing == data { return false }
        try data.write(to: url)
        return true
    }

    @Test func exportDecks() throws {
        let decks = Decks.all.map { d in
            DeckExport(id: d.id, world: d.world.rawValue, title: d.title, tagline: d.tagline, colorHex: d.colorHex,
                       questions: d.questions.map { q in
                           QuestionExport(id: q.id, tier: q.tier, prompt: q.prompt, correct: q.correct, wrong: q.wrong, fact: q.fact,
                                          options: q.options, correctIndex: q.correctIndex)
                       })
        }
        let data = try Self.encoder().encode(ContentExport(version: 1, decks: decks))
        let changed = try Self.sync(data, to: "content/assets/decks.json")
        #expect(!changed, "content/assets/decks.json was out of date and has been regenerated; commit it and run again")
    }

    @Test func exportEngineGolden() throws {
        var rng: [Golden.RNGStream] = []
        for seed: UInt64 in [0, 1, 42, 4242, 0x9E37_79B9_7F4A_7C15, UInt64.max] {
            var g = SeededRNG(seed: seed)
            rng.append(.init(seed: seed, values: (0..<8).map { _ in g.next() }))
        }
        let strings = ["", "a", "local-a", "local-a/0", "local-b/1", "football-1", "skincare-36", "G:1234567890", "Noah & Sam", "émoji 🎯"]
        let hashes = strings.map { Golden.Hash(string: $0, hash: $0.stableHash) }
        var bounded: [Golden.Bounded] = []
        for (seed, bound) in [(UInt64(7), 2), (UInt64(7), 3), (UInt64(99), 7), (UInt64(123456), 36), (UInt64.max, 1000)] {
            var g = SeededRNG(seed: seed)
            bounded.append(.init(seed: seed, upperBound: bound, values: (0..<16).map { _ in Int.random(in: 0..<bound, using: &g) }))
        }
        var shuffles: [Golden.Shuffle] = []
        for (seed, count) in [(UInt64(1), 4), (UInt64(5), 12), (UInt64(77), 36), (UInt64(4242), 7)] {
            var g = SeededRNG(seed: seed)
            shuffles.append(.init(seed: seed, count: count, order: Array(0..<count).shuffled(using: &g)))
        }
        var draws: [Golden.Draw] = []
        let football = HisWorld.football
        let skincare = HerWorld.skincare
        let first = MatchEngine.questions(deck: football, round: 2, playerID: "x", seed: 99, excluding: [])
        var rng0 = SeededRNG(seed: 2026)
        let cases: [(Deck, Int, String, UInt64, Set<String>, [String])] = [
            (football, 1, "local-a/0", 4242, [], []),
            (football, 2, "x", 99, [], []),
            (football, 2, "y", 99, [], []),
            (football, 2, "x", 99, Set(first.map(\.id)), []),
            (skincare, 3, "local-b/0", 777, [], []),
            (skincare, 5, "G:abc/1", 1, [], []),
            // Nearly every rookie and pro question is used up: the draw must fall through to other tiers.
            (skincare, 1, "local-a/0", 12, Set(skincare.questions.filter { $0.tier < 3 }.dropLast(2).map(\.id)), []),
            // The unused pool runs dry: the deck must repeat itself to fill the round.
            (football, 4, "local-b/0", 31, Set(football.questions.dropLast(3).map(\.id)), []),
            // This phone has seen some of the deck: unseen questions first.
            (football, 2, "x", 99, [], first.map(\.id)),
            // Every rookie and pro question seen, in a scrambled order: oldest-seen first.
            (skincare, 2, "local-a/0", 5, [], skincare.questions.filter { $0.tier < 3 }.map(\.id).shuffled(using: &rng0)),
        ]
        for (deck, round, pid, seed, excluding, seen) in cases {
            let qs = MatchEngine.questions(deck: deck, round: round, playerID: pid, seed: seed, excluding: excluding, seen: seen)
            draws.append(.init(deck: deck.id, round: round, playerID: pid, seed: seed, excluding: excluding.sorted(), seen: seen, questionIDs: qs.map(\.id)))
        }
        var points: [Golden.Points] = []
        for (c, ms, streak) in [(false, 100, 0), (true, 0, 1), (true, 500, 1), (true, 7_499, 1), (true, 7_500, 1), (true, 14_000, 1), (true, 15_000, 1), (true, 20_000, 1), (true, 1_000, 2), (true, 1_000, 3), (true, 1_000, 4), (true, 1_000, 9), (true, 3_333, 0),
                                 // 49.5 and 48.5 points of time bonus: Swift rounds half away from zero, so 50 and 49.
                                 (true, 150, 1), (true, 450, 1), (true, 750, 2), (true, 14_850, 1)] {
            points.append(.init(correct: c, elapsedMs: ms, streak: streak, points: MatchEngine.points(correct: c, elapsedMs: ms, streak: streak)))
        }
        var scores: [Golden.Score] = []
        let scoreCases: [(Deck, Int, String, UInt64, [Int?], [Int])] = [
            (football, 1, "local-b/0", 4242, [0, 1, 2, 3, nil, 0, 1], [1200, 3400, 15000, 800, 15000, 200, 6000]),
            (skincare, 5, "local-a/0", 4242, [nil, nil, nil, nil, nil, nil, nil], [15000, 15000, 15000, 15000, 15000, 15000, 15000]),
            (football, 3, "x", 99, [0, 0, 0], [100, 100, 100]),           // short answer list
        ]
        for (deck, round, pid, seed, answers, times) in scoreCases {
            let qs = MatchEngine.questions(deck: deck, round: round, playerID: pid, seed: seed, excluding: [])
            // Make some of the answers right on purpose so streaks show up.
            var a = answers
            if a.count == qs.count { for i in [0, 1, 5] where i < a.count { a[i] = a[i] == nil ? nil : qs[i].correctIndex } }
            let r = MatchEngine.score(questions: qs, answers: a, timesMs: times)
            scores.append(.init(deck: deck.id, round: round, playerID: pid, seed: seed, answers: a, timesMs: times, score: r.score, correct: r.correct))
        }
        let golden = Golden(rng: rng, hashes: hashes, bounded: bounded, shuffles: shuffles, draws: draws, points: points, scores: scores)
        let changed = try Self.sync(try Self.encoder().encode(golden), to: "content/golden/engine.json")
        #expect(!changed, "content/golden/engine.json was out of date and has been regenerated; commit it and run again")
    }

    @Test func exportMatchState() throws {
        var s = MatchState(seed: 0xDEAD_BEEF_CAFE_F00D, creator: .team(id: "local-a", members: [("Noah", .his), ("Sam", .hers)]), mode: .teams)
        s.join(.team(id: "local-b", members: [("Alex", .his), ("Jo", .hers)]))
        s.pick(deckID: "football", forMember: "local-b/0", round: 1)
        s.pick(deckID: "skincare", forMember: "local-b/1", round: 1)
        s.pick(deckID: "cars", forMember: "local-a/0", round: 1)
        s.pick(deckID: "divas", forMember: "local-a/1", round: 1)
        func play(_ member: String, _ deck: Deck, round: Int, right: Bool) {
            let qs = MatchEngine.questions(deck: deck, round: round, playerID: member, seed: s.seed, excluding: s.usedQuestionIDs)
            let answers: [Int?] = qs.enumerated().map { i, q in i == 3 ? nil : (right ? q.correctIndex : (q.correctIndex + 1) % 4) }
            let times = qs.indices.map { i in i == 3 ? 15_000 : 1_000 + i * 1_500 }
            s.record(MatchEngine.score(questions: qs, answers: answers, timesMs: times), forMember: member, round: round)
        }
        play("local-b/0", HisWorld.football, round: 1, right: true)
        play("local-b/1", HerWorld.skincare, round: 1, right: false)
        play("local-a/0", HisWorld.cars, round: 1, right: true)
        play("local-a/1", HerWorld.divas, round: 1, right: true)
        s.revealed["local-a"] = 1
        s.pick(deckID: "grill", forMember: "local-b/0", round: 2)
        s.endTurn(from: "local-a")
        // Fixed clocks, so the file is byte-stable. Reference date + 800,000,000.25 seconds.
        s.createdAt = Date(timeIntervalSinceReferenceDate: 800_000_000.25)
        s.updatedAt = Date(timeIntervalSinceReferenceDate: 800_000_100)

        let facts = MatchStateFacts(
            crowns: Dictionary(uniqueKeysWithValues: s.playerIDs.map { ($0, s.crowns(for: $0)) }),
            totals: Dictionary(uniqueKeysWithValues: s.playerIDs.map { ($0, s.total(for: $0)) }),
            status: s.status.rawValue, winnerID: s.winnerID,
            pendingAnswersFor: Dictionary(uniqueKeysWithValues: s.playerIDs.map { ($0, s.pendingAnswers(for: $0).map(\.member.id)) }),
            pendingPicksFor: Dictionary(uniqueKeysWithValues: s.playerIDs.map { ($0, s.pendingPicks(for: $0)?.targets.map(\.id) ?? []) }),
            usedQuestionIDs: s.usedQuestionIDs.sorted())

        // The state is written exactly as the app writes it (JSONEncoder defaults, only sorted so
        // the file is stable): that is the wire format Android must read and write.
        let wire = JSONEncoder()
        wire.outputFormatting = [.sortedKeys, .prettyPrinted, .withoutEscapingSlashes]
        let c1 = try Self.sync(try wire.encode(s), to: "content/golden/match-state.json")
        let c2 = try Self.sync(try Self.encoder().encode(facts), to: "content/golden/match-state-facts.json")
        #expect(!c1 && !c2, "content/golden/match-state*.json was out of date and has been regenerated; commit it and run again")

        // And the app must read its own output back unchanged.
        let back = try JSONDecoder().decode(MatchState.self, from: try JSONEncoder().encode(s))
        #expect(back == s)
    }
}
