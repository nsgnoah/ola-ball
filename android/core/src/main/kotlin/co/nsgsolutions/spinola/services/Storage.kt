package co.nsgsolutions.spinola.services

import co.nsgsolutions.spinola.engine.MatchTransport
import co.nsgsolutions.spinola.model.MatchMode
import co.nsgsolutions.spinola.model.MatchPlayer
import co.nsgsolutions.spinola.model.MatchState
import co.nsgsolutions.spinola.model.Profile
import co.nsgsolutions.spinola.model.World
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import java.util.UUID
import kotlin.random.Random
import kotlin.random.nextULong

/**
 * The slice of `UserDefaults` / `SharedPreferences` the stores need. The app wraps
 * SharedPreferences; tests use [InMemoryStore]. Keys and JSON payloads are the same as on iOS.
 */
interface KeyValueStore {
    fun getString(key: String): String?

    /** `null` removes the key. */
    fun putString(key: String, value: String?)
}

class InMemoryStore : KeyValueStore {
    private val values = HashMap<String, String>()

    @Synchronized
    override fun getString(key: String): String? = values[key]

    @Synchronized
    override fun putString(key: String, value: String?) {
        if (value == null) values.remove(key) else values[key] = value
    }
}

/** Who you are on this phone (see [Profile]). Saved on every change, under the same key iOS uses. */
class ProfileStore(private val store: KeyValueStore, initial: Profile? = null) {
    private val _profile = MutableStateFlow(initial ?: load())
    val profile: StateFlow<Profile?> = _profile.asStateFlow()

    fun set(profile: Profile?) {
        _profile.value = profile
        save()
    }

    fun reset() = set(null)

    private fun load(): Profile? {
        val text = store.getString(KEY) ?: return null
        return try { MatchJson.decodeProfile(text) } catch (_: Exception) { null }
    }

    private fun save() {
        val profile = _profile.value
        store.putString(KEY, profile?.let { MatchJson.encodeProfile(it) })
    }

    private companion object {
        const val KEY = "ola.profile.v1"
    }
}

/**
 * Every question this phone has shown, oldest first, so the next draw can prefer ones nobody here
 * has seen. Only the answering phone draws a round, so a history that differs per phone can't
 * split a match. Same key and JSON as iOS.
 */
class QuestionHistory(private val store: KeyValueStore) {
    var order: List<String> = load()
        private set

    /** Mark questions as just seen: each moves to the newest end. */
    fun record(ids: List<String>) {
        val fresh = ids.toSet()
        order = order.filter { it !in fresh } + ids
        store.putString(KEY, MatchJson.json.encodeToString(ListSerializer(String.serializer()), order))
    }

    private fun load(): List<String> {
        val text = store.getString(KEY) ?: return emptyList()
        return try { MatchJson.json.decodeFromString(ListSerializer(String.serializer()), text) } catch (_: Exception) { emptyList() }
    }

    companion object {
        const val KEY = "ola.seenQuestions.v1"
    }
}

/** Pass-and-play matches live on this phone only. */
class LocalMatchStore(
    private val store: KeyValueStore,
    private val seedSource: () -> ULong = { Random.nextULong() },
) {
    private val _matches = MutableStateFlow<Map<String, MatchState>>(emptyMap())
    val matches: StateFlow<Map<String, MatchState>> = _matches.asStateFlow()   // keyed by a local id

    /** The questions this phone has shown. It lives here because every Android match is a local one. */
    val history = QuestionHistory(store)

    init { load() }

    fun create(me: Profile, partnerName: String, partnerWorld: World): String {
        val id = newID()
        val state = MatchState.create(seed = seedSource(), creator = MatchPlayer.solo(id = "local-a", name = me.name, world = me.world))
            .join(MatchPlayer.solo(id = "local-b", name = partnerName, world = partnerWorld))
        _matches.value = _matches.value + (id to state)
        save()
        return id
    }

    /** Couple vs couple on one phone. */
    fun createTeams(ours: List<Pair<String, World>>, theirs: List<Pair<String, World>>): String {
        val id = newID()
        val state = MatchState.create(seed = seedSource(), creator = MatchPlayer.team(id = "local-a", members = ours), mode = MatchMode.teams)
            .join(MatchPlayer.team(id = "local-b", members = theirs))
        _matches.value = _matches.value + (id to state)
        save()
        return id
    }

    fun update(id: String, state: MatchState) {
        _matches.value = _matches.value + (id to state)
        save()
    }

    fun delete(id: String) {
        _matches.value = _matches.value - id
        save()
    }

    fun reset() {
        _matches.value = emptyMap()
        save()
    }

    /** Uppercase, like Swift's `UUID().uuidString`, so a list of ids reads the same on both phones. */
    private fun newID(): String = UUID.randomUUID().toString().uppercase()

    private fun load() {
        val text = store.getString(KEY) ?: return
        val m = try { MatchJson.decodeMatches(text) } catch (_: Exception) { return }
        _matches.value = m
    }

    private fun save() {
        store.putString(KEY, MatchJson.encodeMatches(_matches.value))
    }

    private companion object {
        const val KEY = "ola.localMatches.v1"
    }
}

/** Transport for a match played on one phone. The active player is whoever the state says holds the turn. */
class PassAndPlayTransport(
    val id: String,
    initial: MatchState,
    private val store: LocalMatchStore,
) : MatchTransport {
    @Volatile
    private var state: MatchState = initial

    override val activePlayerID: String get() = state.turnPlayerID ?: state.players[0].id
    override val activePlayerName: String get() = state.player(activePlayerID)?.name ?: ""
    override val activePlayerWorld: World get() = state.player(activePlayerID)?.world ?: World.his
    override val isMyTurn: Boolean get() = true
    override val isPassAndPlay: Boolean get() = true

    // On iOS both of these hop to the main actor because they are called from detached Tasks. Here
    // the controller launches them on its own (main) scope, so the assignment and the store write
    // already happen together on that thread.
    override suspend fun submitTurn(state: MatchState) {
        this.state = state
        store.update(id, state)
    }

    override suspend fun save(state: MatchState) {
        this.state = state
        store.update(id, state)
    }
}
