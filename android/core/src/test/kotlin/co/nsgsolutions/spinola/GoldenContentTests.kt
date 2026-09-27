package co.nsgsolutions.spinola

import co.nsgsolutions.spinola.model.Decks
import co.nsgsolutions.spinola.model.World
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** `decks.json` loads to the same content iOS compiles, with the same option order per question. */
class GoldenContentTests {
    private val decks = Fixtures.decks

    /** Port of Swift's `ContentTests.everyDeckIsWellFormed`. */
    @Test
    fun everyDeckIsWellFormed() {
        assertEquals(18, decks.size)
        for (deck in decks) {
            assertEquals("${deck.id} has ${deck.questions.size} questions", 36, deck.questions.size)
            for (t in 1..3) {
                assertEquals("${deck.id} tier $t", 12, deck.questions.count { it.tier == t })
            }
            for (q in deck.questions) {
                assertEquals(q.id, 3, q.wrong.size)
                assertFalse(q.id, q.wrong.contains(q.correct))
                assertEquals(q.id, 3, q.wrong.toSet().size)
                assertEquals(q.id, 4, q.options.size)
                assertEquals(q.id, q.correct, q.options[q.correctIndex])
                assertTrue(q.id, q.prompt.isNotEmpty() && q.correct.isNotEmpty())
                assertEquals(q.id, deck.id, q.deckID)
            }
        }
        val ids = decks.flatMap { d -> d.questions.map { it.id } }
        assertEquals(ids.size, ids.toSet().size)
        val prompts = decks.flatMap { d -> d.questions.map { it.prompt } }
        assertEquals("duplicate prompts", prompts.size, prompts.toSet().size)
    }

    @Test
    fun bothWorldsAreRepresented() {
        assertEquals(9, Decks.decks(World.hers).size)
        assertEquals(9, Decks.decks(World.his).size)
        assertTrue(Decks.isLoaded)
        assertEquals("football", Decks.byID("football")?.id)
    }

    /** Port of Swift's `ContentTests.optionOrderIsStableAcrossDevices`. */
    @Test
    fun optionOrderIsStableAcrossDevices() {
        val q = decks[0].questions[0]
        assertEquals(q.options, q.options)
        assertTrue("correct answer should not always be first", decks.flatMap { it.questions }.any { it.correctIndex != 0 })
    }

    /** The seeded shuffle in `Question.options` lands every one of the 648 questions exactly where iOS put it. */
    @Test
    fun optionOrderMatchesSwiftForEveryQuestion() {
        val exported = Fixtures.json.decodeFromString(Decks.ContentFile.serializer(), Fixtures.text("decks.json"))
        assertEquals(decks.size, exported.decks.size)
        var checked = 0
        for ((deck, deckJson) in decks.zip(exported.decks)) {
            assertEquals(deck.id, deckJson.id)
            for ((q, qJson) in deck.questions.zip(deckJson.questions)) {
                assertEquals(q.id, qJson.id)
                assertEquals("options of ${q.id}", checkNotNull(qJson.options) { "${q.id} has no exported options" }, q.options)
                assertEquals("correctIndex of ${q.id}", checkNotNull(qJson.correctIndex) { "${q.id} has no exported correctIndex" }, q.correctIndex)
                checked += 1
            }
        }
        assertEquals(648, checked)
    }
}
