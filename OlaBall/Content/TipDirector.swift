import Foundation

/// Decides which single Coach's Tip (if any) to surface at a given moment.
/// One tip per moment, fundamentals first. Anything skipped shows up next time the situation recurs.
enum TipDirector {
    struct Context {
        var situation: Situation
        var playsThisGame: Int
        var isFourthQuarter: Bool
        var scoreDiff: Int   // user minus opponent
    }

    static func preCall(_ ctx: Context, seen: Set<String>) -> Concept? {
        let s = ctx.situation
        var candidates: [String] = []
        if ctx.playsThisGame == 0 { candidates.append("downs") }
        if ctx.playsThisGame >= 1 { candidates.append("runPlay") }
        if s.down == 2 { candidates.append("notation") }
        if s.down == 3 { candidates.append("thirdDown") }
        if s.down == 4 { candidates.append("fourthDown") }
        if s.down == 4 && s.inFieldGoalRange { candidates.append("fieldGoal") }
        if ctx.isFourthQuarter {
            switch ctx.scoreDiff {
            case ..<(-8): candidates.append("twoScores")
            case -8 ... -4: candidates.append("clutchTD")
            case -3 ... -1: candidates.append("clutchFG")
            case 1...: candidates.append("protectLead")
            default: break
            }
        }
        if s.isGoalToGo { candidates.append("goalToGo") }
        if s.inRedZone && !s.isGoalToGo { candidates.append("redZone") }
        if s.isBackedUp { candidates.append("backedUp") }
        if (50...59).contains(s.ballOn) { candidates.append("midfield") }
        return first(candidates, notIn: seen)
    }

    static func postPlay(_ play: Play, seen: Set<String>) -> Concept? {
        var candidates: [String] = []
        if let ending = play.ending {
            switch ending {
            case .touchdown: candidates.append("touchdown")
            case .fieldGoal: candidates.append("fieldGoal")
            case .missedFieldGoal: candidates.append("missedFG")
            case .punt: candidates.append("punt")
            case .turnoverOnDowns: candidates.append("turnoverOnDowns")
            case .interception: candidates.append("interception")
            case .fumble: candidates.append("fumble")
            }
        } else {
            if play.gainedFirstDown { candidates.append("firstDown") }
            switch play.result {
            case .incomplete: candidates.append("incomplete")
            case .sack: candidates.append("sack")
            default: break
            }
        }
        return first(candidates, notIn: seen)
    }

    static func driveStart(userHasBall: Bool, afterScore: Bool, quarter: Int, isOvertime: Bool, seen: Set<String>) -> Concept? {
        var candidates: [String] = []
        if !userHasBall { candidates.append("defense") }
        if isOvertime { candidates.append("overtime") }
        if afterScore { candidates.append("kickoff") }
        if quarter == 2 { candidates.append("quarters") }
        return first(candidates, notIn: seen)
    }

    private static func first(_ ids: [String], notIn seen: Set<String>) -> Concept? {
        for id in ids where !seen.contains(id) {
            if let c = Concept.byID(id) { return c }
        }
        return nil
    }
}
