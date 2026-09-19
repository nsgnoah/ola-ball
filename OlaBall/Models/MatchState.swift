import Foundation

/// Everything two phones need to agree on. Encoded as JSON into the Game Center match data
/// (or into local storage for pass-and-play). Kept small and boring on purpose.

enum MatchMode: String, Codable, Hashable {
    case couple   // you vs your partner
    case teams    // your couple vs another couple

    var title: String {
        switch self {
        case .couple: return "Me vs my partner"
        case .teams: return "Our couple vs theirs"
        }
    }
}

/// One person holding a phone. A solo player has one member; a couple has two.
struct Member: Codable, Hashable, Identifiable {
    var id: String          // "\(playerID)/\(index)"
    var name: String
    var knows: World        // colors and the avatar
    var answers: World      // the world this member gets quizzed on
}

struct MatchPlayer: Codable, Hashable, Identifiable {
    var id: String          // Game Center gamePlayerID, or "local-a" / "local-b"
    var name: String        // "Noah" or "Noah & Sam"
    var world: World        // the world this side knows (first member's, for teams)
    var members: [Member]

    var isTeam: Bool { members.count > 1 }

    static func solo(id: String, name: String, world: World) -> MatchPlayer {
        MatchPlayer(id: id, name: name, world: world, members: [Member(id: "\(id)/0", name: name, knows: world, answers: world.other)])
    }

    static func team(id: String, members specs: [(name: String, lane: World)]) -> MatchPlayer {
        let members = specs.enumerated().map { i, m in Member(id: "\(id)/\(i)", name: m.name, knows: m.lane, answers: m.lane) }
        return MatchPlayer(id: id, name: members.map(\.name).joined(separator: " & "), world: members.first?.knows ?? .his, members: members)
    }
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
    /// deckID each member must answer, keyed by member id. Chosen by the other side.
    var picks: [String: String] = [:]
    var results: [String: RoundResult] = [:]

    func isComplete(memberIDs: [String]) -> Bool {
        memberIDs.allSatisfy { results[$0] != nil }
    }

    func score(for player: MatchPlayer) -> Int {
        player.members.compactMap { results[$0.id]?.score }.reduce(0, +)
    }
}

enum MatchStatus: String, Codable { case active, finished }

struct MatchState: Codable, Hashable {
    static let roundsToWin = 3
    static let maxRounds = 5
    static let questionsPerRound = 7

    var version = 3
    var mode: MatchMode = .couple
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

    init(seed: UInt64, creator: MatchPlayer, mode: MatchMode = .couple) {
        self.seed = seed
        self.mode = mode
        self.players = [creator]
        self.turnPlayerID = creator.id
    }

    // MARK: Lookup

    func player(_ id: String) -> MatchPlayer? { players.first { $0.id == id } }
    func partner(of id: String) -> MatchPlayer? { players.first { $0.id != id } }
    func member(_ id: String) -> Member? { players.flatMap(\.members).first { $0.id == id } }
    var playerIDs: [String] { players.map(\.id) }
    var allMemberIDs: [String] { players.flatMap { $0.members.map(\.id) } }
    var isReady: Bool { players.count == 2 }

    func crowns(for id: String) -> Int {
        rounds.filter { roundWinner($0) == id }.count
    }

    func total(for id: String) -> Int {
        guard let p = player(id) else { return 0 }
        return rounds.map { $0.score(for: p) }.reduce(0, +)
    }

    /// Winner of a completed round, nil if incomplete or tied.
    func roundWinner(_ round: Round) -> String? {
        guard isReady, round.isComplete(memberIDs: allMemberIDs) else { return nil }
        let a = players[0], b = players[1]
        let sa = round.score(for: a), sb = round.score(for: b)
        if sa == sb { return nil }
        return sa > sb ? a.id : b.id
    }

    var completedRounds: [Round] { rounds.filter { $0.isComplete(memberIDs: allMemberIDs) } }

    struct PendingAnswer: Hashable { let round: Int; let member: Member }
    struct PendingPick: Hashable { let round: Int; let targets: [Member] }

    /// Members of this side who have a deck to answer, lowest round first, in member order.
    func pendingAnswers(for id: String) -> [PendingAnswer] {
        guard status == .active, let p = player(id) else { return [] }
        for r in rounds {
            let missing = p.members.filter { r.picks[$0.id] != nil && r.results[$0.id] == nil }
            if !missing.isEmpty { return missing.map { PendingAnswer(round: r.number, member: $0) } }
        }
        return []
    }

    /// The other side's members this side still owes a deck, in the lowest such round.
    func pendingPicks(for id: String) -> PendingPick? {
        guard status == .active, let partner = partner(of: id) else { return nil }
        for r in rounds {
            let missing = partner.members.filter { r.picks[$0.id] == nil }
            if !missing.isEmpty { return PendingPick(round: r.number, targets: missing) }
        }
        if rounds.count < MatchState.maxRounds { return PendingPick(round: rounds.count + 1, targets: partner.members) }
        return nil
    }

    // MARK: Mutation

    mutating func join(_ player: MatchPlayer) {
        guard players.count < 2, !players.contains(where: { $0.id == player.id }) else { return }
        players.append(player)
        updatedAt = Date()
    }

    mutating func pick(deckID: String, forMember memberID: String, round number: Int) {
        if !rounds.contains(where: { $0.number == number }) { rounds.append(Round(number: number)) }
        rounds[number - 1].picks[memberID] = deckID
        updatedAt = Date()
    }

    mutating func record(_ result: RoundResult, forMember memberID: String, round number: Int) {
        guard number - 1 < rounds.count else { return }
        rounds[number - 1].results[memberID] = result
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
        let ta = total(for: a), tb = total(for: b)
        if ta == tb { return nil }
        return ta > tb ? a : b
    }

    /// Every question used so far, so a later round never repeats one.
    var usedQuestionIDs: Set<String> {
        Set(rounds.flatMap { $0.results.values.flatMap(\.questionIDs) })
    }
}
