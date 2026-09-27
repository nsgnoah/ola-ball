package co.nsgsolutions.spinola

import co.nsgsolutions.spinola.model.Deck
import co.nsgsolutions.spinola.model.Decks
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * The files `OlaBallTests/CrossPlatformExportTests.swift` writes into `content/`, on the test
 * classpath via `core/build.gradle.kts`. The Swift side is the reference: if a test here fails,
 * fix Kotlin, never the fixture.
 */
object Fixtures {
    fun text(name: String): String =
        checkNotNull(Fixtures::class.java.getResource("/$name")) { "missing test resource /$name" }.readText()

    /** Tolerates keys a newer export may add, so a fixture can grow without breaking older checks. */
    val json: Json = Json { ignoreUnknownKeys = true }

    /** `content/assets/decks.json`, parsed by the same loader the app uses. Also installs it in [Decks]. */
    val decks: List<Deck> by lazy {
        Decks.load(text("decks.json"))
        Decks.all
    }

    /** `content/golden/engine.json`. */
    val engine: Golden by lazy { json.decodeFromString(Golden.serializer(), text("engine.json")) }

    /** `content/golden/match-state-facts.json`. */
    val matchStateFacts: MatchStateFacts by lazy { json.decodeFromString(MatchStateFacts.serializer(), text("match-state-facts.json")) }

    fun deck(id: String): Deck = checkNotNull(decks.firstOrNull { it.id == id }) { "no deck $id" }

    // Mirrors of `CrossPlatformExportTests.Golden` and `.MatchStateFacts`.

    @Serializable
    class Golden(
        val rng: List<RNGStream>,
        val hashes: List<Hash>,
        val bounded: List<Bounded>,
        val shuffles: List<Shuffle>,
        val draws: List<Draw>,
        val points: List<Points>,
        val scores: List<Score>,
    ) {
        @Serializable class RNGStream(val seed: ULong, val values: List<ULong>)
        @Serializable class Hash(val string: String, val hash: Long)

        /** `Int.random(in: 0..<upperBound, using: &rng)` drawn `values.count` times from one generator. */
        @Serializable class Bounded(val seed: ULong, val upperBound: Int, val values: List<Int>)

        /** `Array(0..<count).shuffled(using: &rng)`. */
        @Serializable class Shuffle(val seed: ULong, val count: Int, val order: List<Int>)
        @Serializable class Draw(val deck: String, val round: Int, val playerID: String, val seed: ULong, val excluding: List<String>, val questionIDs: List<String>)
        @Serializable class Points(val correct: Boolean, val elapsedMs: Int, val streak: Int, val points: Int)
        @Serializable class Score(val deck: String, val round: Int, val playerID: String, val seed: ULong, val answers: List<Int?>, val timesMs: List<Int>, val score: Int, val correct: Int)
    }

    /** What the Kotlin side must compute from `match-state.json` once decoded. */
    @Serializable
    class MatchStateFacts(
        val crowns: Map<String, Int>,
        val totals: Map<String, Int>,
        val status: String,
        val winnerID: String? = null,
        val pendingAnswersFor: Map<String, List<String>>,   // player id -> member ids
        val pendingPicksFor: Map<String, List<String>>,     // player id -> target member ids
        val usedQuestionIDs: List<String>,
    )
}
