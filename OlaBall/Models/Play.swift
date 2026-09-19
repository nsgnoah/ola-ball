import Foundation

enum PlayResultKind: Equatable, Codable, Hashable {
    case gain(Int)               // net yards; negative is a loss
    case incomplete
    case sack(Int)               // yards lost (positive number)
    case fumble
    case interception
    case punt(Int)               // net punt yards
    case fieldGoalMade(Int)      // kick distance
    case fieldGoalMissed(Int)    // kick distance

    var yards: Int {
        switch self {
        case .gain(let y): return y
        case .sack(let l): return -l
        default: return 0
        }
    }
}

enum DriveEnding: String, Codable, Hashable {
    case touchdown, fieldGoal, missedFieldGoal, punt, turnoverOnDowns, interception, fumble

    /// Points awarded to the offense. Touchdowns include the extra point.
    var points: Int {
        switch self {
        case .touchdown: return 7
        case .fieldGoal: return 3
        default: return 0
        }
    }

    var isScore: Bool { points > 0 }
    var isTurnover: Bool { self == .interception || self == .fumble || self == .turnoverOnDowns }

    var headline: String {
        switch self {
        case .touchdown: return "TOUCHDOWN!"
        case .fieldGoal: return "It's good! +3"
        case .missedFieldGoal: return "No good"
        case .punt: return "Punt"
        case .turnoverOnDowns: return "Turnover on downs"
        case .interception: return "INTERCEPTED!"
        case .fumble: return "FUMBLE!"
        }
    }
}

struct Play: Identifiable, Hashable {
    let id = UUID()
    let before: Situation
    let call: PlayCall
    let result: PlayResultKind
    let after: Situation?          // nil when the drive ended
    let ending: DriveEnding?
    let gainedFirstDown: Bool
    let narration: String

    var yards: Int { result.yards }

    /// Where the ball sits after the play, from the offense's perspective.
    var ballAfter: Int {
        if let after { return after.ballOn }
        switch ending {
        case .touchdown: return 100
        case .punt:
            if case .punt(let net) = result { return min(100, before.ballOn + net) }
            return before.ballOn
        default: return before.ballOn
        }
    }

    var headline: String {
        if let ending { return ending.headline }
        if gainedFirstDown { return "First down!" }
        switch result {
        case .incomplete: return "Incomplete"
        case .sack(let l): return "Sacked, −\(l)"
        case .gain(let y):
            if y > 0 { return "+\(y) yards" }
            if y == 0 { return "No gain" }
            return "−\(-y) yards"
        default: return ""
        }
    }

    var isGoodForOffense: Bool {
        if let ending { return ending.isScore }
        if gainedFirstDown { return true }
        return yards >= 4
    }

    var isBadForOffense: Bool {
        if let ending { return ending.isTurnover || ending == .missedFieldGoal }
        return yards < 0
    }
}

struct DriveSummary: Hashable {
    let plays: [Play]
    let ending: DriveEnding
    let startBallOn: Int

    var yards: Int { plays.reduce(0) { $0 + $1.yards } }
    var firstDowns: Int { plays.filter(\.gainedFirstDown).count }
    var endBallOn: Int { plays.last?.ballAfter ?? startBallOn }
}
