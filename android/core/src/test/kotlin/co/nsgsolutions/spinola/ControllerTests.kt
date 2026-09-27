package co.nsgsolutions.spinola

import co.nsgsolutions.spinola.engine.MatchController
import co.nsgsolutions.spinola.engine.MatchTransport
import co.nsgsolutions.spinola.engine.NoFeedback
import co.nsgsolutions.spinola.engine.Stage
import co.nsgsolutions.spinola.model.Decks
import co.nsgsolutions.spinola.model.MatchMode
import co.nsgsolutions.spinola.model.MatchPlayer
import co.nsgsolutions.spinola.model.MatchState
import co.nsgsolutions.spinola.model.MatchStatus
import co.nsgsolutions.spinola.model.World
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test

/** Port of Swift's `ControllerTests`: whole matches driven through `MatchController` with the clock virtual. */
@OptIn(ExperimentalCoroutinesApi::class)
class ControllerTests {
    /** Pass-and-play on one phone: the transport's active side follows the state's turn. */
    class MemoryTransport(var state: MatchState) : MatchTransport {
        var turn: String = state.players[0].id
        override val activePlayerID: String get() = turn
        override val activePlayerName: String get() = state.player(turn)?.name ?: ""
        override val activePlayerWorld: World get() = state.player(turn)?.world ?: World.his
        override val isMyTurn: Boolean get() = true
        override val isPassAndPlay: Boolean get() = true
        override suspend fun submitTurn(state: MatchState) { this.state = state; turn = state.turnPlayerID ?: turn }
        override suspend fun save(state: MatchState) { this.state = state }
    }

    /**
     * An online (Game Center / Play Games) transport: two separate phones, so it is nobody's "pass the
     * phone". `isMyTurn` is whether the local side owns the turn, exactly as the online transport reports it.
     */
    class OnlineTransport(var state: MatchState, var localID: String) : MatchTransport {
        var submissions = 0
        override val activePlayerID: String get() = localID
        override val activePlayerName: String get() = state.player(localID)?.name ?: "Noah"
        override val activePlayerWorld: World get() = state.player(localID)?.world ?: World.his
        override val isMyTurn: Boolean get() = state.turnPlayerID == null || state.turnPlayerID == localID
        override val isPassAndPlay: Boolean get() = false
        override suspend fun submitTurn(state: MatchState) {
            submissions += 1
            // The service hands the turn to the other participant regardless of what the payload says.
            this.state = state.copy(turnPlayerID = state.players.firstOrNull { it.id != localID }?.id)
        }
        override suspend fun save(state: MatchState) { this.state = state }
    }

    /** The controller's scope, as the app would give it: Main, which the test dispatcher stands in for. */
    private lateinit var mainScope: CoroutineScope

    @Before
    fun setUp() {
        Fixtures.decks
        Dispatchers.setMain(StandardTestDispatcher())
        mainScope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    }

    @After
    fun tearDown() {
        mainScope.cancel()
        Dispatchers.resetMain()
    }

    private fun controller(state: MatchState, transport: MatchTransport) = MatchController(state, transport, NoFeedback, mainScope)

    /**
     * The creator of an online match opens it before anyone has accepted. There is no opponent in
     * the state yet, so there is nothing to pick and nothing to answer: the turn has to go over so
     * the other side can join. Regression test for a match that was dead on arrival.
     */
    @Test
    fun aNewOnlineMatchHandsTheFirstTurnOver() = runTest {
        val seed = MatchState.create(seed = 42uL, creator = MatchPlayer.solo(id = "a", name = "Noah", world = World.his))
        val transport = OnlineTransport(seed, localID = "a")
        val c = controller(seed, transport)

        c.start(announce = true)
        advanceUntilIdle()

        assertEquals("the seed state must reach the service", 1, transport.submissions)
        assertNotEquals("the turn must go to the opponent", "a", transport.state.turnPlayerID)
        assertEquals(Stage.Waiting, c.stage)
        c.dispose()
    }

    /** Drives a controller to the end. Side "a" answers everything right; side "b" always taps option 0. */
    private fun TestScope.playOut(c: MatchController): Int {
        c.start(announce = true)
        var guardCount = 0
        val trace = ArrayDeque<String>()
        while (c.stage != Stage.Finished && guardCount < 1500) {
            guardCount += 1
            trace.addLast("${c.me}:${c.stage}")
            if (trace.size > 40) trace.removeFirst()
            when (val stage = c.stage) {
                Stage.SetupTeam -> c.joinTeam(listOf("X" to World.his, "Y" to World.hers))
                is Stage.Picking -> {
                    c.pick(Decks.decks(stage.target.answers)[guardCount % 6])
                    advanceUntilIdle()
                }
                is Stage.Handoff -> c.continueAfterHandoff()
                is Stage.Intro -> c.beginAnswering()
                Stage.Answering -> if (c.revealed) c.nextQuestion() else c.select(if (c.me == "a") (c.currentQuestion?.correctIndex ?: 0) else 0)
                is Stage.RoundReveal -> c.acknowledgeReveal()
                Stage.Waiting -> {
                    advanceUntilIdle()
                    c.start()
                }
                Stage.Finished -> {}
            }
        }
        if (c.stage != Stage.Finished) {
            fail("stalled after $guardCount steps; rounds=${c.state.rounds.size} status=${c.state.status} turn=${c.state.turnPlayerID ?: "-"} trace=${trace.takeLast(12).joinToString(" | ")}")
        }
        return guardCount
    }

    @Test
    fun aWholePassAndPlayMatchCompletes() = runTest {
        var s = MatchState.create(seed = 42uL, creator = MatchPlayer.solo(id = "a", name = "Noah", world = World.his))
        s = s.join(MatchPlayer.solo(id = "b", name = "Sam", world = World.hers))
        val c = controller(s, MemoryTransport(s))
        playOut(c)
        assertEquals(Stage.Finished, c.stage)
        assertEquals(MatchStatus.finished, c.state.status)
        assertEquals("the side answering everything right should win", "a", c.state.winnerID)
        assertTrue(c.state.completedRounds.size >= 3)
        c.dispose()
    }

    @Test
    fun aCouplesMatchCompletesWithHandoffsBetweenMembers() = runTest {
        var s = MatchState.create(seed = 7uL, creator = MatchPlayer.team(id = "a", members = listOf("Noah" to World.his, "Sam" to World.hers)), mode = MatchMode.teams)
        s = s.join(MatchPlayer.team(id = "b", members = listOf("Alex" to World.his, "Jo" to World.hers)))
        val c = controller(s, MemoryTransport(s))
        playOut(c)
        assertEquals(Stage.Finished, c.stage)
        assertEquals("a", c.state.winnerID)
        // Every member of both couples answered every completed round.
        for (r in c.state.completedRounds) {
            assertEquals("round ${r.number} has ${r.results.size} results", 4, r.results.size)
            assertEquals(4, r.picks.size)
        }
        // Lanes were respected: each member's picked deck comes from the world they answer.
        for (r in c.state.rounds) {
            for ((memberID, deckID) in r.picks) {
                assertEquals("$memberID got $deckID", c.state.member(memberID)?.answers, Decks.byID(deckID)?.world)
            }
        }
        c.dispose()
    }

    @Test
    fun aChallengedCoupleJoinsBeforePlaying() = runTest {
        // The creator's phone made the match; this phone ("b") opens it and must set up its couple first.
        val s = MatchState.create(seed = 11uL, creator = MatchPlayer.team(id = "a", members = listOf("Noah" to World.his, "Sam" to World.hers)), mode = MatchMode.teams)
        val t = MemoryTransport(s)
        t.turn = "b"
        val c = controller(s, t)
        c.start(announce = true)
        assertEquals(Stage.SetupTeam, c.stage)
        c.joinTeam(listOf("Alex" to World.his, "Jo" to World.hers))
        assertTrue(c.state.isReady)
        assertEquals("Alex & Jo", c.state.player("b")?.name)
        advanceUntilIdle()
        c.dispose()
    }

    /** A question left alone for 15 s is recorded as a miss; the clock is virtual so the test does not wait. */
    @Test
    fun anUnansweredQuestionTimesOut() = runTest {
        var s = MatchState.create(seed = 42uL, creator = MatchPlayer.solo(id = "a", name = "Noah", world = World.his))
        s = s.join(MatchPlayer.solo(id = "b", name = "Sam", world = World.hers))
        s = s.pick(deckID = "football", memberID = "b/0", round = 1)
        val t = MemoryTransport(s)
        t.turn = "b"
        val c = controller(s, t)
        c.start()
        assertEquals(Stage.Intro(round = 1), c.stage)
        c.beginAnswering()
        assertEquals(Stage.Answering, c.stage)
        advanceUntilIdle()
        assertTrue(c.revealed)
        assertEquals(listOf<Int?>(null), c.answers)
        assertEquals(listOf(15_000), c.timesMs)
        c.dispose()
    }

    /** A failed submit keeps the move on this phone and reports it, and `retrySubmit` sends it again. */
    @Test
    fun aFailedSubmitCanBeRetried() = runTest {
        var s = MatchState.create(seed = 42uL, creator = MatchPlayer.solo(id = "a", name = "Noah", world = World.his))
        s = s.join(MatchPlayer.solo(id = "b", name = "Sam", world = World.hers))
        val flaky = object : MatchTransport {
            var failNext = true
            var submissions = 0
            override val activePlayerID: String get() = "a"
            override val activePlayerName: String get() = "Noah"
            override val activePlayerWorld: World get() = World.his
            override val isMyTurn: Boolean get() = true
            override val isPassAndPlay: Boolean get() = false
            override suspend fun submitTurn(state: MatchState) {
                submissions += 1
                if (failNext) { failNext = false; throw IllegalStateException("no network") }
            }
            override suspend fun save(state: MatchState) {}
        }
        val c = controller(s, flaky)
        c.start()
        val picking = c.stage as Stage.Picking
        c.pick(Decks.decks(picking.target.answers)[0])
        advanceUntilIdle()
        assertEquals("no network", c.error)
        assertEquals(Stage.Waiting, c.stage)
        c.retrySubmit()
        advanceUntilIdle()
        assertEquals(2, flaky.submissions)
        assertEquals(null, c.error)
        c.dispose()
    }
}
