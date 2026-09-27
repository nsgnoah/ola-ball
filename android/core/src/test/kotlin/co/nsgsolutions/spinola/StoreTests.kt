package co.nsgsolutions.spinola

import co.nsgsolutions.spinola.model.MatchMode
import co.nsgsolutions.spinola.model.MatchStatus
import co.nsgsolutions.spinola.model.Profile
import co.nsgsolutions.spinola.model.World
import co.nsgsolutions.spinola.services.InMemoryStore
import co.nsgsolutions.spinola.services.LocalMatchStore
import co.nsgsolutions.spinola.services.MatchJson
import co.nsgsolutions.spinola.services.PassAndPlayTransport
import co.nsgsolutions.spinola.services.ProfileStore
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** `ProfileStore`, `LocalMatchStore` and `PassAndPlayTransport` over an in-memory key-value store. */
class StoreTests {
    @Test
    fun profilePersistsAndRoundTrips() {
        val kv = InMemoryStore()
        val store = ProfileStore(kv)
        assertNull(store.profile.value)
        val p = Profile(name = "Noah", world = World.his, teamPartnerName = "Sam", teamMyLane = World.his, teamPartnerLane = World.hers)
        store.set(p)
        assertEquals(p, store.profile.value)
        val raw = kv.getString("ola.profile.v1")!!
        assertEquals(p, MatchJson.decodeProfile(raw))
        assertEquals(p, ProfileStore(kv).profile.value)

        // Optional team fields are omitted when unset, as Swift's encoder does.
        store.set(Profile(name = "Sam", world = World.hers))
        assertFalse(kv.getString("ola.profile.v1")!!.contains("teamPartnerName"))
        assertEquals(Profile(name = "Sam", world = World.hers), ProfileStore(kv).profile.value)

        store.reset()
        assertNull(store.profile.value)
        assertNull(kv.getString("ola.profile.v1"))
    }

    @Test
    fun localMatchesPersistAndRoundTrip() {
        val kv = InMemoryStore()
        val store = LocalMatchStore(kv, seedSource = { 0xDEAD_BEEF_CAFE_F00DuL })
        val id = store.create(me = Profile(name = "Noah", world = World.his), partnerName = "Sam", partnerWorld = World.hers)
        val state = store.matches.value.getValue(id)
        assertEquals(0xDEAD_BEEF_CAFE_F00DuL, state.seed)
        assertEquals(listOf("local-a", "local-b"), state.playerIDs)
        assertEquals("local-a", state.turnPlayerID)
        assertTrue(state.isReady)
        assertEquals(MatchMode.couple, state.mode)
        assertEquals(World.hers, state.member("local-a/0")?.answers)

        val teams = store.createTeams(ours = listOf("Noah" to World.his, "Sam" to World.hers), theirs = listOf("Alex" to World.his, "Jo" to World.hers))
        assertEquals(MatchMode.teams, store.matches.value.getValue(teams).mode)
        assertEquals("Alex & Jo", store.matches.value.getValue(teams).player("local-b")?.name)

        // A fresh store over the same key-value store sees both matches, identical.
        val reloaded = LocalMatchStore(kv)
        assertEquals(store.matches.value, reloaded.matches.value)
        assertEquals(MatchJson.decodeMatches(kv.getString("ola.localMatches.v1")!!), store.matches.value)

        val moved = state.pick(deckID = "football", memberID = "local-b/0", round = 1).endTurn("local-a")
        store.update(id, moved)
        assertEquals("local-b", LocalMatchStore(kv).matches.value.getValue(id).turnPlayerID)

        store.delete(teams)
        assertEquals(setOf(id), LocalMatchStore(kv).matches.value.keys)
        store.reset()
        assertTrue(LocalMatchStore(kv).matches.value.isEmpty())
    }

    @Test
    fun aCorruptStoreLoadsAsEmpty() {
        val kv = InMemoryStore()
        kv.putString("ola.localMatches.v1", "not json")
        kv.putString("ola.profile.v1", "{")
        assertTrue(LocalMatchStore(kv).matches.value.isEmpty())
        assertNull(ProfileStore(kv).profile.value)
    }

    @Test
    fun passAndPlayTransportFlipsTheActivePlayerOnSubmit() = runTest {
        val kv = InMemoryStore()
        val store = LocalMatchStore(kv, seedSource = { 42uL })
        val id = store.create(me = Profile(name = "Noah", world = World.his), partnerName = "Sam", partnerWorld = World.hers)
        val initial = store.matches.value.getValue(id)
        val transport = PassAndPlayTransport(id, initial, store)
        assertEquals("local-a", transport.activePlayerID)
        assertEquals("Noah", transport.activePlayerName)
        assertEquals(World.his, transport.activePlayerWorld)
        assertTrue(transport.isMyTurn)
        assertTrue(transport.isPassAndPlay)

        val saved = initial.pick(deckID = "football", memberID = "local-b/0", round = 1)
        transport.save(saved)
        assertEquals("local-a", transport.activePlayerID)   // a save does not end the turn
        assertEquals(saved, store.matches.value.getValue(id))

        transport.submitTurn(saved.endTurn("local-a"))
        assertEquals("local-b", transport.activePlayerID)
        assertEquals("Sam", transport.activePlayerName)
        assertEquals(World.hers, transport.activePlayerWorld)
        assertEquals("local-b", LocalMatchStore(kv).matches.value.getValue(id).turnPlayerID)
        assertEquals(MatchStatus.active, store.matches.value.getValue(id).status)
    }
}
