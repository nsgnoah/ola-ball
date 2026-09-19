import Foundation

/// Turns a finished play into a headline and a one-line "why".
/// Every "why" names something the coach can do differently next time, in plain words, and never scolds.
enum PlayAnalyst {
    enum Voice { case you, them }

    struct Verdict { let headline: String; let why: String; let good: Bool; let bad: Bool }

    static func verdict(for sim: PlaySim, result: PlayResultKind, gainedFirstDown: Bool, ending: DriveEnding?, perspective: Voice) -> Verdict {
        let you = perspective == .you
        let a = sim.analysis
        let kind = sim.plan.kind
        let threwItAway = result == .incomplete && a.separationAtCatch == nil && a.underPressure

        func headline() -> String {
            if ending == .touchdown { return "TOUCHDOWN!" }
            if let ending { return ending.headline }
            if gainedFirstDown { return "First down!" }
            switch result {
            case .incomplete: return threwItAway ? "Thrown away" : "Incomplete"
            case .sack(let l): return "Sacked, −\(l)"
            case .gain(let y): return y > 0 ? "+\(y) yards" : (y == 0 ? "No gain" : "−\(-y) yards")
            default: return ""
            }
        }

        func why() -> String {
            let subject = you ? "You" : "They"
            let receiver = you ? "your receiver" : "their receiver"
            let qb = you ? "your quarterback" : "their quarterback"
            let route = you ? "your route" : "their route"
            switch result {
            case .sack:
                if let t = a.timeToThrow { return "The rush got home in \(String(format: "%.1f", t)) seconds. A shorter route gets the ball out before that." }
                return "The rush got to \(qb) before \(route) came open. Shorter routes beat the rush."
            case .interception:
                if let sep = a.separationAtCatch, sep < 1.5 { return "\(receiver.sentenceCased) had under a yard of space. Next time look for the receiver with room around him." }
                return "The defender read the throw and jumped it. A sharper cut in the route would have shaken him."
            case .incomplete:
                if threwItAway { return "\(qb.sentenceCased) threw it away to avoid the sack. No loss. A quicker, shorter route would have been open in time." }
                if a.underPressure { return "\(qb.sentenceCased) had to throw early under pressure. A shorter route, or a run, beats a rush like that." }
                if let sep = a.separationAtCatch {
                    if sep < 1.5 { return "The defender was all over \(receiver): under a yard of space. Throw to the side with fewer defenders." }
                    if sim.throwDistanceForAnalysis > 30 { return "A long throw is a low-odds throw, even with space. Shorter throws land more often." }
                    return "\(receiver.sentenceCased) had space; this one just slipped through. Same idea again works."
                }
                return "The pass fell incomplete. No yards lost, and the same read again is fine."
            case .fumble:
                return "A hard hit knocked the ball loose. It's rare and it's bad luck, not a bad call."
            case .gain(let y):
                if kind == .pass {
                    let sep = a.separationAtCatch ?? 0
                    let yac = Int(a.yardsAfterCatch.rounded())
                    if ending == .touchdown { return sep >= 2 ? "\(receiver.sentenceCased) had \(Int(sep)) yards of space and nobody caught him. That's what open looks like." : "Tight window, big finish." }
                    if yac >= 8 { return "Caught with \(Int(sep)) yards of space, then \(yac) more after the catch. Space is yards." }
                    if sep >= 2.5 { return "\(receiver.sentenceCased) was open by \(Int(sep)) yards. Easy pitch and catch." }
                    return "Tight coverage, but the catch was made. Risky; a route away from the defender is safer."
                }
                let box = a.defendersAtPointOfAttack
                if ending == .touchdown { return box <= 1 ? "\(subject) found the empty side of the field. Once past the line, nobody was home." : "Broke through a crowd and outran everyone." }
                if a.breakaway { return "Broke a tackle! That's the running back earning extra yards." }
                if y >= 8 { return box <= 1 ? "\(subject) ran where only \(box) defender was waiting. That's finding the gap." : "Good blocking opened a lane through \(box) defenders." }
                if y >= 3 { return box >= 3 ? "\(subject) ran into \(box) defenders and still got a few. Try the lighter side next time." : "Solid gain. \(box) defender\(box == 1 ? "" : "s") near the hole." }
                if y < 0 { return "Caught behind the line. Aim the run at a gap between blockers, not around the whole line." }
                return box >= 3 ? "\(subject) ran straight into \(box) defenders. Look for the side with fewer bodies." : "The defense won the line on that one. Try the other side, or throw over them."
            default:
                return ""
            }
        }

        let bad: Bool
        let good: Bool
        if let ending { bad = ending.isTurnover || ending == .missedFieldGoal; good = ending.isScore }
        else { bad = result.yards < 0 || result == .incomplete; good = gainedFirstDown || result.yards >= 5 }
        return Verdict(headline: headline(), why: why(), good: good, bad: bad)
    }
}

extension PlaySim {
    var throwDistanceForAnalysis: Float { analysis.separationAtCatch == nil ? 0 : (plan.pathLength) }
}

extension String {
    /// Uppercases only the first character: "your receiver" -> "Your receiver".
    var sentenceCased: String { prefix(1).uppercased() + dropFirst() }
}
