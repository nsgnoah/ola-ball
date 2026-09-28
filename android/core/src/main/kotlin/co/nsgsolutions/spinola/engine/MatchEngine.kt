package co.nsgsolutions.spinola.engine

import co.nsgsolutions.spinola.model.Deck
import co.nsgsolutions.spinola.model.MatchState
import co.nsgsolutions.spinola.model.Question
import co.nsgsolutions.spinola.model.RoundResult
import co.nsgsolutions.spinola.support.SeededRNG
import co.nsgsolutions.spinola.support.shuffled
import co.nsgsolutions.spinola.support.stableHash
import kotlin.math.max
import kotlin.math.min

/** Pure rules: which questions a round asks, how answers score, how the match escalates. */
object MatchEngine {
    const val secondsPerQuestion: Double = 15.0
    const val basePoints = 100
    const val maxTimeBonus = 50
    const val streakBonus = 25

    /** Tier mix per round: rookie questions early, legend questions late. */
    fun tiers(forRound: Int): List<Int> = when (forRound) {
        1 -> listOf(1, 1, 1, 1, 1, 2, 2)
        2 -> listOf(1, 1, 2, 2, 2, 2, 3)
        3 -> listOf(2, 2, 2, 2, 3, 3, 3)
        4 -> listOf(2, 2, 3, 3, 3, 3, 3)
        else -> listOf(3, 3, 3, 3, 3, 3, 3)
    }

    fun tierName(tier: Int): String = when (tier) {
        1 -> "Rookie"
        2 -> "Pro"
        else -> "Legend"
    }

    fun roundLabel(number: Int): String = when (number) {
        1 -> "Warm-up"
        2 -> "Getting real"
        3 -> "Pro level"
        4 -> "Legend territory"
        else -> "Last word"
    }

    /** Deterministic question draw: both phones compute the same list from the match seed. */
    fun questions(deck: Deck, round: Int, playerID: String, seed: ULong, excluding: Set<String>): List<Question> {
        // Wrapping arithmetic, exactly as Swift's `&+` / `&*` on UInt64.
        val rng = SeededRNG(seed + round.toULong() * 1_000_003uL + playerID.stableHash.toULong())
        val pools = HashMap<Int, MutableList<Question>>()
        for (t in 1..3) {
            pools[t] = deck.questions.filter { it.tier == t && it.id !in excluding }.shuffled(rng).toMutableList()
        }
        val out = ArrayList<Question>()
        for (t in tiers(round)) {
            // Prefer the requested tier, then fall back nearby so a well-used deck still plays.
            val order = listOf(t, t + 1, t - 1, t + 2, t - 2).filter { it in 1..3 }
            for (candidate in order) {
                val pool = pools[candidate]
                if (pool != null && pool.isNotEmpty()) {
                    out.add(pool.removeAt(0))
                    break
                }
            }
        }
        // A deck holds 120 questions, 40 per tier, so a match should never run one dry. If it ever
        // does, let the deck repeat itself: a seen question beats a short or empty round.
        if (out.size < MatchState.questionsPerRound) {
            val already = out.map { it.id }.toSet()
            for (q in deck.questions.shuffled(rng)) {
                if (q.id in already) continue
                out.add(q)
                if (out.size == MatchState.questionsPerRound) break
            }
        }
        return out
    }

    /** Points for one answer. */
    fun points(correct: Boolean, elapsedMs: Int, streak: Int): Int {
        if (!correct) return 0
        val fraction = max(0.0, 1 - elapsedMs.toDouble() / (secondsPerQuestion * 1000))
        // Swift's `.rounded()` is half away from zero; `Math.round` matches it for this positive value
        // (kotlin.math.round would round half to even).
        val timeBonus = Math.round(maxTimeBonus.toDouble() * fraction).toInt()
        val streakPart = min(3, max(0, streak - 1)) * streakBonus
        return basePoints + timeBonus + streakPart
    }

    /** Score a full set of answers. */
    fun score(questions: List<Question>, answers: List<Int?>, timesMs: List<Int>): RoundResult {
        var total = 0
        var streak = 0
        var right = 0
        for ((i, q) in questions.withIndex()) {
            val a = if (i < answers.size) answers[i] else null
            val t = if (i < timesMs.size) timesMs[i] else (secondsPerQuestion * 1000).toInt()
            val ok = a == q.correctIndex
            if (ok) { streak += 1; right += 1 } else { streak = 0 }
            total += points(correct = ok, elapsedMs = t, streak = streak)
        }
        return RoundResult(questionIDs = questions.map { it.id }, answers = answers, timesMs = timesMs, score = total, correct = right)
    }
}
