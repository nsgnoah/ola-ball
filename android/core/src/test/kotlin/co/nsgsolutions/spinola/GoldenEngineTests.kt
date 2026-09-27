package co.nsgsolutions.spinola

import co.nsgsolutions.spinola.engine.MatchEngine
import co.nsgsolutions.spinola.model.MatchState
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** `MatchEngine` against the draws, points and scores Swift wrote, plus the ports of `EngineTests`. */
class GoldenEngineTests {
    private val golden = Fixtures.engine
    private val football = Fixtures.deck("football")

    @Test
    fun questionDrawsMatchSwift() {
        for (d in golden.draws) {
            val qs = MatchEngine.questions(deck = Fixtures.deck(d.deck), round = d.round, playerID = d.playerID, seed = d.seed, excluding = d.excluding.toSet())
            assertEquals("${d.deck} round ${d.round} player ${d.playerID} seed ${d.seed} excluding ${d.excluding.size}", d.questionIDs, qs.map { it.id })
        }
    }

    @Test
    fun pointsMatchSwift() {
        for (p in golden.points) {
            assertEquals("correct=${p.correct} elapsed=${p.elapsedMs} streak=${p.streak}", p.points, MatchEngine.points(correct = p.correct, elapsedMs = p.elapsedMs, streak = p.streak))
        }
    }

    @Test
    fun roundScoresMatchSwift() {
        for (s in golden.scores) {
            val qs = MatchEngine.questions(deck = Fixtures.deck(s.deck), round = s.round, playerID = s.playerID, seed = s.seed, excluding = emptySet())
            val r = MatchEngine.score(questions = qs, answers = s.answers, timesMs = s.timesMs)
            val label = "${s.deck} round ${s.round} player ${s.playerID}"
            assertEquals("$label score", s.score, r.score)
            assertEquals("$label correct", s.correct, r.correct)
            assertEquals("$label questionIDs", qs.map { it.id }, r.questionIDs)
            assertEquals("$label answers", s.answers, r.answers)
            assertEquals("$label timesMs", s.timesMs, r.timesMs)
        }
    }

    // Ports of Swift's EngineTests.

    @Test
    fun roundsEscalate() {
        assertEquals(2, MatchEngine.tiers(1).max())
        assertTrue(MatchEngine.tiers(5).all { it == 3 })
        assertEquals(MatchState.questionsPerRound, MatchEngine.tiers(3).size)
    }

    @Test
    fun questionDrawIsDeterministicAndFresh() {
        val a = MatchEngine.questions(deck = football, round = 2, playerID = "x", seed = 99uL, excluding = emptySet())
        val b = MatchEngine.questions(deck = football, round = 2, playerID = "x", seed = 99uL, excluding = emptySet())
        assertEquals(a.map { it.id }, b.map { it.id })
        assertEquals(MatchState.questionsPerRound, a.size)
        val used = a.map { it.id }.toSet()
        val c = MatchEngine.questions(deck = football, round = 2, playerID = "x", seed = 99uL, excluding = used)
        assertTrue(c.map { it.id }.toSet().intersect(used).isEmpty())
        // Two members of one couple on the same deck get different questions.
        val d = MatchEngine.questions(deck = football, round = 2, playerID = "y", seed = 99uL, excluding = emptySet())
        assertNotEquals(a.map { it.id }, d.map { it.id })
    }

    @Test
    fun scoringRewardsSpeedAndStreaks() {
        assertEquals(0, MatchEngine.points(correct = false, elapsedMs = 100, streak = 0))
        val fast = MatchEngine.points(correct = true, elapsedMs = 500, streak = 1)
        val slow = MatchEngine.points(correct = true, elapsedMs = 14_000, streak = 1)
        assertTrue(fast > slow)
        assertTrue(MatchEngine.points(correct = true, elapsedMs = 1000, streak = 3) > MatchEngine.points(correct = true, elapsedMs = 1000, streak = 1))
    }

    @Test
    fun labelsReadAsOnIOS() {
        assertEquals("Rookie", MatchEngine.tierName(1))
        assertEquals("Pro", MatchEngine.tierName(2))
        assertEquals("Legend", MatchEngine.tierName(3))
        assertEquals(listOf("Warm-up", "Getting real", "Pro level", "Legend territory", "Last word"), (1..5).map { MatchEngine.roundLabel(it) })
    }
}
