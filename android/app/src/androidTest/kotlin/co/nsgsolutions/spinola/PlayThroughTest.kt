package co.nsgsolutions.spinola

import android.content.Context
import android.graphics.Bitmap
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.semantics.SemanticsProperties
import androidx.compose.ui.semantics.getOrNull
import androidx.compose.ui.test.SemanticsMatcher
import androidx.compose.ui.test.captureToImage
import androidx.compose.ui.test.junit4.createEmptyComposeRule
import androidx.compose.ui.test.onAllNodesWithTag
import androidx.compose.ui.test.onNodeWithContentDescription
import androidx.compose.ui.test.onNodeWithTag
import androidx.compose.ui.test.onRoot
import androidx.compose.ui.test.performClick
import androidx.test.core.app.ActivityScenario
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import co.nsgsolutions.spinola.model.MatchPlayer
import co.nsgsolutions.spinola.model.MatchMode
import co.nsgsolutions.spinola.model.MatchState
import co.nsgsolutions.spinola.model.Profile
import co.nsgsolutions.spinola.model.World
import co.nsgsolutions.spinola.services.MatchJson
import org.junit.After
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import androidx.compose.ui.test.performScrollTo

/**
 * Plays a whole pass-and-play match on one phone and saves screenshots, the same walk the iOS
 * UI test takes (OlaBallUITests/PlayThroughUITests.swift), driven by the same identifiers.
 *
 * Screenshots land in the app's external files dir under `shots/`; pull them with
 * `adb pull /sdcard/Android/data/co.nsgsolutions.spinola/files/shots build/android-shots`.
 * `android/scripts/store_shots.sh` does all of that.
 */
@RunWith(AndroidJUnit4::class)
class PlayThroughTest {
    @get:Rule
    val compose = createEmptyComposeRule()

    private lateinit var scenario: ActivityScenario<MainActivity>
    private val context: Context get() = InstrumentationRegistry.getInstrumentation().targetContext
    private val shotDir: File by lazy { File(context.getExternalFilesDir(null), "shots").apply { mkdirs() } }

    /** A ready-made profile and two pass-and-play matches, so the tests can skip the keyboard. Mirrors OlaBallApp.swift. */
    @Before
    fun seed() {
        val profile = Profile(name = "Noah", world = World.his)
        val couple = MatchState.create(seed = 4242uL, creator = MatchPlayer.solo("local-a", "Noah", World.his))
            .join(MatchPlayer.solo("local-b", "Sam", World.hers))
        val teams = MatchState.create(seed = 777uL, creator = MatchPlayer.team("local-a", listOf("Noah" to World.his, "Sam" to World.hers)), mode = MatchMode.teams)
            .join(MatchPlayer.team("local-b", listOf("Alex" to World.his, "Jo" to World.hers)))
        context.getSharedPreferences("ola", Context.MODE_PRIVATE).edit()
            .clear()
            .putString("ola.profile.v1", MatchJson.encodeProfile(profile))
            .putString("ola.localMatches.v1", MatchJson.encodeMatches(mapOf("seed-match" to couple, "seed-teams" to teams)))
            .commit()
        scenario = ActivityScenario.launch(MainActivity::class.java)
    }

    @After
    fun tearDown() {
        scenario.close()
    }

    @Test
    fun privacyAndSupportAreReachableInApp() {
        waitFor("new-local-match")
        compose.onNodeWithContentDescription("More", useUnmergedTree = true).performClick()
        waitFor("open-about")
        compose.onNodeWithTag("open-about", useUnmergedTree = true).performClick()
        waitFor("about-screen")
        snap("11-privacy")
    }

    @Test
    fun passAndPlayMatch() {
        waitFor("new-local-match")
        snap("02-home")
        compose.onNodeWithTag("local-match-seed-match", useUnmergedTree = true).performClick()
        val steps = playOut(maxSteps = 400, prefix = "")
        assertTrue("match never finished after $steps steps", exists("match-over"))
        compose.onNodeWithTag("back-to-matches", useUnmergedTree = true).performClick()
        waitFor("new-local-match")
        snap("10-home-after")
    }

    @Test
    fun passAndPlayCouplesMatch() {
        waitFor("new-local-match")
        compose.onNodeWithTag("local-match-seed-teams", useUnmergedTree = true).performClick()
        val steps = playOut(maxSteps = 900, prefix = "t")
        assertTrue("couples match never finished after $steps steps", exists("match-over"))
    }

    // MARK: Driving

    /** Taps whatever the match asks for until the final screen shows, taking one screenshot per kind of screen. */
    private fun playOut(maxSteps: Int, prefix: String): Int {
        val shots = mutableSetOf<String>()
        fun once(key: String, name: String) { if (shots.add(key)) snap(prefix + name) }
        var steps = 0
        while (steps < maxSteps) {
            steps += 1
            compose.waitForIdle()
            if (exists("match-over")) { once("over", "9-match-over"); break }
            if (exists("handoff-continue")) { once("handoff", "5-handoff"); tap("handoff-continue"); continue }
            if (exists("start-round")) { once("intro", "6-round-intro"); tap("start-round"); continue }
            if (exists("next-question")) { once("answered", "7-answered"); tap("next-question"); continue }
            if (exists("option-0")) { once("question", "7-question"); tap("option-${steps % 4}"); continue }
            if (exists("reveal-continue")) { once("reveal", "8-round-reveal"); tap("reveal-continue"); continue }
            val decks = compose.onAllNodes(hasTestTagPrefix("deck-"), useUnmergedTree = true).fetchSemanticsNodes()
            if (decks.isNotEmpty()) {
                once("pick", "4-pick")
                compose.onAllNodes(hasTestTagPrefix("deck-"), useUnmergedTree = true)[steps % decks.size].performClick()
                continue
            }
            Thread.sleep(200)
        }
        return steps
    }

    private fun exists(tag: String): Boolean =
        compose.onAllNodesWithTag(tag, useUnmergedTree = true).fetchSemanticsNodes().isNotEmpty()

    /** Scrolls the node into view first when it sits in a scrolling column, as a person would on a short phone. */
    private fun tap(tag: String) {
        val node = compose.onAllNodesWithTag(tag, useUnmergedTree = true)[0]
        runCatching { node.performScrollTo() }
        node.performClick()
    }

    private fun waitFor(tag: String, timeoutMs: Long = 10_000) {
        compose.waitUntil(timeoutMs) { exists(tag) }
    }

    private fun hasTestTagPrefix(prefix: String) = SemanticsMatcher("testTag starts with $prefix") {
        it.config.getOrNull(SemanticsProperties.TestTag)?.startsWith(prefix) == true
    }

    /** Waits out the entrance springs first, like the iOS test: a trophy caught mid-flight is a useless store screenshot. */
    private fun snap(name: String) {
        Thread.sleep(900)
        compose.waitForIdle()
        val bitmap = compose.onRoot(useUnmergedTree = true).captureToImage().asAndroidBitmap()
        File(shotDir, "$name.png").outputStream().use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
    }
}
