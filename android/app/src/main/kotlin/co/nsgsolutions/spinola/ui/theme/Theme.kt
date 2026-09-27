package co.nsgsolutions.spinola.ui.theme

import android.content.Context
import android.provider.Settings
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.PlatformTextStyle
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.LineHeightStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import co.nsgsolutions.spinola.R
import java.text.NumberFormat
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/**
 * Game-show palette: saturated primaries, cream paper, navy ink, brass gold.
 * Mirrors `Views/Theme.swift` on iOS; the hex values are identical.
 */
object Theme {
    val his = Color(0xFF2F56BF)
    val hisDeep = Color(0xFF1A3579)
    val hers = Color(0xFFD6406F)
    val hersDeep = Color(0xFF962352)
    val night = Color(0xFF1A1B4B)
    val nightDeep = Color(0xFF0E0F2E)
    val violet = Color(0xFF4F3DB0)
    val violetDeep = Color(0xFF33267A)
    val gold = Color(0xFFEDB240)
    val goldDeep = Color(0xFFB97F0C)
    val good = Color(0xFF2AA35C)
    val goodDeep = Color(0xFF157A3D)
    val bad = Color(0xFFD9463F)
    val badDeep = Color(0xFFB0271F)
    val ink = Color(0xFF1D1A33)
    val ink2 = Color(0xFF5A5670)
    val ink3 = Color(0xFF9793A8)
    val panel = Color(0xFFFFFBF1)
    val panelEdge = Color(0xFFE0D2B4)
    val cream = Color(0xFFFFF3D9)

    // Kept for parity with the iOS names.
    val paper = Color(0xFFF4EFE4)
    val paperCard = Color(0xFFFFFBF1)
    val rule = Color(0xFFE3DCCD)
    val goodInk = Color(0xFF157A3D)
    val badInk = Color(0xFFB0271F)
    val background = night
    val textPrimary = Color.White
    val textSecondary = Color.White.copy(alpha = 0.75f)
}

/** `Color(hex: "2F56BF")` on iOS. Accepts an optional leading '#'. */
fun colorHex(hex: String): Color {
    val v = hex.trimStart('#').toLong(16)
    return Color(((v shr 16) and 0xFF).toInt(), ((v shr 8) and 0xFF).toInt(), (v and 0xFF).toInt())
}

/** Straight sRGB blend toward [other], opaque. The same arithmetic as `Color.mix(with:by:)` on iOS. */
fun Color.mix(other: Color, by: Float): Color {
    val t = by.coerceIn(0f, 1f)
    return Color(
        red = red + (other.red - red) * t,
        green = green + (other.green - green) * t,
        blue = blue + (other.blue - blue) * t,
        alpha = 1f,
    )
}

/**
 * One dial for "how big is the surface we are drawing on". The phone layout is authored at
 * 393x852 dp; this reports how far it can grow (or, on a tablet only, shrink) to suit the window it
 * actually got. Type, buttons, panels and drawn art all read it, so they grow together instead of
 * the phone layout stranding itself in a narrow column on a big screen.
 *
 * It tracks the WINDOW, not the device: tablets run apps in resizable windows too.
 */
object Viewport {
    const val designWidth = 393f
    const val designHeight = 852f

    var scale by mutableFloatStateOf(1f)
        private set
    var isPad by mutableStateOf(false)
        private set

    /** Seeded from the device class so the very first frame is already right; [fit] corrects it from real geometry. */
    fun seed(isTablet: Boolean) {
        isPad = isTablet
        if (isTablet && scale == 1f) scale = 1.3f
    }

    fun fit(widthDp: Float, heightDp: Float) {
        if (widthDp <= 20f || heightDp <= 20f) return
        val room = min(widthDp / designWidth, heightDp / designHeight)
        // A phone never shrinks: the layout already fits the smallest phone and shrinking it
        // would undercut the reading floors. A tablet may shrink a little, because 0.9 of the
        // phone layout on a tablet is still physically larger than a phone.
        val floor = if (isPad) 0.9f else 1f
        val next = min(1.3f, max(floor, room))
        if (abs(next - scale) > 0.005f) scale = next
    }
}

object UI {
    val scale: Float get() = Viewport.scale
    val isPad: Boolean get() = Viewport.isPad

    /** Scale a hand-placed size (art, avatars, ring diameters). Fonts scale in [AppText]. */
    fun s(v: Float): Float = v * scale
    fun s(v: Int): Float = v * scale
    fun s(v: Dp): Dp = v * scale
}

/** The app's five text sizes. Nothing else. */
object TypeScale {
    const val display = 50f   // one word on a screen
    const val title = 34f     // screen titles
    const val heading = 24f   // card headings, questions
    const val button = 20f
    const val label = 13f
}

/**
 * Type roles. On iOS these are Rockwell (slab serif) for anything loud or read and DIN Condensed
 * Bold for scoreboard numbers and kickers, both shipped with the OS. Android ships neither, so the
 * app bundles the closest open-licence faces (SIL Open Font License 1.1, texts in
 * assets/licenses): Arvo, a geometric slab cut from the same cloth as Rockwell, and Barlow
 * Condensed Bold, which matches DIN Condensed Bold almost stroke for stroke. They were chosen side
 * by side against the real iOS fonts. Swap the families HERE and nowhere else; every text style
 * goes through [AppText].
 */
object Fonts {
    val slab: FontFamily = FontFamily(
        Font(R.font.arvo_regular, FontWeight.Normal),
        Font(R.font.arvo_bold, FontWeight.Bold),
    )
    val condensed: FontFamily = FontFamily(Font(R.font.barlow_condensed_bold, FontWeight.Bold))
}

/** Mirrors the `Font` helpers in `Views/Theme.swift`: canvas scale applied, legibility floors enforced. */
object AppText {
    // DIN Condensed sits small on its em box, so iOS multiplies it by 1.12 for scores and 1.15 for
    // labels. Barlow Condensed sits on its em box the same way, so the factors carry over as they are.
    private const val scoreFactor = 1.12f
    private const val labelFactor = 1.15f

    private fun style(family: FontFamily, weight: FontWeight?, points: Float, tracking: TextUnit = TextUnit.Unspecified): TextStyle {
        val size = UI.s(points)
        return TextStyle(
            fontFamily = family,
            fontWeight = weight,
            fontSize = size.sp,
            lineHeight = (size * 1.18f).sp,
            letterSpacing = tracking,
            platformStyle = PlatformTextStyle(includeFontPadding = false),
            lineHeightStyle = LineHeightStyle(LineHeightStyle.Alignment.Center, LineHeightStyle.Trim.None),
        )
    }

    fun headline(size: Float): TextStyle = style(Fonts.slab, FontWeight.Bold, size)
    fun display(size: Float): TextStyle = style(Fonts.slab, FontWeight.Bold, size)
    fun score(size: Float): TextStyle = style(Fonts.condensed, FontWeight.Bold, size * scoreFactor)
    fun condensed(size: Float): TextStyle = style(Fonts.condensed, FontWeight.Bold, size * labelFactor)
    fun label(size: Float = 13f): TextStyle = style(Fonts.condensed, FontWeight.Bold, max(size, 12f) * labelFactor)
    fun body(size: Float = 17f): TextStyle = style(Fonts.slab, FontWeight.Normal, max(size, 15f))
    fun bodyRegular(size: Float = 17f): TextStyle = style(Fonts.slab, FontWeight.Normal, max(size, 14f))
    fun bodyBold(size: Float = 17f): TextStyle = style(Fonts.slab, FontWeight.Bold, max(size, 15f))

    /**
     * Art type: takes FINAL points and applies no canvas scale and no font scaling. For lettering
     * inside fixed-frame art (the wordmark, an avatar's initial, the timer's count), where the frame
     * has already been scaled and scaling the text again would overflow it. Callers must divide by
     * the current font scale (see [fixedSp]) so the phone's text-size setting does not apply.
     */
    fun logo(finalPoints: Float, fontScale: Float): TextStyle =
        TextStyle(fontFamily = Fonts.slab, fontWeight = FontWeight.Bold, fontSize = fixedSp(finalPoints, fontScale),
            platformStyle = PlatformTextStyle(includeFontPadding = false))

    fun artScore(finalPoints: Float, fontScale: Float): TextStyle =
        TextStyle(fontFamily = Fonts.condensed, fontWeight = FontWeight.Bold, fontSize = fixedSp(finalPoints * scoreFactor, fontScale),
            platformStyle = PlatformTextStyle(includeFontPadding = false))

    /** An sp value that renders at exactly [points] dp regardless of the user's font-size setting. */
    fun fixedSp(points: Float, fontScale: Float): TextUnit = (points / max(0.01f, fontScale)).sp
}

/** True when the phone asks for less motion ("Remove animations" sets the animator scale to 0). */
val LocalReduceMotion = compositionLocalOf { false }

fun reduceMotionEnabled(context: Context): Boolean =
    Settings.Global.getFloat(context.contentResolver, Settings.Global.ANIMATOR_DURATION_SCALE, 1f) == 0f

/**
 * A score as SwiftUI prints `Text("\(n)")`: through the locale's number format, so 1415 reads
 * "1,415" in the US and "1.415" in Germany. Plain string templates would drop the separator.
 */
fun Int.grouped(): String = NumberFormat.getIntegerInstance().format(this)

