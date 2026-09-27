package co.nsgsolutions.spinola.audio

import android.os.Build
import android.view.HapticFeedbackConstants
import android.view.View
import java.lang.ref.WeakReference

/**
 * The taps and bumps under the buttons, mirroring `enum Haptics` in `Views/Theme.swift`. Uses
 * [View.performHapticFeedback] only: no VIBRATE permission, and the person's own haptics setting
 * is respected (no `FLAG_IGNORE_GLOBAL_SETTING`). Silent until [attach] gives it a view.
 */
object Haptics {
    private var view: WeakReference<View>? = null

    /** Give it the activity's decor view (`window.decorView`) once, from `onCreate`. */
    fun attach(view: View) {
        this.view = WeakReference(view)
    }

    /** `UIImpactFeedbackGenerator(style: .light)` plus the tap sound at half volume. */
    fun tap() {
        perform(HapticFeedbackConstants.CONTEXT_CLICK)
        SoundKit.play(Sound.Tap, 0.5f)
    }

    /** `UIImpactFeedbackGenerator(style: .heavy)` plus a louder tap. */
    fun heavy() {
        perform(if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.LONG_PRESS)
        SoundKit.play(Sound.Tap, 0.9f)
    }

    /** `UINotificationFeedbackGenerator().notificationOccurred(.success)`. */
    fun success() {
        perform(if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) HapticFeedbackConstants.CONFIRM else HapticFeedbackConstants.CONTEXT_CLICK)
    }

    /** `UINotificationFeedbackGenerator().notificationOccurred(.error)`: a double bump on phones without REJECT. */
    fun failure() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            perform(HapticFeedbackConstants.REJECT)
        } else {
            perform(HapticFeedbackConstants.CLOCK_TICK)
            view?.get()?.postDelayed({ perform(HapticFeedbackConstants.CLOCK_TICK) }, 70)
        }
    }

    fun answer(correct: Boolean) {
        if (correct) success() else failure()
    }

    /** `UISelectionFeedbackGenerator().selectionChanged()`: the wheel passing a deck. */
    fun tick() {
        perform(HapticFeedbackConstants.CLOCK_TICK)
    }

    private fun perform(constant: Int) {
        view?.get()?.performHapticFeedback(constant)
    }
}
