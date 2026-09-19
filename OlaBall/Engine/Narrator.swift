import Foundation

/// Fun, plain-English play-by-play. Never uses real player names.
enum Narrator {
    enum Voice { case you, them }

    private struct Cast {
        let qb: String, back: String, receiver: String, kicker: String, punter: String, defense: String, they: String
        static func cast(for voice: Voice) -> Cast {
            switch voice {
            case .you: return Cast(qb: "Your quarterback", back: "Your running back", receiver: "Your receiver", kicker: "Your kicker", punter: "Your punter", defense: "Their defense", they: "The other team")
            case .them: return Cast(qb: "Their quarterback", back: "Their running back", receiver: "Their receiver", kicker: "Their kicker", punter: "Their punter", defense: "Your defense", they: "Your team")
            }
        }
    }

    static func line<R: RandomNumberGenerator>(for call: PlayCall, result: PlayResultKind, before: Situation, outcome: RulesEngine.Outcome, voice: Voice, using rng: inout R) -> String {
        let c = Cast.cast(for: voice)
        let touchdown = outcome.ending == .touchdown

        func pick(_ options: [String]) -> String { options.randomElement(using: &rng) ?? options[0] }

        switch result {
        case .fumble:
            return pick(["\(c.back) gets hit and the ball pops loose... \(c.defense) falls on it. Turnover!",
                         "Big hit, and the ball is on the ground! \(c.defense) recovers it."])
        case .interception:
            return pick(["\(c.qb) throws it right into the arms of a defender. Intercepted!",
                         "The pass is tipped... and caught by \(c.defense.lowercased())! Turnover."])
        case .sack(let l):
            return pick(["\(c.qb) can't find anyone open and gets tackled behind the line. Lost \(l) yards.",
                         "The pass rush gets home. \(c.qb) is sacked for a loss of \(l)."])
        case .incomplete:
            return pick(["\(c.qb) throws... it's off the fingertips. Incomplete.",
                         "The throw sails over \(c.receiver.lowercased())'s head. Incomplete.",
                         "Defender knocks it away. Incomplete pass."])
        case .punt(let net):
            if before.ballOn + net >= 100 {
                return "\(c.punter) booms it into the end zone. Touchback: \(c.they) starts at their 20."
            }
            return pick(["\(c.punter) sends it \(net) yards downfield.", "A high, spiraling punt. \(net) yards of field flipped."])
        case .fieldGoalMade(let d):
            return pick(["The snap, the hold, the kick from \(d) yards... it's GOOD! Three points.",
                         "\(c.kicker) splits the uprights from \(d) yards out!"])
        case .fieldGoalMissed(let d):
            return pick(["The \(d)-yard kick drifts wide. No good.",
                         "\(c.kicker) pushes it right from \(d) yards. No points."])
        case .gain(let y):
            switch call {
            case .run:
                if touchdown { return pick(["\(c.back) breaks a tackle and dives into the end zone!", "\(c.back) walks in. Touchdown!"]) }
                if y >= 10 { return pick(["\(c.back) finds a hole and rumbles for \(y) yards!", "Huge run! \(c.back) breaks free for \(y)."]) }
                if y >= 3 { return pick(["Solid run up the middle for \(y).", "\(c.back) muscles ahead for \(y) yards."]) }
                if y >= 0 { return pick(["Stuffed at the line. Just \(y) yard\(y == 1 ? "" : "s").", "\(c.defense) swarms. Only \(y)."]) }
                return pick(["Tackled in the backfield. Lost \(-y) yards.", "Nowhere to go. \(c.back) is dropped for a loss of \(-y)."])
            case .shortPass:
                if touchdown { return pick(["Quick throw, catch, and \(c.receiver.lowercased()) walks into the end zone!", "\(c.qb) fires it in. Touchdown!"]) }
                if y >= 10 { return pick(["Quick throw, and \(c.receiver.lowercased()) turns upfield for \(y)!", "Catch and run for \(y) yards!"]) }
                return pick(["\(c.qb) hits \(c.receiver.lowercased()) for \(y).", "Short completion, \(y) yards."])
            case .deepPass:
                if touchdown { return pick(["\(c.qb) launches it deep... CAUGHT in the end zone! Touchdown!", "Bombs away... and it's a touchdown!"]) }
                return pick(["\(c.qb) throws it deep... CAUGHT! A gain of \(y)!", "Down the sideline for \(y) yards! What a throw."])
            default:
                return "The play gains \(y) yards."
            }
        }
    }
}
