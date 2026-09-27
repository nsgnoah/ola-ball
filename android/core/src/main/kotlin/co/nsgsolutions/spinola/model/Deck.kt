package co.nsgsolutions.spinola.model

import co.nsgsolutions.spinola.support.SeededRNG
import co.nsgsolutions.spinola.support.shuffled
import co.nsgsolutions.spinola.support.stableHash
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json

/**
 * Which "world" a deck belongs to. A player declares the world they know; their partner gets
 * quizzed on it. The constant names are the JSON raw values ("hers", "his"), shared with iOS.
 */
@Serializable
enum class World {
    @SerialName("hers") hers,
    @SerialName("his") his;

    val title: String
        get() = when (this) {
            hers -> "Her World"
            his -> "His World"
        }

    /** What a player who knows this world sees on their own card. */
    val iKnowLine: String
        get() = when (this) {
            hers -> "I know her world"
            his -> "I know his world"
        }

    val blurb: String
        get() = when (this) {
            hers -> "Skincare, fashion, rom-coms, reality TV, pop divas, weddings, book club, wellness, celebrity gossip. Your partner gets quizzed on these."
            his -> "Football, ball sports, cars, grilling, games, gear, action movies, tech, fight night. Your partner gets quizzed on these."
        }

    val other: World
        get() = if (this == hers) his else hers
}

class Question(
    val id: String,
    val deckID: String,
    /** 1 rookie, 2 pro, 3 legend. */
    val tier: Int,
    val prompt: String,
    val correct: String,
    val wrong: List<String>,
    val fact: String?,
) {
    /** Options in a stable shuffled order for this question (the same on both phones). */
    val options: List<String> by lazy {
        val rng = SeededRNG(id.stableHash.toULong() * 0x9E3779B97F4A7C15uL + 7uL)
        (listOf(correct) + wrong).shuffled(rng)
    }

    val correctIndex: Int
        get() = options.indexOf(correct).coerceAtLeast(0)

    override fun equals(other: Any?): Boolean = other is Question && other.id == id
    override fun hashCode(): Int = id.hashCode()
    override fun toString(): String = "Question($id)"
}

class Deck(
    val id: String,
    val world: World,
    val title: String,
    val tagline: String,
    /** Six hex digits, no '#'. The UI layer turns it into a colour. */
    val colorHex: String,
    val questions: List<Question>,
) {
    override fun equals(other: Any?): Boolean = other is Deck && other.id == id
    override fun hashCode(): Int = id.hashCode()
    override fun toString(): String = "Deck($id)"
}

/**
 * The question content. On iOS it is compiled from Swift source; here it is loaded once from
 * `decks.json` (written by the iOS test suite into `content/assets/`, shipped as an asset).
 * Call [load] before anything reads [all]; the Application does it at launch, tests do it in setup.
 */
object Decks {
    @Volatile
    var all: List<Deck> = emptyList()
        private set

    val isLoaded: Boolean get() = all.isNotEmpty()

    fun byID(id: String): Deck? = all.firstOrNull { it.id == id }
    fun decks(world: World): List<Deck> = all.filter { it.world == world }

    fun load(json: String) {
        all = parse(json)
    }

    /** Parses the shared content file without installing it, for tests and tooling. */
    fun parse(json: String): List<Deck> {
        val file = Json { ignoreUnknownKeys = true }.decodeFromString<ContentFile>(json)
        return file.decks.map { d ->
            Deck(
                id = d.id, world = d.world, title = d.title, tagline = d.tagline, colorHex = d.colorHex,
                questions = d.questions.map { q ->
                    Question(id = q.id, deckID = d.id, tier = q.tier, prompt = q.prompt, correct = q.correct, wrong = q.wrong, fact = q.fact)
                },
            )
        }
    }

    @Serializable
    internal class ContentFile(val version: Int = 1, val decks: List<DeckJson>)

    @Serializable
    internal class DeckJson(
        val id: String,
        val world: World,
        val title: String,
        val tagline: String,
        val colorHex: String,
        val questions: List<QuestionJson>,
    )

    /** `options` and `correctIndex` are derived by iOS and exported only so the tests can check the shuffle. */
    @Serializable
    internal class QuestionJson(
        val id: String,
        val tier: Int,
        val prompt: String,
        val correct: String,
        val wrong: List<String>,
        val fact: String? = null,
        val options: List<String>? = null,
        val correctIndex: Int? = null,
    )
}
