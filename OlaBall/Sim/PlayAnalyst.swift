import Foundation

/// Turns a finished play into a headline and a one-line "why".
enum PlayAnalyst {
    enum Voice { case you, them }

    struct Verdict { let headline: String; let why: String; let good: Bool; let bad: Bool }

    static func verdict(for sim: PlaySim, result: PlayResultKind, gainedFirstDown: Bool, ending: DriveEnding?, perspective: Voice) -> Verdict {
        let you = perspective == .you
        let a = sim.analysis
        let kind = sim.plan.kind

        func headline() -> String {
            if ending == .touchdown { return "TOUCHDOWN!" }
            if let ending { return ending.headline }
            if gainedFirstDown { return "First down!" }
            switch result {
            case .incomplete: return "Incomplete"
            case .sack(let l): return "Sacked, −\(l)"
            case .gain(let y): return y > 0 ? "+\(y) yards" : (y == 0 ? "No gain" : "−\(-y) yards")
            default: return ""
            }
        }

        func why() -> String {
            let subject = you ? "You" : "They"
            let receiver = you ? "your receiver" : "their receiver"
            let qb = you ? "your quarterback" : "their quarterback"
            switch result {
            case .sack:
                if let t = a.timeToThrow { return "The rush got home in \(String(format: "%.1f", t)) seconds. A quicker route would have beaten it." }
                return "The rush got to \(qb) before the route came open. Shorter routes beat the blitz."
            case .interception:
                if let sep = a.separationAtCatch, sep < 1.5 { return "\(receiver.capitalized) was covered tight, under a yard of space. Throwing into a crowd is how picks happen." }
                return "The throw was late and the defender jumped it."
            case .incomplete:
                if a.underPressure { return "\(qb.capitalized) had to throw early under pressure and the timing was off." }
                if let sep = a.separationAtCatch {
                    if sep < 1.5 { return "The defender was all over \(receiver): under a yard of space. Look for an open man." }
                    if sim.throwDistanceForAnalysis > 30 { return "A long throw is a low-odds throw, even with space." }
                    return "\(receiver.capitalized) had space; this one just slipped through. Bad luck." }
                return "The pass fell incomplete."
            case .fumble:
                return "A hard hit knocked the ball loose. It happens."
            case .gain(let y):
                if kind == .pass {
                    let sep = a.separationAtCatch ?? 0
                    let yac = Int(a.yardsAfterCatch.rounded())
                    if ending == .touchdown { return sep >= 2 ? "\(receiver.capitalized) had \(Int(sep)) yards of space and nobody caught him. That's what open looks like." : "Tight window, big finish." }
                    if yac >= 8 { return "Caught with \(Int(sep)) yards of space, then \(yac) more after the catch. Space is yards." }
                    if sep >= 2.5 { return "\(receiver.capitalized) was open by \(Int(sep)) yards. Easy pitch and catch." }
                    return "Tight coverage, but the catch was made. Risky, and it worked."
                }
                let box = a.defendersAtPointOfAttack
                if ending == .touchdown { return box <= 1 ? "\(subject) found the empty side of the field. Once past the line, nobody was home." : "Broke through a crowd and outran everyone." }
                if a.breakaway { return "Broke a tackle! That's the running back earning extra yards." }
                if y >= 8 { return box <= 1 ? "\(subject) ran where only \(box) defender was waiting. That's finding the gap." : "Good blocking opened a lane through \(box) defenders." }
                if y >= 3 { return box >= 3 ? "\(subject) ran into \(box) defenders and still got a few. Try the lighter side next time." : "Solid gain. \(box) defender\(box == 1 ? "" : "s") near the hole." }
                return box >= 3 ? "\(subject) ran straight into \(box) defenders. Look for the side with fewer bodies." : "The defense won the line on that one."
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
