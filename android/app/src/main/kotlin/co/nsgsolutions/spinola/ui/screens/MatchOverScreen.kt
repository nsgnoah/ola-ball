package co.nsgsolutions.spinola.ui.screens

import androidx.compose.animation.core.SpringSpec
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import co.nsgsolutions.spinola.LocalMatchStore
import co.nsgsolutions.spinola.LocalProfileStore
import co.nsgsolutions.spinola.audio.Haptics
import co.nsgsolutions.spinola.audio.Sound
import co.nsgsolutions.spinola.audio.SoundKit
import co.nsgsolutions.spinola.engine.MatchController
import co.nsgsolutions.spinola.model.MatchMode
import co.nsgsolutions.spinola.ui.hud.ChunkyButton
import co.nsgsolutions.spinola.ui.hud.ConfettiBurst
import co.nsgsolutions.spinola.ui.hud.Crowns
import co.nsgsolutions.spinola.ui.hud.GameBackground
import co.nsgsolutions.spinola.ui.hud.GameText
import co.nsgsolutions.spinola.ui.hud.Kicker
import co.nsgsolutions.spinola.ui.hud.OlaSays
import co.nsgsolutions.spinola.ui.hud.SideAvatars
import co.nsgsolutions.spinola.ui.hud.Stage
import co.nsgsolutions.spinola.ui.hud.StickerText
import co.nsgsolutions.spinola.ui.hud.TrophyIcon
import co.nsgsolutions.spinola.ui.hud.panel
import co.nsgsolutions.spinola.ui.theme.AppText
import co.nsgsolutions.spinola.ui.theme.Theme
import co.nsgsolutions.spinola.ui.theme.TypeScale
import co.nsgsolutions.spinola.ui.theme.UI
import kotlinx.coroutines.delay
import kotlin.math.PI
import kotlin.math.pow
import co.nsgsolutions.spinola.ui.theme.grouped
import co.nsgsolutions.spinola.ui.hud.PinnedColumn

// Port of Views/MatchOverView.swift. iOS presents the rematch itself as a full-screen cover; here
// the new match id goes back to the app shell through [onRematch], which swaps the open match.

@Composable
fun MatchOverScreen(controller: MatchController, onClose: () -> Unit, onRematch: (String) -> Unit) {
    val localMatches = LocalMatchStore.current
    val profiles = LocalProfileStore.current
    val profile by profiles.profile.collectAsState()
    val snap by controller.snapshot.collectAsState()
    val s = snap.state
    val me = controller.me
    val winner = s.winnerID
    val iWon = winner == me
    val winnerWorld = winner?.let { s.player(it)?.world }
    var pop by remember { mutableStateOf(false) }
    val popScale by animateFloatAsState(if (pop) 1f else 0.2f, popSpring(0.7f, 0.5f), label = "trophy-scale")
    val popTilt by animateFloatAsState(if (pop) 0f else 20f, popSpring(0.7f, 0.5f), label = "trophy-tilt")

    Stage(background = {
        if (winnerWorld != null) GameBackground(winnerWorld) else GameBackground(top = Theme.violet, bottom = Theme.violetDeep)
    }) {
        PinnedColumn(
            spacing = 14.dp,
            modifier = Modifier.padding(20.dp),
            top = {
                MatchHeader(controller, onClose)
            },
            bottom = {
                val p = profile
                val partner = s.partner(s.players[0].id)
                if (controller.transport.isPassAndPlay && p != null && partner != null) {
                    ChunkyButton(
                        text = "Rematch",
                        onClick = {
                            Haptics.heavy()
                            val id = if (s.mode == MatchMode.teams) {
                                val a = s.players[0].members.map { it.name to it.answers }
                                val b = partner.members.map { it.name to it.answers }
                                localMatches.createTeams(ours = a, theirs = b)
                            } else {
                                localMatches.create(me = p, partnerName = partner.name, partnerWorld = partner.world)
                            }
                            onRematch(id)
                        },
                        modifier = Modifier.testTag("rematch"),
                        color = Theme.gold,
                    )
                }
                ChunkyButton(
                    text = "Back to matches",
                    onClick = onClose,
                    modifier = Modifier.testTag("back-to-matches"),
                    color = Color.White,
                    edge = Theme.panelEdge,
                    ink = Theme.ink,
                    height = 52f,
                    fontSize = 22f,
                )
            },
        ) {
            Kicker("FINAL")
            TrophyIcon(
                size = 96f,
                modifier = Modifier.graphicsLayer {
                    scaleX = popScale
                    scaleY = popScale
                    rotationZ = popTilt
                },
            )
            StickerText(
                when {
                    winner == null -> "IT'S A TIE"
                    iWon -> "YOU WIN"
                    else -> "${s.player(winner)?.name?.uppercase() ?: "THEY"} WINS"
                },
                size = TypeScale.display,
                modifier = Modifier.tuckUp(UI.s(8f).dp).testTag("match-over"),
            )
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                for (p in s.players) {
                    Column(
                        Modifier.weight(1f).winnerRing(winner == p.id).panel(padding = 14f),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        SideAvatars(player = p, size = 40f)
                        val name = AppText.label(13f)
                        GameText(
                            p.name.uppercase(), name, Theme.ink, maxLines = 1,
                            autoSize = TextAutoSize.StepBased(minFontSize = name.fontSize * 0.6f, maxFontSize = name.fontSize, stepSize = 0.5f.sp),
                        )
                        Crowns(count = s.crowns(p.id), size = 15f)
                        GameText(controller.total(p.id).grouped(), AppText.score(36f), Theme.ink)
                        Kicker("TOTAL POINTS", color = Theme.ink2, size = 10f)
                    }
                }
            }
            OlaSays(
                text = when {
                    winner == null -> "Identical. Suspicious. Run it back."
                    iWon -> "Bragging rights are yours until the rematch."
                    else -> "Rematch. Immediately. Don't let this stand."
                },
            )
        }
        if (iWon) ConfettiBurst()
    }
    LaunchedEffect(Unit) {
        SoundKit.play(if (iWon) Sound.Fanfare else if (winner == null) Sound.Swoosh else Sound.Lose)
        delay(100)
        pop = true
    }
}

/** The gold ring iOS overlays on the winning panel; see the twin in RoundRevealScreen.kt. */
private fun Modifier.winnerRing(on: Boolean): Modifier =
    if (!on) this else drawWithContent {
        drawContent()
        drawRoundRect(Theme.gold, cornerRadius = CornerRadius(UI.s(22f).dp.toPx()), style = Stroke(4.dp.toPx()))
    }

/** SwiftUI's negative top padding: laid out [by] shorter and drawn that much higher. */
private fun Modifier.tuckUp(by: Dp): Modifier = layout { measurable, constraints ->
    val placeable = measurable.measure(constraints)
    val pull = by.roundToPx()
    layout(placeable.width, (placeable.height - pull).coerceAtLeast(0)) { placeable.placeRelative(0, -pull) }
}

/** SwiftUI's `.spring(duration:bounce:)`: bounce is 1 − damping ratio, duration sets stiffness. */
private fun <T> popSpring(seconds: Float, bounce: Float): SpringSpec<T> =
    spring(dampingRatio = 1f - bounce, stiffness = (2f * PI.toFloat() / seconds).pow(2))
