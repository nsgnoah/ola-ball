package co.nsgsolutions.spinola.ui.screens

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.requiredHeightIn
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.geometry.toRect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import co.nsgsolutions.spinola.LocalProfileStore
import co.nsgsolutions.spinola.audio.Haptics
import co.nsgsolutions.spinola.audio.Sound
import co.nsgsolutions.spinola.audio.SoundKit
import co.nsgsolutions.spinola.model.Decks
import co.nsgsolutions.spinola.model.Profile
import co.nsgsolutions.spinola.model.World
import co.nsgsolutions.spinola.ui.hud.ChunkyButton
import co.nsgsolutions.spinola.ui.hud.GameBackground
import co.nsgsolutions.spinola.ui.hud.GameText
import co.nsgsolutions.spinola.ui.hud.GameTextField
import co.nsgsolutions.spinola.ui.hud.Glyph
import co.nsgsolutions.spinola.ui.hud.GlyphKind
import co.nsgsolutions.spinola.ui.hud.Kicker
import co.nsgsolutions.spinola.ui.hud.Mascot
import co.nsgsolutions.spinola.ui.hud.OlaSays
import co.nsgsolutions.spinola.ui.hud.Stage
import co.nsgsolutions.spinola.ui.hud.StageScroll
import co.nsgsolutions.spinola.ui.hud.StickerText
import co.nsgsolutions.spinola.ui.hud.panel
import co.nsgsolutions.spinola.ui.hud.sunburstPath
import co.nsgsolutions.spinola.ui.theme.AppText
import co.nsgsolutions.spinola.ui.theme.Theme
import co.nsgsolutions.spinola.ui.theme.TypeScale
import co.nsgsolutions.spinola.ui.theme.UI
import co.nsgsolutions.spinola.ui.theme.color
import co.nsgsolutions.spinola.ui.theme.mix
import kotlin.math.PI
import kotlin.math.pow
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.selected

// Port of Views/ProfileSetupView.swift.

/** First launch: your name and the world you know. */
@Composable
fun ProfileSetupScreen() {
    val profiles = LocalProfileStore.current
    var name by rememberSaveable { mutableStateOf("") }
    var world by rememberSaveable { mutableStateOf<World?>(null) }
    val canCommit = world != null && name.trim().isNotEmpty()

    fun commit() {
        val w = world ?: return
        if (!canCommit) return
        Haptics.success()
        SoundKit.play(Sound.Crown)
        profiles.set(Profile(name = name.trim(), world = w))
    }

    Stage(background = { GameBackground(top = Theme.violet, bottom = Theme.violetDeep) }) {
        StageScroll {
            Column(
                Modifier.fillMaxWidth().padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(18.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Column(
                    Modifier.padding(top = 10.dp),
                    verticalArrangement = Arrangement.spacedBy(2.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Kicker("SPINOLA · TRIVIA FOR TWO")
                    GameText("WHOSE WORLD", AppText.headline(TypeScale.heading), Color.White.copy(alpha = 0.85f))
                    // No negative nudge here: in a narrow column this headline wraps to two
                    // lines, and pulling a two-line block upward prints it through the line above.
                    StickerText("DO YOU KNOW?", size = TypeScale.display)
                }

                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    for (w in World.entries) {
                        WorldCard(
                            w,
                            selected = world == w,
                            onSelect = {
                                Haptics.tap()
                                world = w
                            },
                            modifier = Modifier.weight(1f),
                        )
                    }
                }

                OlaSays("Pick the side you could teach a class on. Your partner gets quizzed on it, you get quizzed on theirs.")

                Column(Modifier.fillMaxWidth().panel(padding = 14f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Kicker("YOUR NAME", color = Theme.ink2, size = 12f)
                    GameTextField(
                        value = name,
                        onValueChange = { name = it },
                        placeholder = "First name",
                        textStyle = AppText.bodyBold(20f),
                        onDone = { commit() },
                        testTag = "name-field",
                    )
                }

                ChunkyButton(
                    text = "Let's play",
                    onClick = { commit() },
                    modifier = Modifier.padding(top = 4.dp).testTag("profile-done"),
                    color = Theme.gold,
                    enabled = canCommit,
                    // The arrow follows the words, as on iOS.
                    trailing = { Glyph(GlyphKind.ArrowRight, size = 18f, color = Theme.ink, weight = 16f) },
                )
            }
        }
    }
}

/**
 * One world to choose: a colour block with three of its mascots, the world's name and a line of
 * what is in it. Grows a white ring and a check when selected.
 */
@Composable
private fun WorldCard(w: World, selected: Boolean, onSelect: () -> Unit, modifier: Modifier = Modifier) {
    val decks = remember(w) { Decks.decks(w) }
    val color = w.color
    val edge = color.mix(Color.Black, 0.3f)
    // `.spring(duration: 0.35, bounce: 0.4)` on iOS: bounce is one minus the damping ratio, and
    // for a unit mass the perceptual duration is 2π/√stiffness.
    val scale by animateFloatAsState(
        if (selected) 1.03f else 1f,
        spring(dampingRatio = 0.6f, stiffness = (2f * PI.toFloat() / 0.35f).pow(2)),
        label = "select",
    )
    val shape = RoundedCornerShape(22.dp)
    val interaction = remember { MutableInteractionSource() }
    Box(
        modifier
            .graphicsLayer {
                scaleX = scale
                scaleY = scale
            }
            .drawBehind {
                val r = CornerRadius(22.dp.toPx())
                drawRoundRect(edge, topLeft = Offset(0f, 7.dp.toPx()), cornerRadius = r)
                drawRoundRect(color, cornerRadius = r)
                clipPath(Path().apply { addRoundRect(RoundRect(size.toRect(), r)) }) {
                    drawPath(sunburstPath(size, rays = 12), Color.White, alpha = 0.10f)   // `Sunburst(rays: 12)` on iOS
                }
            }
            .then(if (selected) Modifier.border(4.dp, Color.White, shape) else Modifier)
            // A plain press, no ripple, as on the buttons.
            .clickable(interactionSource = interaction, indication = null, role = Role.Button, onClick = onSelect)
            // The ring and check say which world is picked; say it for screen readers too.
            .semantics { this.selected = selected }
            .testTag("world-${w.name}"),
    ) {
        Column(
            Modifier
                .fillMaxWidth()
                .heightIn(min = UI.s(230f).dp)   // grows with its contents; a fixed height spills on a tablet
                .padding(12.dp),
            horizontalAlignment = Alignment.Start,
        ) {
            Row(Modifier.padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy((-18).dp)) {
                for (d in decks.take(3)) Mascot(deck = d, size = 46f)
            }
            Spacer(Modifier.weight(1f).requiredHeightIn(min = 6.dp))
            StickerText(
                if (w == World.hers) "HER" else "HIS",
                size = 44f,
                align = TextAlign.Start,
                modifier = Modifier.trimBottom(UI.s(8f).dp),
            )
            GameText("WORLD", AppText.headline(22f), Color.White.copy(alpha = 0.9f))
            GameText(
                if (w == World.hers) {
                    "Beauty, fashion, rom-coms, reality TV, divas, weddings, books, wellness, gossip"
                } else {
                    "Football, ball sports, cars, grilling, games, gear, movies, tech, fights"
                },
                AppText.bodyRegular(11f),
                Color.White.copy(alpha = 0.85f),
                Modifier.padding(top = 4.dp),
            )
        }
        if (selected) {
            Box(
                Modifier
                    .align(Alignment.TopEnd)
                    .padding(10.dp)
                    .size(28.dp)
                    .drawBehind { drawCircle(Theme.good) }
                    .border(2.5.dp, Color.White, CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Glyph(GlyphKind.Check, size = 14f, weight = 20f)
            }
        }
    }
}

/**
 * SwiftUI's negative bottom padding: the element is laid out [amount] shorter than it measures,
 * so whatever follows sits that much closer. Compose's `padding` refuses negative values.
 */
private fun Modifier.trimBottom(amount: Dp): Modifier = layout { measurable, constraints ->
    val placeable = measurable.measure(constraints)
    val trim = amount.roundToPx()
    layout(placeable.width, (placeable.height - trim).coerceAtLeast(0)) { placeable.place(0, 0) }
}
