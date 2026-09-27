package co.nsgsolutions.spinola.ui.hud

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import co.nsgsolutions.spinola.audio.Haptics
import co.nsgsolutions.spinola.audio.Sound
import co.nsgsolutions.spinola.audio.SoundKit
import co.nsgsolutions.spinola.model.Deck
import co.nsgsolutions.spinola.ui.theme.AppText
import co.nsgsolutions.spinola.ui.theme.LocalReduceMotion
import co.nsgsolutions.spinola.ui.theme.Theme
import co.nsgsolutions.spinola.ui.theme.TypeScale
import co.nsgsolutions.spinola.ui.theme.UI
import co.nsgsolutions.spinola.ui.theme.color
import co.nsgsolutions.spinola.ui.theme.mix
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.pow
import kotlin.math.sin
import kotlin.random.Random
import androidx.compose.ui.semantics.Role

// Port of Views/Wheel.swift.

/** The pick wheel. Spin it and fate suggests a deck; tap a slice to overrule fate. */
@Composable
fun WheelView(decks: List<Deck>, onPick: (Deck) -> Unit, enabled: Boolean = true) {
    val k = UI.scale   // the wheel grows with the canvas
    val reduceMotion = LocalReduceMotion.current
    val scope = rememberCoroutineScope()
    val rotation = remember { Animatable(0f) }
    var spinning by remember { mutableStateOf(false) }
    var landed by remember { mutableStateOf<Deck?>(null) }
    val ticks = remember { JobHolder() }
    val sliceAngle = 360f / max(1, decks.size)

    fun spin() {
        if (spinning || decks.isEmpty()) return
        spinning = true
        landed = null
        Haptics.heavy()
        val target = Random.nextInt(decks.size)
        // Land the target slice under the pointer at the top: slice i is centred at i*slice degrees clockwise from the top,
        // so rotating the wheel by -(i*slice) brings it up. Add whole turns for drama and a little wobble.
        // Reduce Motion turns the spin into a decision, not a ride: the wheel steps straight to the
        // slice it picked. This is the largest movement in the app, so honouring the setting matters.
        val turns = if (reduceMotion) 0f else Random.nextInt(4, 7).toFloat()
        val wobble = if (reduceMotion) 0f else Random.nextDouble(-sliceAngle * 0.3, sliceAngle * 0.3).toFloat()
        val final = turns * 360f - target * sliceAngle + wobble
        val base = rotation.value % 360f
        val duration = if (reduceMotion) 0.3 else 3.4
        // Ticks that slow down with the wheel.
        ticks.job?.cancel()
        ticks.job = scope.launch {
            var t = 0.0
            while (t < duration - 0.3) {
                val progress = t / duration
                val interval = 0.045 + 0.35 * progress.pow(2.2)
                delay((interval * 1000).toLong())
                Haptics.tick()
                SoundKit.play(Sound.Tick, 0.35f)
                t += interval
            }
        }
        scope.launch {
            rotation.animateTo(
                rotation.value - base + final,
                tween((duration * 1000).toInt(), easing = CubicBezierEasing(0.12f, 0.85f, 0.2f, 1f)),
            )
            delay(50)
            spinning = false
            SoundKit.play(Sound.Correct, 0.6f)
            Haptics.success()
            landed = decks[target]
        }
    }

    Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(14.dp)) {
        // Authored in a 320-point box and scaled as one piece, so the slices, pointer and hub keep their proportions.
        Box(Modifier.size(320.dp * k), contentAlignment = Alignment.Center) {
            Box(Modifier.size(320.dp).graphicsLayer { scaleX = k; scaleY = k }) {
                // Slices are disabled (for taps and for screen readers) while the wheel turns or a
                // submit is in flight, as the iOS guard `enabled, !spinning` intends.
                Wheel(decks, sliceAngle, rotation = { rotation.value }, tappable = enabled && !spinning) { deck ->
                    Haptics.heavy()
                    onPick(deck)
                }
                // Pointer
                Box(Modifier.align(Alignment.TopCenter).offset(y = (-8).dp).size(34.dp, 30.dp).rotate(180f)) {
                    Triangle(Theme.panelEdge, Modifier.fillMaxSize().offset(y = 3.dp))
                    Triangle(Color.White, Modifier.fillMaxSize())
                }
                // Hub
                Box(
                    Modifier.align(Alignment.Center).size(74.dp).drawBehind {
                        val r = size.minDimension / 2f
                        drawCircle(Theme.ink.copy(alpha = 0.35f), r, center + Offset(0f, 4.dp.toPx()))
                        drawCircle(Color.White, r)
                    },
                    contentAlignment = Alignment.Center,
                ) {
                    Glyph(kind = GlyphKind.Star, size = 30f / UI.scale, color = Theme.violet)   // the whole wheel is already scaled by k
                }
            }
        }

        AnimatedContent(
            targetState = landed,
            contentKey = { it?.id },
            transitionSpec = {
                (fadeIn(smoothSpring(0.4f)) + slideInVertically(smoothSpring(0.4f)) { it })
                    .togetherWith(fadeOut(smoothSpring(0.4f)) + slideOutVertically(smoothSpring(0.4f)) { it })
            },
            label = "landed",
        ) { deck ->
            if (deck != null) {
                LandedPanel(
                    deck = deck,
                    enabled = enabled,
                    onSpinAgain = { spin() },
                    onLockIn = {
                        if (!enabled || spinning) return@LandedPanel
                        Haptics.heavy()
                        onPick(deck)
                    },
                )
            } else {
                // Spinning is guarded inside rather than by `enabled`, so the button keeps its
                // colour during the ride the way the iOS one does.
                ChunkyButton(
                    text = "Spin the wheel",
                    onClick = { spin() },
                    modifier = Modifier.testTag("spin"),
                    color = Theme.gold,
                    enabled = enabled,
                    leading = { Glyph(kind = GlyphKind.Spin, size = 22f, color = Theme.ink, weight = 14f) },
                )
            }
        }
    }
}

/** The wheel proper: disc, slices, rim and the tappable icon on each slice, all turning together. */
@Composable
private fun Wheel(decks: List<Deck>, sliceAngle: Float, rotation: () -> Float, tappable: Boolean, onTap: (Deck) -> Unit) {
    val sliceColors = remember(decks) { decks.map { it.color.mix(Theme.ink, 0.14f) } }
    Box(Modifier.fillMaxSize().graphicsLayer { rotationZ = rotation() }) {
        Canvas(Modifier.fillMaxSize()) {
            val r = size.minDimension / 2f
            drawCircle(Theme.ink.copy(alpha = 0.35f), r, center + Offset(0f, 8.dp.toPx()))
            drawCircle(Color.White, r)
            val pad = 8.dp.toPx()
            val oval = Rect(Offset(pad, pad), Size(size.width - 2f * pad, size.height - 2f * pad))
            decks.forEachIndexed { i, _ ->
                val start = i * sliceAngle - 90f - sliceAngle / 2f
                val slice = Path().apply {
                    moveTo(center.x, center.y)
                    arcTo(oval, start, sliceAngle, forceMoveTo = false)
                    close()
                }
                drawPath(slice, sliceColors[i])
                drawPath(slice, Color.White, style = Stroke(4.dp.toPx()))
            }
            drawCircle(Color.White, r - 4.dp.toPx(), style = Stroke(8.dp.toPx()))
        }
        decks.forEachIndexed { i, deck ->
            SliceButton(deck, i, sliceAngle, rotation, tappable) { onTap(deck) }
        }
    }
}

/** Icon at the slice's mid-radius, tappable to choose outright. */
@Composable
private fun BoxScope.SliceButton(deck: Deck, index: Int, sliceAngle: Float, rotation: () -> Float, tappable: Boolean, onTap: () -> Unit) {
    val mid = index * sliceAngle - 90f
    val r = 108f
    val dx = r * cos(mid * PI / 180.0).toFloat()
    val dy = r * sin(mid * PI / 180.0).toFloat()
    Box(
        Modifier
            .align(Alignment.Center)
            .offset { IntOffset(dx.dp.roundToPx(), dy.dp.roundToPx()) }
            .size(64.dp)
            // Counter-rotate the icon about its own centre so it stays upright.
            .graphicsLayer { rotationZ = -rotation() }
            .clip(CircleShape)
            .clickable(interactionSource = null, indication = null, enabled = tappable, role = Role.Button, onClick = onTap)
            .testTag("deck-${deck.id}")
            .semantics { contentDescription = deck.title },
        contentAlignment = Alignment.Center,
    ) {
        DeckIcon(deck.id, fill = Color.White, ink = Art.darker(deck.color, 0.45f), modifier = Modifier.size(40.dp))
    }
}

@Composable
private fun LandedPanel(deck: Deck, enabled: Boolean, onSpinAgain: () -> Unit, onLockIn: () -> Unit) {
    Column(Modifier.fillMaxWidth().panel(padding = 12f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
            Mascot(deck, mood = Mood.Happy, size = 54f)
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Kicker("THE WHEEL SAYS", color = Theme.ink2, size = 11f)
                GameText(
                    deck.title.uppercase(), AppText.headline(TypeScale.heading), Theme.ink, maxLines = 1,
                    autoSize = TextAutoSize.StepBased(
                        minFontSize = (UI.s(TypeScale.heading) * 0.7f).sp,
                        maxFontSize = UI.s(TypeScale.heading).sp,
                        stepSize = 0.5f.sp,
                    ),
                )
            }
            Spacer(Modifier.weight(1f))
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            ChunkyButton(
                text = "Spin again", onClick = onSpinAgain, modifier = Modifier.weight(1f),
                color = Color.White, edge = Theme.panelEdge, ink = Theme.ink, height = 52f, fontSize = 20f, enabled = enabled,
            )
            ChunkyButton(
                text = "Lock it in", onClick = onLockIn, modifier = Modifier.weight(1f).testTag("lock-in"),
                color = Theme.good, ink = Color.White, height = 52f, fontSize = 20f, enabled = enabled,
            )
        }
    }
}

/** The tick loop of the spin in flight, cancelled when the next spin starts (as `tickTask` on iOS). */
private class JobHolder {
    var job: Job? = null
}
