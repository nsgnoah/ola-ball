package co.nsgsolutions.spinola.ui.hud

import androidx.compose.runtime.key
import android.graphics.Bitmap
import android.graphics.Matrix
import androidx.compose.animation.core.EaseInOut
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.SpringSpec
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.sizeIn
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicText
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.foundation.verticalScroll
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.geometry.center
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.ImageShader
import androidx.compose.ui.graphics.Outline
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.ShaderBrush
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.TileMode
import androidx.compose.ui.graphics.TransformOrigin
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.scale
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Density
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import co.nsgsolutions.spinola.model.Deck
import co.nsgsolutions.spinola.model.MatchState
import co.nsgsolutions.spinola.model.World
import co.nsgsolutions.spinola.support.SeededRNG
import co.nsgsolutions.spinola.ui.theme.AppText
import co.nsgsolutions.spinola.ui.theme.LocalReduceMotion
import co.nsgsolutions.spinola.ui.theme.Theme
import co.nsgsolutions.spinola.ui.theme.TypeScale
import co.nsgsolutions.spinola.ui.theme.UI
import co.nsgsolutions.spinola.ui.theme.color
import co.nsgsolutions.spinola.ui.theme.mix
import kotlinx.coroutines.delay
import kotlin.math.PI
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.random.Random
import androidx.compose.animation.core.withInfiniteAnimationFrameNanos
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.foundation.ScrollState

// Port of Views/HUD.swift plus the view half of Views/Theme.swift (ChunkyButtonStyle, panel(),
// gameField(), Text.placeholder). Every piece keeps its Swift name so the screens read the same.

// MARK: - Text plumbing

/**
 * The one text primitive under every HUD piece. Foundation's [BasicText], not Material's `Text`:
 * Material merges its own typography (letter spacing, colours) into whatever style it is handed,
 * and the game's type is set entirely by [AppText].
 */
@Composable
internal fun GameText(
    text: String,
    style: TextStyle,
    color: Color,
    modifier: Modifier = Modifier,
    align: TextAlign? = null,
    maxLines: Int = Int.MAX_VALUE,
    overflow: TextOverflow = TextOverflow.Clip,
    autoSize: TextAutoSize? = null,
) {
    val resolved = if (align != null) style.copy(color = color, textAlign = align) else style.copy(color = color)
    BasicText(text = text, modifier = modifier, style = resolved, maxLines = maxLines, overflow = overflow, autoSize = autoSize)
}

/**
 * SwiftUI's `.spring(duration:)` with no bounce: a critically damped spring that settles in about
 * [seconds]. Compose springs are specified by stiffness, and for a unit mass the perceptual
 * duration is 2π/√stiffness.
 */
fun <T> smoothSpring(seconds: Float): SpringSpec<T> =
    spring(dampingRatio = Spring.DampingRatioNoBouncy, stiffness = (2f * PI.toFloat() / seconds).pow(2))

// MARK: - Sticker text

/** Big slab type with a single hard "print" offset underneath. The only text shadow in the app. */
@Composable
fun StickerText(
    text: String,
    size: Float = TypeScale.title,
    color: Color = Color.White,
    align: TextAlign = TextAlign.Center,
    modifier: Modifier = Modifier,
) {
    val style = AppText.headline(size)
    // Shrinks to fit (down to half) before it would wrap past two lines; both layers get the
    // same text and constraints, so they always pick the same size.
    val autoSize = TextAutoSize.StepBased(minFontSize = (UI.s(size) * 0.5f).sp, maxFontSize = UI.s(size).sp, stepSize = 0.5f.sp)
    val print = max(2f, size * 0.055f)
    Box(modifier) {
        // The print layer is decoration: without this every headline is read out twice.
        GameText(text, style, Theme.ink.copy(alpha = 0.3f), Modifier.offset(y = print.dp).clearAndSetSemantics {}, align, maxLines = 2, autoSize = autoSize)
        GameText(text, style, color, align = align, maxLines = 2, autoSize = autoSize)
    }
}

// MARK: - Stage and backgrounds

/**
 * Every screen is a Stage: the backdrop fills the whole window, the content sits in a centred
 * phone-width column. On a phone the column is the screen; on a tablet (either orientation) the set
 * dressing surrounds it instead of the app shrinking into a letterboxed window.
 */
object Layout {
    /**
     * The play column: the stage the game is composed on. Unconstrained on a phone, because there
     * the screen *is* the column. On a tablet it keeps the phone's proportions at the canvas scale,
     * so a screen that pins its header to the top and its button to the bottom composes the same
     * way on both, instead of stranding its middle in a half-screen of empty space. The background
     * still bleeds to every edge behind it.
     */
    val column: Dp? get() = if (UI.isPad) 430.dp * UI.scale else null
    val columnHeight: Dp? get() = if (UI.isPad) 852.dp * UI.scale else null
}

@Composable
fun Stage(background: @Composable () -> Unit, modifier: Modifier = Modifier, content: @Composable BoxScope.() -> Unit) {
    Box(modifier.fillMaxSize()) {
        background()
        val column = Layout.column
        val columnHeight = Layout.columnHeight
        // The app is edge to edge; the backdrop runs under the bars, the content does not.
        Box(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing), contentAlignment = Alignment.Center) {
            val bounded = if (column != null && columnHeight != null) Modifier.sizeIn(maxWidth = column, maxHeight = columnHeight) else Modifier
            Box(bounded.fillMaxSize(), content = content)
        }
    }
}

/**
 * A scrolling screen that centres its content when the content is shorter than the screen, and
 * scrolls normally when it is taller. Without this a tablet shows a top-heavy column above a
 * third of a screen of dead space.
 */
@Composable
fun StageScroll(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    BoxWithConstraints(modifier.fillMaxSize().imePadding()) {
        val minHeight = maxHeight
        Column(
            Modifier.fillMaxWidth().verticalScroll(rememberScrollState()).heightIn(min = minHeight),
            verticalArrangement = Arrangement.Center,
            content = content,
        )
    }
}

/**
 * The column of a screen that does not scroll on iOS: [top] pinned to the top, [bottom] pinned to
 * the bottom, and [middle] centred between them, which is what the iOS `Spacer`s above and below
 * the middle do. When the middle does not fit (a 16:9 phone, a large text size, a long question
 * with Ola's fact under it), the middle scrolls instead of pushing the bottom buttons off the
 * screen or crushing them. On a screen with room to spare it lays out exactly as before.
 */
@Composable
fun PinnedColumn(
    spacing: Dp,
    modifier: Modifier = Modifier,
    scrollState: ScrollState = rememberScrollState(),
    top: @Composable ColumnScope.() -> Unit = {},
    bottom: @Composable ColumnScope.() -> Unit = {},
    middle: @Composable ColumnScope.() -> Unit,
) {
    Column(
        modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(spacing),
    ) {
        top()
        BoxWithConstraints(Modifier.weight(1f).fillMaxWidth()) {
            val room = maxHeight
            Column(
                Modifier
                    .fillMaxWidth()
                    .verticalScroll(scrollState)
                    .heightIn(min = room)
                    // Room for the chunky bottom edges, drop shadows and pop-in overshoot at the
                    // viewport's edges, which a scroll container would otherwise clip.
                    .padding(vertical = 8.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(spacing, Alignment.CenterVertically),
                content = middle,
            )
        }
        bottom()
    }
}

/**
 * Game-show backdrop: a solid colour, sunburst rays turning slowly from above the top edge, a
 * halftone dot band rising from the bottom, paper grain over everything.
 */
@Composable
fun GameBackground(world: World) {
    GameBackground(top = world.color, bottom = if (world == World.his) Theme.hisDeep else Theme.hersDeep)
}

@Composable
fun GameBackground(top: Color, @Suppress("UNUSED_PARAMETER") bottom: Color) {
    // Full-bleed colour is pulled toward night so a whole screen of it reads as a stage, not a highlighter.
    val base = top.mix(Theme.night, 0.34f)
    val reduceMotion = LocalReduceMotion.current
    val spin: State<Float> = if (reduceMotion) {
        remember { mutableFloatStateOf(0f) }
    } else {
        rememberInfiniteTransition(label = "sunburst").animateFloat(
            initialValue = 0f, targetValue = 360f,
            animationSpec = infiniteRepeatable(tween(90_000, easing = LinearEasing), RepeatMode.Restart),
            label = "spin",
        )
    }
    Box(
        Modifier.fillMaxSize().drawWithCache {
            val centre = Offset(size.width / 2f, -size.height * 0.08f)
            val sunburst = sunburstPath(size, rays = 18, centre = centre)
            val halftone = halftonePath(size, spacing = 13.dp.toPx(), unit = density)
            // One grain pixel per dp, as one per point on iOS.
            val grainShader = ImageShader(Grain.image, TileMode.Repeated, TileMode.Repeated).apply {
                setLocalMatrix(Matrix().apply { setScale(density, density) })
            }
            val grain = ShaderBrush(grainShader)
            val vignette = Brush.radialGradient(
                0f to Theme.nightDeep.copy(alpha = 0f),
                160f / 640f to Theme.nightDeep.copy(alpha = 0f),
                1f to Theme.nightDeep.copy(alpha = 0.45f),
                center = size.center,
                radius = 640.dp.toPx(),
            )
            onDrawBehind {
                drawRect(base)
                rotate(spin.value, pivot = centre) { drawPath(sunburst, Color.White, alpha = 0.07f) }
                drawPath(halftone, Theme.nightDeep, alpha = 0.28f)
                drawRect(grain, alpha = 0.12f, blendMode = BlendMode.Overlay)
                drawRect(vignette)
            }
        },
    )
}

/**
 * `Sunburst` on iOS: [rays] wedges radiating from [centre], long enough to leave the window from
 * any angle. The backdrop uses 18 rays; the world cards on the profile screen use 12. The default
 * centre is the one `Sunburst.path(in:)` picks: just above the top edge, halfway across.
 */
fun sunburstPath(size: Size, rays: Int = 18, centre: Offset = Offset(size.width / 2f, -size.height * 0.08f)): Path {
    val p = Path()
    val radius = size.height * 2.4f
    val n = rays * 2
    val a = 2.0 * PI / n
    for (i in 0 until n step 2) {
        val a0 = i * a
        val a1 = a0 + a
        p.moveTo(centre.x, centre.y)
        p.lineTo(centre.x + radius * cos(a0).toFloat(), centre.y + radius * sin(a0).toFloat())
        p.lineTo(centre.x + radius * cos(a1).toFloat(), centre.y + radius * sin(a1).toFloat())
        p.close()
    }
    return p
}

/**
 * `Halftone` on iOS: dots that grow toward the bottom edge, rows staggered by half a step. iOS
 * works in points; here [spacing] is already in pixels and [unit] is pixels per dp, so the dot
 * radius (0.5 to 5.1 points on iOS) scales with the screen density exactly as the spacing does.
 */
private fun halftonePath(size: Size, spacing: Float, unit: Float): Path {
    val p = Path()
    val startY = size.height * 0.58f
    var y = startY
    var row = 0
    while (y < size.height + spacing) {
        val t = (y - startY) / max(1f, size.height - startY)
        val r = (0.5f + 4.6f * t * t) * unit
        var x = if (row % 2 == 0) 0f else spacing / 2f
        while (x < size.width + spacing) {
            p.addOval(Rect(x - r, y - r, x + r, y + r))
            x += spacing
        }
        y += spacing * 0.87f
        row += 1
    }
    return p
}

/** Paper grain, generated once and tiled. The same pixels as `Grain.image` on iOS. */
object Grain {
    val image: ImageBitmap by lazy {
        val n = 96
        val rng = SeededRNG(99uL)
        val pixels = IntArray(n * n)
        for (y in 0 until n) {
            for (x in 0 until n) {
                if (rng.nextInt(3) != 0) continue   // one pixel in three
                val white = rng.nextUnitFloat() > 0.5f
                val alpha = 0.25f + 0.75f * rng.nextClosedUnitFloat()
                val a = (alpha * 255f).roundToInt().coerceIn(0, 255)
                pixels[y * n + x] = (a shl 24) or (if (white) 0xFFFFFF else 0x000000)
            }
        }
        Bitmap.createBitmap(pixels, n, n, Bitmap.Config.ARGB_8888).asImageBitmap()
    }

    /**
     * Swift's `Float.random(in: 0..<1, using:)`: 24 random significand bits drawn with a 32-bit
     * bounded draw, scaled by 2^-24.
     */
    private fun SeededRNG.nextUnitFloat(): Float = nextUInt32(1u shl 24).toFloat() * (1f / (1 shl 24))

    /** Swift's `Float.random(in: 0...1, using:)`: the closed range draws one more value so 1 is reachable. */
    private fun SeededRNG.nextClosedUnitFloat(): Float = nextUInt32((1u shl 24) + 1u).toFloat() * (1f / (1 shl 24))

    /** `RandomNumberGenerator.next(upperBound:)` for a `UInt32`: Lemire on the low 32 bits of the 64-bit word. */
    private fun SeededRNG.nextUInt32(upperBound: UInt): UInt {
        var random = next().toUInt()
        var m = random.toULong() * upperBound.toULong()
        var low = m.toUInt()
        if (low < upperBound) {
            val t = (0u - upperBound) % upperBound
            while (low < t) {
                random = next().toUInt()
                m = random.toULong() * upperBound.toULong()
                low = m.toUInt()
            }
        }
        return (m shr 32).toUInt()
    }
}

// MARK: - Small pieces

/**
 * Small caps label. Used for section titles and one-line context, nothing else.
 *
 * Only the default white kickers get the lift. They sit on whatever deck colour the round happens
 * to be, where a tight ink shadow keeps them readable on the pale ones. A kicker given its own
 * colour is on a light panel, where the same shadow just smudges the letters.
 */
@Composable
fun Kicker(text: String, color: Color? = null, size: Float = TypeScale.label, modifier: Modifier = Modifier) {
    val density = LocalDensity.current.density
    val lifted = color == null
    val style = AppText.label(size).copy(
        letterSpacing = 1.1.sp,
        shadow = if (lifted) Shadow(Theme.ink.copy(alpha = 0.45f), Offset(0f, 1f * density), 1f * density) else null,
    )
    GameText(text.uppercase(), style, color ?: Color.White.copy(alpha = 0.85f), modifier)
}

@Composable
fun WorldTag(world: World) {
    Box(Modifier.background(world.color, CircleShape).padding(horizontal = 10.dp, vertical = 6.dp)) {
        GameText(world.title.uppercase(), AppText.label(11f).copy(letterSpacing = 0.8.sp), Color.White)
    }
}

/** A player's avatar: initial on a world-coloured disc with a white rim. */
@Composable
fun Avatar(name: String, world: World, size: Float = 40f, modifier: Modifier = Modifier) {
    val s = UI.s(size)
    val fontScale = LocalDensity.current.fontScale
    val color = world.color
    val shadow = color.mix(Color.Black, 0.25f)
    Box(
        modifier.size(s.dp).drawBehind {
            val r = this.size.minDimension / 2f
            drawCircle(shadow, r, center + Offset(0f, this.size.height * 0.06f))
            drawCircle(color, r)
            drawCircle(Color.White, r, style = Stroke(max(2.dp.toPx(), this.size.height * 0.06f)))
        },
        contentAlignment = Alignment.Center,
    ) {
        GameText(name.take(1).uppercase(), AppText.logo(s * 0.58f, fontScale), Color.White, Modifier.offset(y = (s * 0.02f).dp))
    }
}

@Composable
fun Crowns(count: Int, @Suppress("UNUSED_PARAMETER") color: Color = Theme.gold, size: Float = 16f, empty: Color = Theme.ink.copy(alpha = 0.18f)) {
    // `color` is kept for parity with the iOS signature; the crown draws its own brass.
    Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
        repeat(MatchState.roundsToWin) { i ->
            CrownIcon(filled = i < count, size = size + 4f, empty = empty)
        }
    }
}

/** Ola, the host: a brass disc with her initial. */
@Composable
fun OlaBadge(size: Float = 28f) {
    val s = UI.s(size)
    val fontScale = LocalDensity.current.fontScale
    Box(
        Modifier.size(s.dp).drawBehind {
            val r = this.size.minDimension / 2f
            drawCircle(Theme.goldDeep, r, center + Offset(0f, this.size.height * 0.07f))
            drawCircle(Theme.gold, r)
            drawCircle(Theme.goldDeep, r - this.size.height * 0.12f, style = Stroke(max(1.dp.toPx(), this.size.height * 0.06f)))
        },
        contentAlignment = Alignment.Center,
    ) {
        GameText("O", AppText.logo(s * 0.56f, fontScale), Theme.ink, Modifier.offset(y = (s * 0.02f).dp))
    }
}

/** Speech bubble from Ola, with a tail. */
@Composable
fun OlaSays(text: String, modifier: Modifier = Modifier) {
    Row(modifier, horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.Top) {
        OlaBadge(size = 30f)
        Box {
            GameText(
                text, AppText.body(15f), Theme.ink,
                Modifier.background(Theme.cream, RoundedCornerShape(16.dp)).padding(horizontal = 14.dp, vertical = 11.dp),
            )
            Box(Modifier.align(Alignment.TopStart).offset(x = (-9).dp, y = 10.dp).size(12.dp, 10.dp).rotate(-90f)) {
                Triangle(Theme.cream, Modifier.fillMaxSize())
            }
        }
    }
}

// MARK: - Mascots

enum class Mood { Idle, Happy, Sad, Think }

/**
 * Every deck has a little character: a soft body in the deck's colour, big eyes, feet, and the
 * deck's icon pinned like a badge. Moods change the eyes and mouth. Idles with a slow breath,
 * blinks, glances around.
 */
@Composable
fun Mascot(deck: Deck, mood: Mood = Mood.Idle, size: Float = 120f, modifier: Modifier = Modifier) {
    val s = UI.s(size)
    val body = deck.color
    val dark = body.mix(Color.Black, 0.3f)
    val light = body.mix(Color.White, 0.28f)
    val reduceMotion = LocalReduceMotion.current

    // Breath runs 0 (at rest) to 1 (drawn in); SwiftUI toggles a Bool and lets the animation interpolate.
    val breathe: State<Float> = if (reduceMotion) {
        remember { mutableFloatStateOf(0f) }
    } else {
        rememberInfiniteTransition(label = "breathe").animateFloat(
            initialValue = 0f, targetValue = 1f,
            animationSpec = infiniteRepeatable(tween(if (mood == Mood.Happy) 300 else 1600, easing = EaseInOut), RepeatMode.Reverse),
            label = "breathe",
        )
    }
    var blink by remember { mutableStateOf(false) }
    var glanceTarget by remember { mutableFloatStateOf(0f) }
    val eyeOpen = animateFloatAsState(
        targetValue = if (blink) 0.1f else if (mood == Mood.Happy) 0.45f else 1f,
        animationSpec = tween(70, easing = EaseInOut), label = "blink",
    )
    val glance = animateFloatAsState(glanceTarget, smoothSpring(0.4f), label = "glance")
    // The timers live and die with the composable, which is what `alive` guarded on iOS.
    if (!reduceMotion) {
        LaunchedEffect(Unit) {
            while (true) {
                delay(Random.nextInt(2, 6) * 1000L)
                blink = true
                delay(100)
                blink = false
            }
        }
        LaunchedEffect(Unit) {
            while (true) {
                delay(Random.nextLong(1500, 3801))
                glanceTarget = listOf(-1f, 0f, 1f, 0f).random()
            }
        }
    }

    Box(modifier.size(s.dp, (s * 1.15f).dp), contentAlignment = Alignment.Center) {
        // Ground shadow and feet.
        Canvas(Modifier.fillMaxSize()) {
            val sp = s.dp.toPx()
            val cx = this.size.width / 2f
            val cy = this.size.height / 2f
            drawOval(Color.Black.copy(alpha = 0.16f), Offset(cx - sp * 0.31f, cy + sp * 0.56f - sp * 0.055f), Size(sp * 0.62f, sp * 0.11f))
            val footW = sp * 0.2f
            val footH = sp * 0.1f
            val gap = sp * 0.14f
            val footY = cy + sp * 0.47f - footH / 2f
            drawRoundRect(dark, Offset(cx - gap / 2f - footW, footY), Size(footW, footH), CornerRadius(footH / 2f))
            drawRoundRect(dark, Offset(cx + gap / 2f, footY), Size(footW, footH), CornerRadius(footH / 2f))
        }
        // Body
        Box(
            Modifier.size((s * 0.82f).dp, (s * 0.86f).dp).graphicsLayer {
                val b = breathe.value
                scaleX = 1f + 0.02f * b
                scaleY = 1f - 0.02f * b
                transformOrigin = TransformOrigin(0.5f, 1f)
                rotationZ = if (mood == Mood.Sad) -3f else 0f
                translationY = if (mood == Mood.Happy) -s * 0.06f * b * density else 0f
            },
        ) {
            Canvas(Modifier.fillMaxSize()) {
                val radius = CornerRadius(s.dp.toPx() * 0.36f)
                drawRoundRect(Brush.verticalGradient(listOf(light, body, dark)), cornerRadius = radius)
                // Top rim: a white stroke inside the edge, masked out by the middle of the body.
                val rim = max(1.5.dp.toPx(), s.dp.toPx() * 0.02f)
                drawRoundRect(
                    Brush.verticalGradient(0f to Color.White.copy(alpha = 0.35f), 0.5f to Color.White.copy(alpha = 0f)),
                    topLeft = Offset(rim / 2f, rim / 2f),
                    size = Size(this.size.width - rim, this.size.height - rim),
                    cornerRadius = radius,
                    style = Stroke(rim),
                )
            }
            MascotFace(s, mood, eyeOpen, glance, Modifier.align(Alignment.Center).offset(y = (-s * 0.06f).dp))
            // Icon badge, pinned bottom-right
            Box(
                Modifier
                    .align(Alignment.Center)
                    .offset((s * 0.28f).dp, (s * 0.28f).dp)
                    .size((s * 0.28f).dp)
                    .drawWithContent {
                        drawContent()
                        drawCircle(dark.copy(alpha = 0.2f), style = Stroke(1.dp.toPx()))
                    }
                    .drawBehind { drawCircle(Color.White) },
            ) {
                DeckIcon(deck.id, fill = Color.White, ink = dark, modifier = Modifier.fillMaxSize().padding((s * 0.035f).dp))
            }
        }
    }
}

@Composable
private fun MascotFace(s: Float, mood: Mood, eyeOpen: State<Float>, glance: State<Float>, modifier: Modifier) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy((s * 0.04f).dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy((s * 0.1f).dp)) {
            MascotEye(s, mood, eyeOpen, glance)
            MascotEye(s, mood, eyeOpen, glance)
        }
        MascotMouth(s, mood)
    }
}

@Composable
private fun MascotEye(s: Float, mood: Mood, eyeOpen: State<Float>, glance: State<Float>) {
    Box(Modifier.size((s * 0.2f).dp)) {
        Canvas(Modifier.fillMaxSize().graphicsLayer { scaleY = eyeOpen.value }) {
            val sp = s.dp.toPx()
            val g = glance.value
            drawCircle(Color.White)
            drawCircle(
                Theme.ink, radius = sp * 0.095f / 2f,
                center = center + Offset(g * sp * 0.03f + (if (mood == Mood.Think) sp * 0.03f else 0f), if (mood == Mood.Think) -sp * 0.025f else sp * 0.01f),
            )
            drawCircle(Color.White, radius = sp * 0.035f / 2f, center = center + Offset(-sp * 0.02f + g * sp * 0.03f, -sp * 0.025f))
        }
        if (mood == Mood.Sad) {
            // A brow, laid over the eye and unaffected by the blink.
            Box(
                Modifier
                    .align(Alignment.TopCenter)
                    .offset(y = (-s * 0.04f).dp)
                    .size((s * 0.16f).dp, (s * 0.03f).dp)
                    .rotate(12f)
                    .background(Theme.ink.copy(alpha = 0.85f), CircleShape),
            )
        }
    }
}

@Composable
private fun MascotMouth(s: Float, mood: Mood) {
    val ink = Theme.ink.copy(alpha = 0.85f)
    when (mood) {
        Mood.Happy -> Canvas(Modifier.size((s * 0.22f).dp, (s * 0.12f).dp)) {
            val sp = s.dp.toPx()
            val r = sp * 0.11f
            val c = Offset(sp * 0.11f, 0f)
            val p = Path().apply {
                arcTo(Rect(c.x - r, c.y - r, c.x + r, c.y + r), 10f, 160f, forceMoveTo = true)
                close()
            }
            drawPath(p, ink)
        }
        Mood.Sad -> Canvas(Modifier.size((s * 0.16f).dp, (s * 0.1f).dp)) {
            val sp = s.dp.toPx()
            val r = sp * 0.08f
            val c = Offset(sp * 0.08f, sp * 0.09f)
            val p = Path().apply { arcTo(Rect(c.x - r, c.y - r, c.x + r, c.y + r), 200f, 140f, forceMoveTo = true) }
            drawPath(p, ink, style = Stroke(max(2.dp.toPx(), sp * 0.03f), cap = StrokeCap.Round))
        }
        Mood.Think -> Box(
            Modifier
                .offset(x = (s * 0.04f).dp)
                .size((s * 0.09f).dp, max(2f, s * 0.03f).dp)
                .background(ink, CircleShape),
        )
        Mood.Idle -> Canvas(Modifier.size((s * 0.16f).dp, (s * 0.08f).dp)) {
            val sp = s.dp.toPx()
            val r = sp * 0.08f
            val c = Offset(sp * 0.08f, 0f)
            val p = Path().apply { arcTo(Rect(c.x - r, c.y - r, c.x + r, c.y + r), 20f, 140f, forceMoveTo = true) }
            drawPath(p, ink, style = Stroke(max(2.dp.toPx(), sp * 0.03f), cap = StrokeCap.Round))
        }
    }
}

/** Deck tile: colour block with the mascot and the name. */
@Composable
fun DeckTile(deck: Deck, compact: Boolean = false, modifier: Modifier = Modifier) {
    val color = deck.color
    val edge = color.mix(Color.Black, 0.3f)
    val face = color.mix(Color.White, 0.1f)
    Box(
        modifier.fillMaxWidth().height(if (compact) 100.dp else 156.dp).drawBehind {
            val r = CornerRadius(22.dp.toPx())
            drawRoundRect(edge, topLeft = Offset(0f, 5.dp.toPx()), cornerRadius = r)
            drawRoundRect(Brush.verticalGradient(listOf(face, color)), cornerRadius = r)
        },
    ) {
        Mascot(
            deck, size = if (compact) 56f else 84f,
            modifier = Modifier.align(Alignment.TopEnd).padding(end = 10.dp, top = if (compact) 4.dp else 8.dp),
        )
        Column(Modifier.align(Alignment.BottomStart).padding(14.dp), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            StickerText(deck.title.uppercase(), size = if (compact) 18f else 22f, align = TextAlign.Start)
            if (!compact) {
                GameText(deck.tagline, AppText.bodyRegular(11f), Color.White.copy(alpha = 0.85f), maxLines = 2)
            }
        }
    }
}

// MARK: - Timer ring and confetti

@Composable
fun TimerRing(startMs: Long, durationSeconds: Double, size: Float = 56f, color: Color = Theme.gold) {
    val s = UI.s(size)
    val fontScale = LocalDensity.current.fontScale
    val durationMs = durationSeconds * 1000.0
    // Read from the wall clock every frame, the way `TimelineView` reads `ctx.date` on iOS. Not an
    // animation: Compose scales animations by the system animator duration, and "Remove animations"
    // sets that to zero, which emptied the ring and showed 0 for the whole question. The frame wait
    // is the infinite-animation one because this loop never ends on its own; the Compose test
    // harness treats those as idle, where a plain withFrameNanos loop blocks every waitForIdle().
    // The controller's own clock is what ends the question; this ring only shows it.
    val progress = remember(startMs) { mutableFloatStateOf(0f) }
    LaunchedEffect(startMs) {
        while (progress.floatValue < 1f) {
            withInfiniteAnimationFrameNanos {
                progress.floatValue = ((System.currentTimeMillis() - startMs) / durationMs).toFloat().coerceIn(0f, 1f)
            }
        }
    }
    // Only the count recomposes, once a second; the ring reads the progress in the draw phase.
    val left by remember(startMs, durationSeconds) {
        derivedStateOf { max(0, ceil(durationSeconds * (1.0 - progress.floatValue)).toInt()) }
    }
    Box(
        Modifier.size(s.dp).drawBehind {
            val d = this.size.width
            val r = d / 2f
            drawCircle(Theme.panelEdge, r, center + Offset(0f, 3.dp.toPx()))
            drawCircle(Color.White, r)
            val width = d * 0.1f
            val inset = d * 0.08f
            drawCircle(Theme.panelEdge, r - inset, style = Stroke(width))
            val fraction = (1f - progress.floatValue).coerceIn(0f, 1f)
            if (fraction > 0f) {
                drawArc(
                    color = if (fraction < 0.25f) Theme.bad else color,
                    startAngle = -90f, sweepAngle = 360f * fraction, useCenter = false,
                    topLeft = Offset(inset, inset), size = Size(d - 2f * inset, d - 2f * inset),
                    style = Stroke(width, cap = StrokeCap.Round),
                )
            }
        },
        contentAlignment = Alignment.Center,
    ) {
        GameText("$left", AppText.artScore(s * 0.4f, fontScale), Theme.ink)
    }
}

/** Overlay for a Box: fills it, ignores touches, draws nothing under Reduce Motion. */
@Composable
fun ConfettiBurst(modifier: Modifier = Modifier) {
    if (LocalReduceMotion.current) return
    val particles = remember {
        List(80) {
            ConfettiParticle(
                angle = Random.nextDouble(0.0, 2.0 * PI).toFloat(),
                speed = Random.nextDouble(180.0, 420.0).toFloat(),
                size = Random.nextDouble(6.0, 12.0).toFloat(),
                hue = Random.nextFloat(),
                spin = Random.nextDouble(-6.0, 6.0).toFloat(),
                delay = Random.nextDouble(0.0, 0.15).toFloat(),
            )
        }
    }
    val t = remember { mutableFloatStateOf(0f) }
    LaunchedEffect(Unit) {
        val start = withFrameNanos { it }
        while (t.floatValue < 1.8f + 0.15f) {
            withFrameNanos { now -> t.floatValue = (now - start) / 1_000_000_000f }
        }
    }
    Canvas(modifier.fillMaxSize()) {
        val d = density
        val now = t.floatValue
        // The motion is authored in points; scale the whole burst so a phone and a tablet match.
        scale(d, d, pivot = Offset.Zero) {
            val origin = Offset(this.size.width / d / 2f, this.size.height / d * 0.4f)
            for (p in particles) {
                val life = now - p.delay
                if (life <= 0f || life >= 1.8f) continue
                val x = origin.x + cos(p.angle) * p.speed * life * 0.7f
                val y = origin.y + sin(p.angle) * p.speed * life * 0.5f + 260f * life * life
                val alpha = max(0f, 1f - life / 1.8f)
                rotate(degrees = p.spin * life * 180f / PI.toFloat(), pivot = Offset(x, y)) {
                    drawRoundRect(
                        Color.hsv(p.hue * 360f, 0.85f, 1f, alpha),
                        topLeft = Offset(x - p.size / 2f, y - p.size / 2f),
                        size = Size(p.size, p.size * 0.6f),
                        cornerRadius = CornerRadius(2f),
                    )
                }
            }
        }
    }
}

private class ConfettiParticle(val angle: Float, val speed: Float, val size: Float, val hue: Float, val spin: Float, val delay: Float)

/** Shake modifier for wrong answers: [amount] dp of horizontal wobble over [shakes] cycles as [progress] runs 0 to 1. */
fun Modifier.shake(progress: Float, amount: Float = 10f, shakes: Float = 4f): Modifier =
    offset { IntOffset((amount * sin(progress * PI.toFloat() * shakes)).dp.roundToPx(), 0) }

// MARK: - Wordmark

/** The logo: two stacked world chips with a VS badge on the seam. */
@Composable
fun Wordmark(scale: Float = 1f) {
    // Geometry and lettering share this, so the chips grow with the words inside them.
    val k = scale * UI.scale
    val fontScale = LocalDensity.current.fontScale
    Box(contentAlignment = Alignment.Center) {
        Column(verticalArrangement = Arrangement.spacedBy((8f * k).dp)) {
            WordmarkChip("HIS WORLD", Theme.his, k, fontScale)
            WordmarkChip("HER WORLD", Theme.hers, k, fontScale)
        }
        Box(
            Modifier.size((48f * k).dp).rotate(-8f).drawBehind {
                val r = this.size.minDimension / 2f
                drawCircle(Theme.goldDeep, r, center + Offset(0f, (3f * k).dp.toPx()))
                drawCircle(Theme.gold, r)
                drawCircle(Theme.ink, r, style = Stroke((3f * k).dp.toPx()))
            },
            contentAlignment = Alignment.Center,
        ) {
            GameText("VS", AppText.logo(18f * k, fontScale), Theme.ink)
        }
    }
}

@Composable
private fun WordmarkChip(text: String, color: Color, k: Float, fontScale: Float) {
    val edge = color.mix(Color.Black, 0.3f)
    Box(
        Modifier.size((270f * k).dp, (66f * k).dp).drawBehind {
            val r = CornerRadius((18f * k).dp.toPx())
            drawRoundRect(edge, topLeft = Offset(0f, (6f * k).dp.toPx()), cornerRadius = r)
            drawRoundRect(color, cornerRadius = r)
            drawRoundRect(Brush.verticalGradient(0f to Color.White.copy(alpha = 0.18f), 0.5f to Color.White.copy(alpha = 0f)), cornerRadius = r)
            drawRoundRect(Theme.ink, cornerRadius = r, style = Stroke((3f * k).dp.toPx()))
        },
        contentAlignment = Alignment.Center,
    ) {
        GameText(text, AppText.logo(36f * k, fontScale), Color.White)
    }
}

// MARK: - Buttons, panels, fields (the view half of Theme.swift)

/** A chunky game button: solid face over a darker "edge" that compresses when pressed. */
@Composable
fun ChunkyButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    color: Color = Theme.gold,
    edge: Color? = null,
    ink: Color = Theme.ink,
    height: Float = 56f,
    fontSize: Float = TypeScale.button,
    enabled: Boolean = true,
    leading: (@Composable () -> Unit)? = null,
    trailing: (@Composable () -> Unit)? = null,
) {
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    val edgeColor = edge ?: color.mix(Color.Black, 0.3f)
    // The edge stays put while the face sinks onto it.
    val edgeOffset = animateFloatAsState(if (pressed) UI.s(2f) else UI.s(6f), smoothSpring(0.15f), label = "edge")
    val faceOffset = animateFloatAsState(if (pressed) 4f else 0f, smoothSpring(0.15f), label = "face")
    val gloss = Brush.verticalGradient(0f to Color.White.copy(alpha = 0.22f), 0.5f to Color.White.copy(alpha = 0f))
    Box(
        modifier
            .fillMaxWidth()
            .alpha(if (enabled) 1f else 0.45f)
            .offset { IntOffset(0, faceOffset.value.dp.roundToPx()) }
            .height(max(44f, UI.s(height)).dp)   // never below the 44dp minimum target
            .drawBehind {
                val r = CornerRadius(UI.s(16f).dp.toPx())
                drawRoundRect(edgeColor, topLeft = Offset(0f, edgeOffset.value.dp.toPx()), cornerRadius = r)
                drawRoundRect(color, cornerRadius = r)
                drawRoundRect(gloss, cornerRadius = r)
            }
            // A plain press, no ripple: Material's ripple reads as generic.
            .clickable(interactionSource = interaction, indication = null, enabled = enabled, role = Role.Button, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            leading?.invoke()
            GameText(text.uppercase(), AppText.headline(fontSize).copy(letterSpacing = 0.5.sp), ink, align = TextAlign.Center)
            trailing?.invoke()
        }
    }
}

/** The 44dp white-20% circle used for close, trash and more. */
@Composable
fun RoundIconButton(
    kind: GlyphKind,
    contentDescription: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    glyphSize: Float = 15f,
    weight: Float = 18f,
) {
    val interaction = remember { MutableInteractionSource() }
    Box(
        modifier
            .size(44.dp)
            .semantics { this.contentDescription = contentDescription }
            .clickable(interactionSource = interaction, indication = null, role = Role.Button, onClick = onClick)
            .background(Color.White.copy(alpha = 0.2f), CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Glyph(kind = kind, size = glyphSize, weight = weight)
    }
}

/** Cream chunky panel with a soft edge, the game's card. */
fun Modifier.panel(padding: Float = 16f, radius: Float = 22f): Modifier =
    drawBehind {
        val r = CornerRadius(UI.s(radius).dp.toPx())
        drawRoundRect(Theme.panelEdge, topLeft = Offset(0f, UI.s(5f).dp.toPx()), cornerRadius = r)
        drawRoundRect(Theme.panel, cornerRadius = r)
    }.padding(UI.s(padding).dp)

/**
 * Every text field: cream fill, a visible edge so it reads as somewhere to type, sized with the
 * canvas. The prompt is drawn in ink2 (about 6:1 on cream) because the platform placeholder is a
 * pale grey at low opacity that all but disappears on cream, which is how "First name" became
 * invisible on iOS. Still visibly lighter than typed text, so it reads as a hint.
 */
@Composable
fun GameTextField(
    value: String,
    onValueChange: (String) -> Unit,
    placeholder: String,
    modifier: Modifier = Modifier,
    textStyle: TextStyle = AppText.bodyBold(20f),
    height: Float = 54f,
    radius: Float = 14f,
    imeAction: ImeAction = ImeAction.Done,
    onDone: (() -> Unit)? = null,
    testTag: String? = null,
) {
    val shape = RoundedCornerShape(UI.s(radius).dp)
    val tagged = if (testTag != null) modifier.testTag(testTag) else modifier
    BasicTextField(
        value = value,
        onValueChange = onValueChange,
        modifier = tagged
            .fillMaxWidth()
            .height(UI.s(height).dp)
            .background(Theme.cream, shape)
            .border(1.5.dp, Theme.panelEdge, shape)
            // The prompt is the field's label, as a SwiftUI TextField's prompt is for VoiceOver.
            .semantics { contentDescription = placeholder },
        textStyle = textStyle.copy(color = Theme.ink),
        singleLine = true,
        cursorBrush = SolidColor(Theme.ink),
        keyboardOptions = KeyboardOptions(capitalization = KeyboardCapitalization.Words, autoCorrectEnabled = false, imeAction = imeAction),
        keyboardActions = KeyboardActions(onDone = { onDone?.invoke() }),
        decorationBox = { inner ->
            Box(Modifier.fillMaxSize().padding(horizontal = UI.s(14f).dp), contentAlignment = Alignment.CenterStart) {
                if (value.isEmpty()) GameText(placeholder, textStyle, Theme.ink2, Modifier.clearAndSetSemantics {}, maxLines = 1)
                inner()
            }
        },
    )
}

object Art {
    fun lighter(c: Color, amount: Float): Color = c.mix(Color.White, amount)
    fun darker(c: Color, amount: Float): Color = c.mix(Color.Black, amount)
}

/** An upward-pointing triangle filling its bounds: the wheel's pointer and Ola's speech tail. */
object TriangleShape : Shape {
    override fun createOutline(size: Size, layoutDirection: LayoutDirection, density: Density): Outline =
        Outline.Generic(trianglePath(size))
}

@Composable
fun Triangle(color: Color, modifier: Modifier) {
    Canvas(modifier) { drawPath(trianglePath(size), color) }
}

private fun trianglePath(size: Size): Path = Path().apply {
    moveTo(size.width / 2f, 0f)
    lineTo(size.width, size.height)
    lineTo(0f, size.height)
    close()
}
