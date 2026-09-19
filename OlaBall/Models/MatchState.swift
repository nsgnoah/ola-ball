import Foundation

/// Everything two phones need to agree on. Encoded as JSON into the Game Center match data
/// (or into local storage for pass-and-play). Kept small and boring on purpose.
struct MatchPlayer: Codable, Hashable, Identifiable {
    var id: String          // Game Center gamePlayerID, or "local-a" / "local-b"
    var name: String
    var world: World        // the world this player knows; they get quizzed on the other one
}

struct RoundResult: Codable, Hashable {
    var questionIDs: [String]
    var answers: [Int?]     // chosen option index per question; nil = timed out
    var timesMs: [Int]
    var score: Int
    var correct: Int
}

struct Round: Codable, Hashable {
    var number: Int
    /// deckID each player must answer, keyed by that player's id. Chosen by their partner.
    var picks: [String: String] = [:]
    var results: [String: RoundResult] = [:]

    func isComplete(playerIDs: [String]) -> Bool {
        playerIDs.allSatisfy { results[$0] != nil }
    }
}

enum MatchStatus: String, Codable { case active, finished }

struct MatchState: Codable, Hashable {
    static let roundsToWin = 3
    static let maxRounds = 5
    static let questionsPerRound = 7

    var version = 2
    var seed: UInt64
    var players: [MatchPlayer]          // players[0] created the match and moves first
    var rounds: [Round] = []
    var status: MatchStatus = .active
    var winnerID: String?
    /// For pass-and-play. Game Center tracks the current participant itself.
    var turnPlayerID: String?
    /// Highest round number each player has seen the results of.
    var revealed: [String: Int] = [:]
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    init(seed: UInt64, creator: MatchPlayer) {
        self.seed = seed
        self.players = [creator]
        self.turnPlayerID = creator.id
    }

    // MARK: Lookup

    func player(_ id: String) -> MatchPlayer? { players.first { $0.id == id } }
    func partner(of id: String) -> MatchPlayer? { players.first { $0.id != id } }
    var playerIDs: [String] { players.map(\.id) }
    var isReady: Bool { players.count == 2 }

    func crowns(for id: String) -> Int {
        rounds.filter { roundWinner($0) == id }.count
    }

    /// Winner of a completed round, nil if incomplete or tied.
    func roundWinner(_ round: Round) -> String? {
        guard isReady, round.isComplete(playerIDs: playerIDs) else { return nil }
        let a = players[0], b = players[1]
        let sa = round.results[a.id]!.score, sb = round.results[b.id]!.score
        if sa == sb { return nil }
        return sa > sb ? a.id : b.id
    }

    var completedRounds: [Round] { rounds.filter { $0.isComplete(playerIDs: playerIDs) } }

    /// The round a player still has to answer (deck picked, no result yet).
    func pendingAnswer(for id: String) -> Round? {
        rounds.first { $0.picks[id] != nil && $0.results[id] == nil }
    }

    /// The round number the player should pick for their partner, if any.
    func pendingPick(for id: String) -> Int? {
        guard status == .active, let partner = partner(of: id) else { return nil }
        // The lowest round where the partner has no deck yet.
        for r in rounds where r.picks[partner.id] == nil { return r.number }
        if rounds.count < MatchState.maxRounds { return rounds.count + 1 }
        return nil
    }

    // MARK: Mutation

    mutating func join(_ player: MatchPlayer) {
        guard players.count < 2, !players.contains(where: { $0.id == player.id }) else { return }
        players.append(player)
        updatedAt = Date()
    }

    mutating func pick(deckID: String, forRound number: Int, by pickerID: String) {
        guard let partner = partner(of: pickerID) else { return }
        if !rounds.contains(where: { $0.number == number }) { rounds.append(Round(number: number)) }
        rounds[number - 1].picks[partner.id] = deckID
        updatedAt = Date()
    }

    mutating func record(_ result: RoundResult, forRound number: Int, by playerID: String) {
        guard number - 1 < rounds.count else { return }
        rounds[number - 1].results[playerID] = result
        updatedAt = Date()
        evaluate()
    }

    mutating func endTurn(from id: String) {
        turnPlayerID = partner(of: id)?.id
        updatedAt = Date()
    }

    /// Settle the match if someone has three crowns or five rounds are complete.
    mutating func evaluate() {
        guard status == .active, isReady else { return }
        let a = players[0].id, b = players[1].id
        let ca = crowns(for: a), cb = crowns(for: b)
        if ca >= MatchState.roundsToWin { status = .finished; winnerID = a; return }
        if cb >= MatchState.roundsToWin { status = .finished; winnerID = b; return }
        if completedRounds.count >= MatchState.maxRounds {
            status = .finished
            winnerID = ca == cb ? tiebreak(a, b) : (ca > cb ? a : b)
        }
    }

    private func tiebreak(_ a: String, _ b: String) -> String? {
        let ta = rounds.compactMap { $0.results[a]?.score }.reduce(0, +)
        let tb = rounds.compactMap { $0.results[b]?.score }.reduce(0, +)
        if ta == tb { return nil }
        return ta > tb ? a : b
    }

    /// Every question used so far, so a rematch or later round never repeats one.
    var usedQuestionIDs: Set<String> {
        Set(rounds.flatMap { $0.results.values.flatMap(\.questionIDs) })
    }
}
