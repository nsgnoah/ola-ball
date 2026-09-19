import Foundation

/// Fictional players. Every club has a stable, deterministic roster: same names and numbers every game.
struct RosterEntry: Hashable {
    let name: String
    let number: Int
}

enum Roster {
    static let lastNames = [
        "Okafor", "Lindqvist", "Haddad", "Nakamura", "Castellano", "Bright", "Duarte", "Kowalski", "Achebe", "Reyes",
        "Sorensen", "Banerjee", "O'Rourke", "Tremblay", "Mbeki", "Halvorsen", "Petrov", "Zhang", "Ferreira", "Oyelaran",
        "Whitfield", "Brandt", "Iversen", "Delacroix", "Sato", "Nwosu", "Kaminski", "Larkin", "Vasquez", "Adeyemi",
        "Fontaine", "Marchetti", "Hernandez", "Bergstrom", "Ali", "Thornton", "Quintero", "Abara", "Lindgren", "Moreau",
        "Beaulieu", "Kessler", "Osei", "Ramirez", "Takahashi", "Winters", "Gallagher", "Nilsson", "Diallo", "Barros",
    ]

    /// Position keys: role short name plus ordinal within that role for a lineup, e.g. "WR1", "OL3", "S0".
    static func key(role: Role, ordinal: Int) -> String { "\(role.shortName)\(ordinal)" }

    private static var cache: [String: [String: RosterEntry]] = [:]

    static func roster(for team: Team) -> [String: RosterEntry] {
        if let r = cache[team.id] { return r }
        var rng = SeededRNG(seed: UInt64(truncatingIfNeeded: team.id.hashValue) &* 0x9E3779B97F4A7C15 &+ 17)
        var names = lastNames
        var used: Set<Int> = []
        var roster: [String: RosterEntry] = [:]
        let slots: [(Role, Int)] = [(.quarterback, 1), (.runningBack, 2), (.wideReceiver, 3), (.tightEnd, 1), (.offensiveLine, 5),
                                    (.defensiveLine, 5), (.linebacker, 3), (.cornerback, 3), (.safety, 2)]
        for (role, count) in slots {
            for i in 0..<count {
                let idx = Int.random(in: 0..<names.count, using: &rng)
                let name = names.remove(at: idx)
                var number = 0
                for _ in 0..<40 {
                    number = Int.random(in: numberRange(for: role), using: &rng)
                    if !used.contains(number) { break }
                }
                used.insert(number)
                roster[key(role: role, ordinal: i)] = RosterEntry(name: name, number: number)
            }
        }
        cache[team.id] = roster
        return roster
    }

    static func entry(team: Team, role: Role, ordinal: Int) -> RosterEntry {
        roster(for: team)[key(role: role, ordinal: ordinal)] ?? RosterEntry(name: "Player", number: 0)
    }

    /// Offensive tag ("RB", "X", "Z", "Y", "TE", "QB") to roster key. The lineup order fixes the ordinals.
    static func key(forOffenseTag tag: String) -> String? {
        switch tag {
        case "QB": return "QB0"
        case "RB": return "RB0"
        case "X": return "WR0"
        case "Z": return "WR1"
        case "Y": return "WR2"
        case "TE": return "TE0"
        default: return nil
        }
    }

    static func numberRange(for role: Role) -> ClosedRange<Int> {
        switch role {
        case .quarterback: return 1...19
        case .runningBack, .cornerback, .safety: return 20...49
        case .wideReceiver: return 10...19
        case .tightEnd: return 80...89
        case .offensiveLine: return 60...79
        case .defensiveLine: return 90...99
        case .linebacker: return 50...59
        }
    }
}
