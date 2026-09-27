package co.nsgsolutions.spinola.ui.screens

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import co.nsgsolutions.spinola.audio.AppFeedback
import co.nsgsolutions.spinola.engine.MatchController
import co.nsgsolutions.spinola.services.LocalMatchStore
import co.nsgsolutions.spinola.services.PassAndPlayTransport

/**
 * Keeps the open match's [MatchController] alive across activity recreation. On iOS the
 * controller is `@State` on the full-screen cover and survives a rotation for free. On Android a
 * tablet rotation, a fold, or a font-size or dark-mode change recreates the activity, and a
 * controller built inside the composition would die with it: the question clock and the answers
 * given so far this round (which are saved only when the round ends) would vanish, and the player
 * would land back on the hand-off to answer the same seven questions again.
 *
 * One match is open at a time, so this holds at most one controller. It is released when the cover
 * closes or another match opens (see [retainOnly]) and when the activity finishes for good.
 */
class MatchHost : ViewModel() {
    private class Session(val matchID: String, val controller: MatchController) {
        var started = false
    }

    private var session: Session? = null

    /** The controller for [matchID], built on first use from the store's saved state; null if the match is gone. */
    fun controller(matchID: String, store: LocalMatchStore): MatchController? {
        session?.let { if (it.matchID == matchID) return it.controller }
        release()
        val initial = store.matches.value[matchID] ?: return null
        // viewModelScope runs on Dispatchers.Main.immediate, the main-thread contract the controller
        // expects, and outlives the composition. Its in-flight saves are not cancelled on release.
        val controller = MatchController(initial, PassAndPlayTransport(matchID, initial, store), AppFeedback, viewModelScope)
        session = Session(matchID, controller)
        return controller
    }

    /**
     * True exactly once per controller: the first time its screen appears. A recreated activity
     * must not call `start(announce = true)` again, or the phone would re-announce a hand-off in
     * the middle of a question.
     */
    fun claimStart(matchID: String): Boolean {
        val s = session ?: return false
        if (s.matchID != matchID || s.started) return false
        s.started = true
        return true
    }

    fun isStarted(matchID: String): Boolean = session?.let { it.matchID == matchID && it.started } == true

    /** Drops the held controller unless it belongs to [matchID] (null drops it regardless). */
    fun retainOnly(matchID: String?) {
        if (session?.matchID != matchID) release()
    }

    private fun release() {
        session?.controller?.dispose()
        session = null
    }

    override fun onCleared() = release()
}
