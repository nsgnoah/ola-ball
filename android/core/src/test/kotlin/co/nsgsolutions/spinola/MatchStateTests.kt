package co.nsgsolutions.spinola

import co.nsgsolutions.spinola.model.MatchMode
import co.nsgsolutions.spinola.model.MatchPlayer
import co.nsgsolutions.spinola.model.MatchState
import co.nsgsolutions.spinola.model.MatchStatus
import co.nsgsolutions.spinola.model.RoundResult
import co.nsgsolutions.spinola.model.World
import co.nsgsolutions.spinola.services.MatchJson
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.booleanOrNull
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.math.BigDecimal

/** Ports of Swift's `EngineTests` match-state cases, plus the wire-format check against `match-state.json`. */
class MatchStateTests {
    private fun result(score: Int, correct: Int) = RoundResult(questionIDs = emptyList(), answers = emptyList(), timesMs = emptyList(), score = score, correct = correct)

    @Test
    fun matchFlowsToAWinner() {
        var s = MatchState.create(seed = 5uL, creator = MatchPlayer.solo(id = "a", name = "Noah", world = World.his))
        s = s.join(MatchPlayer.solo(id = "b", name = "Sam", world = World.hers))
        val am = "a/0"
        val bm = "b/0"
        assertEquals(1, s.pendingPicks("a")?.round)
        assertEquals(listOf(bm), s.pendingPicks("a")?.targets?.map { it.id })
        s = s.pick(deckID = "football", memberID = bm, round = 1)     // a picks for b: from his world, since b answers his
        assertEquals(1, s.pendingAnswers("b").firstOrNull()?.round)
        assertEquals(1, s.pendingPicks("b")?.round)
        s = s.pick(deckID = "skincare", memberID = am, round = 1)
        for (r in 1..3) {
            if (r > 1) {
                s = s.pick(deckID = "football", memberID = bm, round = r)
                s = s.pick(deckID = "fashion", memberID = am, round = r)
            }
            s = s.record(result(700, 7), memberID = am, round = r)
            s = s.record(result(300, 3), memberID = bm, round = r)
        }
        assertEquals(3, s.crowns("a"))
        assertEquals(MatchStatus.finished, s.status)
        assertEquals("a", s.winnerID)
    }

    @Test
    fun couplesScoresAddUpAndPicksCoverBothMembers() {
        var s = MatchState.create(seed = 9uL, creator = MatchPlayer.team(id = "a", members = listOf("Noah" to World.his, "Sam" to World.hers)), mode = MatchMode.teams)
        s = s.join(MatchPlayer.team(id = "b", members = listOf("Alex" to World.his, "Jo" to World.hers)))
        assertEquals("Noah & Sam", s.player("a")?.name)
        assertEquals(World.his, s.member("a/0")?.answers)
        assertEquals(World.hers, s.member("a/1")?.answers)
        val picks = s.pendingPicks("a")
        assertEquals(listOf("b/0", "b/1"), picks?.targets?.map { it.id })
        s = s.pick(deckID = "football", memberID = "b/0", round = 1)
        assertEquals(listOf("b/1"), s.pendingPicks("a")?.targets?.map { it.id })
        s = s.pick(deckID = "skincare", memberID = "b/1", round = 1)
        assertTrue(s.pendingPicks("a") == null || s.pendingPicks("a")?.round == 2)
        assertEquals(listOf("b/0", "b/1"), s.pendingAnswers("b").map { it.member.id })
        s = s.record(result(400, 4), memberID = "b/0", round = 1)
        assertEquals(listOf("b/1"), s.pendingAnswers("b").map { it.member.id })
        s = s.record(result(300, 3), memberID = "b/1", round = 1)
        assertTrue(s.pendingAnswers("b").isEmpty())
        s = s.pick(deckID = "cars", memberID = "a/0", round = 1)
        s = s.pick(deckID = "divas", memberID = "a/1", round = 1)
        s = s.record(result(500, 5), memberID = "a/0", round = 1)
        assertNull("round not complete until every member has answered", s.roundWinner(s.rounds[0]))
        s = s.record(result(100, 1), memberID = "a/1", round = 1)
        assertEquals(600, s.rounds[0].score(s.player("a")!!))
        assertEquals(700, s.rounds[0].score(s.player("b")!!))
        assertEquals("b", s.roundWinner(s.rounds[0]))
    }

    @Test
    fun tiesGiveNoCrown() {
        var s = MatchState.create(seed = 1uL, creator = MatchPlayer.solo(id = "a", name = "A", world = World.his))
        s = s.join(MatchPlayer.solo(id = "b", name = "B", world = World.hers))
        s = s.pick(deckID = "cars", memberID = "b/0", round = 1)
        s = s.pick(deckID = "divas", memberID = "a/0", round = 1)
        s = s.record(result(500, 5), memberID = "a/0", round = 1)
        s = s.record(result(500, 5), memberID = "b/0", round = 1)
        assertNull(s.roundWinner(s.rounds[0]))
        assertTrue(s.crowns("a") == 0 && s.crowns("b") == 0)
    }

    @Test
    fun stateRoundTripsThroughJSON() {
        var s = MatchState.create(seed = 3uL, creator = MatchPlayer.team(id = "a", members = listOf("A" to World.his, "B" to World.hers)), mode = MatchMode.teams)
        s = s.join(MatchPlayer.team(id = "b", members = listOf("C" to World.his, "D" to World.hers)))
        s = s.pick(deckID = "grill", memberID = "b/0", round = 1)
        val text = MatchJson.encode(s)
        val back = MatchJson.decode(text)
        assertEquals(s, back)
        assertTrue(text.length < 60_000)
    }

    @Test
    fun aSecondJoinAndAnOutOfRangeRecordAreIgnored() {
        var s = MatchState.create(seed = 3uL, creator = MatchPlayer.solo(id = "a", name = "A", world = World.his))
        s = s.join(MatchPlayer.solo(id = "b", name = "B", world = World.hers))
        assertEquals(s, s.join(MatchPlayer.solo(id = "c", name = "C", world = World.hers)))
        assertEquals(s, s.join(MatchPlayer.solo(id = "a", name = "A", world = World.his)))
        assertEquals(s, s.record(result(1, 1), memberID = "a/0", round = 1))
        assertEquals("b", s.endTurn("a").turnPlayerID)
    }

    // Wire format

    /** The state file Swift wrote decodes, re-encodes to the same JSON tree, and yields the facts Swift computed from it. */
    @Test
    fun swiftWireFormatRoundTrips() {
        val swiftText = Fixtures.text("match-state.json")
        val s = MatchJson.decode(swiftText)
        val kotlinText = MatchJson.encode(s)
        val diff = jsonDiff(Json.parseToJsonElement(swiftText), Json.parseToJsonElement(kotlinText))
        assertNull("Kotlin's JSON differs from Swift's: $diff\n$kotlinText", diff)
        // And what came out reads back as the same value.
        assertEquals(s, MatchJson.decode(kotlinText))

        // Spot checks on the decoded value (a seed above Long.MAX_VALUE, an omitted optional, a timed-out answer).
        assertEquals(0xDEAD_BEEF_CAFE_F00DuL, s.seed)
        assertEquals(3, s.version)
        assertEquals(MatchMode.teams, s.mode)
        assertNull(s.winnerID)
        assertEquals("local-b", s.turnPlayerID)
        assertEquals(800_000_000.25, s.createdAt, 0.0)
        assertEquals(800_000_100.0, s.updatedAt, 0.0)
        assertEquals(listOf(2, 1, 0, null, 0, 3, 1), s.rounds[0].results["local-a/0"]?.answers)
        assertEquals(mapOf("local-a" to 1), s.revealed)
        assertEquals(2, s.rounds.size)
        assertTrue(s.rounds[1].results.isEmpty())
    }

    @Test
    fun swiftMatchStateFactsHold() {
        val s = MatchJson.decode(Fixtures.text("match-state.json"))
        val facts = Fixtures.matchStateFacts
        assertEquals(facts.crowns, s.playerIDs.associateWith { s.crowns(it) })
        assertEquals(facts.totals, s.playerIDs.associateWith { s.total(it) })
        assertEquals(facts.status, s.status.name)
        assertEquals(facts.winnerID, s.winnerID)
        assertEquals(facts.pendingAnswersFor, s.playerIDs.associateWith { id -> s.pendingAnswers(id).map { it.member.id } })
        assertEquals(facts.pendingPicksFor, s.playerIDs.associateWith { id -> s.pendingPicks(id)?.targets?.map { it.id } ?: emptyList() })
        assertEquals(facts.usedQuestionIDs, s.usedQuestionIDs.sorted())
    }

    /**
     * Structural JSON comparison: key order is ignored and numbers compare by value, because
     * Swift writes `800000100` where kotlinx writes `8.000001E8`. Returns the first difference.
     */
    private fun jsonDiff(swift: JsonElement, kotlin: JsonElement, path: String = "$"): String? = when {
        swift is JsonObject && kotlin is JsonObject -> {
            val missingInKotlin = swift.keys - kotlin.keys
            val extraInKotlin = kotlin.keys - swift.keys
            when {
                missingInKotlin.isNotEmpty() -> "$path: Kotlin omits ${missingInKotlin.sorted()}"
                extraInKotlin.isNotEmpty() -> "$path: Kotlin adds ${extraInKotlin.sorted()}"
                else -> swift.keys.sorted().firstNotNullOfOrNull { k -> jsonDiff(swift.getValue(k), kotlin.getValue(k), "$path.$k") }
            }
        }
        swift is JsonArray && kotlin is JsonArray ->
            if (swift.size != kotlin.size) "$path: ${swift.size} elements in Swift, ${kotlin.size} in Kotlin"
            else swift.indices.firstNotNullOfOrNull { i -> jsonDiff(swift[i], kotlin[i], "$path[$i]") }
        swift is JsonNull && kotlin is JsonNull -> null
        swift is JsonNull || kotlin is JsonNull -> "$path: $swift vs $kotlin"
        swift is JsonPrimitive && kotlin is JsonPrimitive -> when {
            swift.isString != kotlin.isString -> "$path: $swift vs $kotlin"
            swift.isString -> if (swift.content == kotlin.content) null else "$path: $swift vs $kotlin"
            swift.booleanOrNull != null || kotlin.booleanOrNull != null -> if (swift.content == kotlin.content) null else "$path: $swift vs $kotlin"
            else -> if (BigDecimal(swift.content).compareTo(BigDecimal(kotlin.content)) == 0) null else "$path: $swift vs $kotlin"
        }
        else -> "$path: ${swift::class.simpleName} vs ${kotlin::class.simpleName}"
    }
}
