import Foundation

/// Applies football's down-and-distance rules to a raw play result.
enum RulesEngine {
    struct Outcome: Equatable {
        var after: Situation?
        var ending: DriveEnding?
        var firstDown: Bool
    }

    static func apply(_ result: PlayResultKind, call: PlayCall, to s: Situation) -> Outcome {
        switch result {
        case .fumble:
            return Outcome(after: nil, ending: .fumble, firstDown: false)
        case .interception:
            return Outcome(after: nil, ending: .interception, firstDown: false)
        case .punt:
            return Outcome(after: nil, ending: .punt, firstDown: false)
        case .fieldGoalMade:
            return Outcome(after: nil, ending: .fieldGoal, firstDown: false)
        case .fieldGoalMissed:
            return Outcome(after: nil, ending: .missedFieldGoal, firstDown: false)
        case .incomplete:
            return advance(yards: 0, from: s)
        case .sack(let loss):
            return advance(yards: -loss, from: s)
        case .gain(let yards):
            return advance(yards: yards, from: s)
        }
    }

    private static func advance(yards: Int, from s: Situation) -> Outcome {
        let newSpot = s.ballOn + yards
        if newSpot >= 100 {
            return Outcome(after: nil, ending: .touchdown, firstDown: true)
        }
        if yards >= s.yardsToGo {
            return Outcome(after: .firstDown(at: newSpot), ending: nil, firstDown: true)
        }
        if s.down >= 4 {
            return Outcome(after: nil, ending: .turnoverOnDowns, firstDown: false)
        }
        let next = Situation(down: s.down + 1, yardsToGo: s.yardsToGo - yards, ballOn: max(1, newSpot))
        return Outcome(after: next, ending: nil, firstDown: false)
    }

    /// Where the *next* team starts its drive, in that team's own perspective (yards from its own goal).
    static func nextStart(after play: Play) -> Int {
        guard let ending = play.ending else { return 25 }
        switch ending {
        case .touchdown, .fieldGoal:
            return 25 // kickoff, touchback
        case .punt:
            let landing = play.ballAfter
            if landing >= 100 { return 20 } // touchback
            return max(1, 100 - landing)
        case .missedFieldGoal:
            let spotOfKick = play.before.ballOn - 7
            return max(20, 100 - spotOfKick)
        case .turnoverOnDowns, .interception, .fumble:
            return max(1, min(99, 100 - play.before.ballOn))
        }
    }
}
