import Foundation

/// Turns a play call into a raw result. Pure and seedable.
enum PlaySimulator {
    static func simulate<R: RandomNumberGenerator>(_ call: PlayCall, in s: Situation, using rng: inout R) -> PlayResultKind {
        switch call {
        case .run:
            let roll = Int.random(in: 0..<100, using: &rng)
            if roll < 2 { return .fumble }
            if roll < 12 { return .gain(clamp(-Int.random(in: 1...3, using: &rng), s)) }
            if roll < 37 { return .gain(clamp(Int.random(in: 0...2, using: &rng), s)) }
            if roll < 72 { return .gain(clamp(Int.random(in: 3...5, using: &rng), s)) }
            if roll < 92 { return .gain(clamp(Int.random(in: 6...9, using: &rng), s)) }
            return .gain(clamp(Int.random(in: 10...25, using: &rng), s))

        case .shortPass:
            let roll = Int.random(in: 0..<100, using: &rng)
            if roll < 3 { return .interception }
            if roll < 7 { return .sack(clampLoss(Int.random(in: 5...8, using: &rng), s)) }
            if roll < 40 { return .incomplete }
            if roll < 82 { return .gain(clamp(Int.random(in: 4...9, using: &rng), s)) }
            if roll < 96 { return .gain(clamp(Int.random(in: 10...16, using: &rng), s)) }
            return .gain(clamp(Int.random(in: 17...30, using: &rng), s))

        case .deepPass:
            // Deep balls stop working when the field gets short.
            let cramped = s.yardsToEndZone < 25
            let roll = Int.random(in: 0..<100, using: &rng)
            if roll < 9 { return .interception }
            if roll < 21 { return .sack(clampLoss(Int.random(in: 6...10, using: &rng), s)) }
            if roll < (cramped ? 82 : 74) { return .incomplete }
            if roll < 94 { return .gain(clamp(Int.random(in: 18...35, using: &rng), s)) }
            return .gain(clamp(Int.random(in: 36...60, using: &rng), s))

        case .punt:
            let net = Int.random(in: 35...52, using: &rng)
            return .punt(net)

        case .fieldGoal:
            let distance = s.fieldGoalDistance
            let made = Double.random(in: 0..<1, using: &rng) < fieldGoalProbability(distance: distance)
            return made ? .fieldGoalMade(distance) : .fieldGoalMissed(distance)
        }
    }

    static func fieldGoalProbability(distance: Int) -> Double {
        switch distance {
        case ..<31: return 0.96
        case 31...40: return 0.87
        case 41...50: return 0.72
        case 51...55: return 0.55
        case 56...62: return 0.30
        default: return 0.10
        }
    }

    /// Beginner-friendly description of a kick's odds.
    static func fieldGoalOddsText(distance: Int) -> String {
        switch fieldGoalProbability(distance: distance) {
        case 0.9...: return "almost automatic"
        case 0.8...: return "likely"
        case 0.65...: return "decent odds"
        case 0.45...: return "coin flip"
        default: return "long shot"
        }
    }

    private static func clamp(_ yards: Int, _ s: Situation) -> Int {
        if yards >= 0 { return min(yards, s.yardsToEndZone) }
        return max(yards, -(s.ballOn - 1))
    }

    private static func clampLoss(_ loss: Int, _ s: Situation) -> Int {
        max(1, min(loss, s.ballOn - 1))
    }
}
