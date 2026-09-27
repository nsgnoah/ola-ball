package co.nsgsolutions.spinola.services

import co.nsgsolutions.spinola.model.MatchState
import co.nsgsolutions.spinola.model.Profile
import kotlinx.serialization.builtins.MapSerializer
import kotlinx.serialization.builtins.serializer
import kotlinx.serialization.json.Json

/**
 * The one JSON configuration both stores and the online transport use, tuned to read what Swift's
 * JSONEncoder writes and to write what its JSONDecoder reads:
 * - `explicitNulls = false`: a nil optional is an absent key, never `"winnerID": null`
 *   (list elements such as a timed-out answer in `answers` still serialize as `null`);
 * - `encodeDefaults = true`: `version`, `mode`, `status`, empty `rounds`… are always present, as on iOS;
 * - `ignoreUnknownKeys = true`: a newer build on the other phone can add fields without breaking this one.
 */
object MatchJson {
    val json: Json = Json {
        explicitNulls = false
        encodeDefaults = true
        ignoreUnknownKeys = true
    }

    private val matchesSerializer = MapSerializer(String.serializer(), MatchState.serializer())

    fun encode(state: MatchState): String = json.encodeToString(MatchState.serializer(), state)
    fun decode(text: String): MatchState = json.decodeFromString(MatchState.serializer(), text)

    fun encodeMatches(matches: Map<String, MatchState>): String = json.encodeToString(matchesSerializer, matches)
    fun decodeMatches(text: String): Map<String, MatchState> = json.decodeFromString(matchesSerializer, text)

    fun encodeProfile(profile: Profile): String = json.encodeToString(Profile.serializer(), profile)
    fun decodeProfile(text: String): Profile = json.decodeFromString(Profile.serializer(), text)
}
