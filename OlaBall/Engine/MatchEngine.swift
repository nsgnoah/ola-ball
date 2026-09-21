import Foundation

/// Pure rules: which questions a round asks, how answers score, how the match escalates.
enum MatchEngine {
    static let secondsPerQuestion: Double = 15
    static let basePoints = 100
    static let maxTimeBonus = 50
    static let streakBonus = 25

    /// Tier mix per round: rookie questions early, legend questions late.
    static func tiers(forRound number: Int) -> [Int] {
        switch number {
        case 1: return [1, 1, 1, 1, 1, 2, 2]
        case 2: return [1, 1, 2, 2, 2, 2, 3]
        case 3: return [2, 2, 2, 2, 3, 3, 3]
        case 4: return [2, 2, 3, 3, 3, 3, 3]
        default: return [3, 3, 3, 3, 3, 3, 3]
        }
    }

    static func tierName(_ tier: Int) -> String {
        switch tier {
        case 1: return "Rookie"
        case 2: return "Pro"
        default: return "Legend"
        }
    }

    static func roundLabel(_ number: Int) -> String {
        switch number {
        case 1: return "Warm-up"
        case 2: return "Getting real"
        case 3: return "Pro level"
        case 4: return "Legend territory"
        default: return "Last word"
        }
    }

    /// Deterministic question draw: both phones compute the same list from the match seed.
    static func questions(deck: Deck, round: Int, playerID: String, seed: UInt64, excluding used: Set<String>) -> [Question] {
        var rng = SeededRNG(seed: seed &+ UInt64(round) &* 1_000_003 &+ UInt64(truncatingIfNeeded: playerID.stableHash))
        var pools: [Int: [Question]] = [:]
        for t in 1...3 {
            pools[t] = deck.questions.filter { $0.tier == t && !used.contains($0.id) }.shuffled(using: &rng)
        }
        var out: [Question] = []
        for t in tiers(forRound: round) {
            // Prefer the requested tier, then fall back nearby so a well-used deck still plays.
            let order = [t, t + 1, t - 1, t + 2, t - 2].filter { (1...3).contains($0) }
            for candidate in order {
                if let q = pools[candidate]?.first {
                    pools[candidate]?.removeFirst()
                    out.append(q)
                    break
                }
            }
        }
        // A deck holds 36 questions and a round takes 7, so the sixth time a match lands on the
        // same deck the unused pool runs dry. Rather than hand someone a short (or empty) round,
        // let the deck repeat itself: a seen question is a far better outcome than a blank screen.
        if out.count < MatchState.questionsPerRound {
            let already = Set(out.map(\.id))
            for q in deck.questions.shuffled(using: &rng) where !already.contains(q.id) {
                out.append(q)
                if out.count == MatchState.questionsPerRound { break }
            }
        }
        return out
    }

    /// Points for one answer.
    static func points(correct: Bool, elapsedMs: Int, streak: Int) -> Int {
        guard correct else { return 0 }
        let fraction = max(0, 1 - Double(elapsedMs) / (secondsPerQuestion * 1000))
        let timeBonus = Int((Double(maxTimeBonus) * fraction).rounded())
        let streakPart = min(3, max(0, streak - 1)) * streakBonus
        return basePoints + timeBonus + streakPart
    }

    /// Score a full set of answers.
    static func score(questions: [Question], answers: [Int?], timesMs: [Int]) -> RoundResult {
        var total = 0, streak = 0, right = 0
        for (i, q) in questions.enumerated() {
            let a = i < answers.count ? answers[i] : nil
            let t = i < timesMs.count ? timesMs[i] : Int(secondsPerQuestion * 1000)
            let ok = a == q.correctIndex
            if ok { streak += 1; right += 1 } else { streak = 0 }
            total += points(correct: ok, elapsedMs: t, streak: streak)
        }
        return RoundResult(questionIDs: questions.map(\.id), answers: answers, timesMs: timesMs, score: total, correct: right)
    }
}
