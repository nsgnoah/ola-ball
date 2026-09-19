import Foundation

/// Decides which single Coach's Tip (if any) to surface at a given moment.
/// One tip per moment, fundamentals first. Anything skipped shows up next time the situation recurs.
enum TipDirector {
    struct Context {
        var situation: Situation
        var defenseCall: DefenseCall
        var userOnOffense: Bool
        var playsThisGame: Int
        var isFourthQuarter: Bool
        var scoreDiff: Int   // user minus opponent
    }

    static func preSnap(_ ctx: Context, seen: Set<String>) -> Concept? {
        let s = ctx.situation
        var c: [String] = []
        if ctx.userOnOffense {
            if ctx.playsThisGame == 0 { c.append("objective") }
            c.append("drawThePlay")
            if ctx.playsThisGame >= 1 { c.append("gaps") }
            if s.down == 2 { c.append("notation") }
            if s.down == 3 { c.append("thirdDown") }
            if s.down == 4 { c.append("fourthDown") }
            if s.down == 4 && s.inFieldGoalRange { c.append("fieldGoal") }
            if s.down == 4 && !s.inFieldGoalRange { c.append("punt") }
            switch ctx.defenseCall {
            case .stackTheBox: c.append("theBox")
            case .playThePass: c.append("safeties")
            case .blitz: c.append("blitz")
            case .balanced: break
            }
            if ctx.isFourthQuarter {
                switch ctx.scoreDiff {
                case ..<(-8): c.append("twoScores")
                case -8 ... -4: c.append("clutchTD")
                case -3 ... -1: c.append("clutchFG")
                case 1...: c.append("protectLead")
                default: break
                }
            }
            if s.isGoalToGo { c.append("goalToGo") }
            if s.inRedZone && !s.isGoalToGo { c.append("redZone") }
            if ctx.playsThisGame >= 3 { c.append("cornerbacks") }
            if ctx.playsThisGame >= 5 { c.append("linemen") }
        } else {
            c.append("defenseCalls")
            if s.down == 3 && s.yardsToGo >= 7 { c.append("safeties") }
            if s.yardsToGo <= 2 { c.append("theBox") }
        }
        return first(c, notIn: seen)
    }

    static func postPlay(_ play: Play, events: [PlaySim.Event], userOnOffense: Bool, seen: Set<String>) -> Concept? {
        var c: [String] = []
        if let ending = play.ending {
            switch ending {
            case .touchdown: c.append("touchdown")
            case .fieldGoal: c.append("fieldGoal")
            case .missedFieldGoal: c.append("missedFG")
            case .punt: c.append("punt")
            case .turnoverOnDowns: c.append("turnoverOnDowns")
            case .interception: c.append("interception")
            case .fumble: c.append("fumble")
            }
        }
        guard userOnOffense else { return first(c, notIn: seen) }
        if play.gainedFirstDown && play.ending == nil { c.append("firstDown") }
        if events.contains(.sack) { c.append("sack") }
        if events.contains(.incomplete) { c.append("incomplete") }
        if events.contains(.outOfBounds) { c.append("sideline") }
        if events.contains(where: { if case .caught = $0 { return true } else { return false } }) { c.append("separation") }
        if events.contains(.handoff) { c.append("runPlay") }
        if events.contains(.throwStart) { c.append("passPlay") }
        if play.call == .run && !events.contains(.handoff) && events.contains(.snap) { c.append("keeper") }
        return first(c, notIn: seen)
    }

    static func driveStart(userHasBall: Bool, afterScore: Bool, quarter: Int, isOvertime: Bool, seen: Set<String>) -> Concept? {
        var c: [String] = []
        if !userHasBall { c.append("defense") }
        if isOvertime { c.append("overtime") }
        if afterScore { c.append("kickoff") }
        if quarter == 2 { c.append("quarters") }
        return first(c, notIn: seen)
    }

    private static func first(_ ids: [String], notIn seen: Set<String>) -> Concept? {
        for id in ids where !seen.contains(id) {
            if let c = Concept.byID(id) { return c }
        }
        return nil
    }
}
