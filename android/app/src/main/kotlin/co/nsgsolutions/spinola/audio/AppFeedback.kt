package co.nsgsolutions.spinola.audio

import co.nsgsolutions.spinola.engine.MatchFeedback

/**
 * The app's [MatchFeedback]: the sounds and haptics `MatchController.swift` plays itself when an
 * answer lands and when a turn is handed over. The controller stays free of Android; this is the
 * only place it meets the speaker.
 */
object AppFeedback : MatchFeedback {
    override fun answer(correct: Boolean) {
        SoundKit.play(if (correct) Sound.Correct else Sound.Wrong)
        Haptics.answer(correct)
    }

    override fun swoosh() {
        SoundKit.play(Sound.Swoosh)
    }
}
