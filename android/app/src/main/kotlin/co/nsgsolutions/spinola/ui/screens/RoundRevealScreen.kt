package co.nsgsolutions.spinola.ui.screens

import androidx.compose.animation.core.SpringSpec
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import co.nsgsolutions.spinola.audio.Haptics
import co.nsgsolutions.spinola.audio.Sound
import co.nsgsolutions.spinola.audio.SoundKit
import co.nsgsolutions.spinola.engine.MatchController
import co.nsgsolutions.spinola.engine.MatchEngine
import co.nsgsolutions.spinola.model.Decks
import co.nsgsolutions.spinola.model.MatchPlayer
import co.nsgsolutions.spinola.model.MatchState
import co.nsgsolutions.spinola.model.MatchStatus
import co.nsgsolutions.spinola.model.Round
import co.nsgsolutions.spinola.ui.hud.Avatar
import co.nsgsolutions.spinola.ui.hud.ChunkyButton
import co.nsgsolutions.spinola.ui.hud.ConfettiBurst
import co.nsgsolutions.spinola.ui.hud.CrownIcon
import co.nsgsolutions.spinola.ui.hud.DeckIcon
import co.nsgsolutions.spinola.ui.hud.GameBackground
import co.nsgsolutions.spinola.ui.hud.GameText
import co.nsgsolutions.spinola.ui.hud.Kicker
import co.nsgsolutions.spinola.ui.hud.Mascot
import co.nsgsolutions.spinola.ui.hud.Mood
import co.nsgsolutions.spinola.ui.hud.OlaSays
import co.nsgsolutions.spinola.ui.hud.SideAvatars
import co.nsgsolutions.spinola.ui.hud.Stage
import co.nsgsolutions.spinola.ui.hud.StickerText
import co.nsgsolutions.spinola.ui.hud.panel
import co.nsgsolutions.spinola.ui.hud.smoothSpring
import co.nsgsolutions.spinola.ui.theme.AppText
import co.nsgsolutions.spinola.ui.theme.Theme
import co.nsgsolutions.spinola.ui.theme.TypeScale
import co.nsgsolutions.spinola.ui.theme.UI
import co.nsgsolutions.spinola.ui.theme.color
import kotlinx.coroutines.delay
import kotlin.math.PI
import kotlin.math.pow
import co.nsgsolutions.spinola.ui.theme.grouped
import co.nsgsolutions.spinola.ui.hud.PinnedColumn

// Port of Views/RoundRevealView.swift.

/** Both scores for a finished round, and who takes the crown. */
@Composable
fun RoundRevealScreen(controller: MatchController, round: Int) {
    val snap by controller.snapshot.collectAsState()
    val s = snap.state
    val r = s.rounds[round - 1]
    val winner = s.roundWinner(r)
    val me = controller.viewer   // not `me`: after a submit the active side has already flipped
    val iWon = winner == me
    val winnerWorld = winner?.let { s.player(it)?.world }
    var shown by remember { mutableStateOf(false) }
    var crownPop by remember { mutableStateOf(false) }
    val scoreScale by animateFloatAsState(if (shown) 1f else 0.6f, smoothSpring(0.6f), label = "score-scale")
    val scoreAlpha by animateFloatAsState(if (shown) 1f else 0f, smoothSpring(0.6f), label = "score-alpha")
    val crownScale by animateFloatAsState(if (crownPop) 1f else 0.2f, popSpring(0.7f, 0.5f), label = "crown-scale")
    val crownTilt by animateFloatAsState(if (crownPop) 0f else -30f, popSpring(0.7f, 0.5f), label = "crown-tilt")

    Stage(background = {
        if (winnerWorld != null) GameBackground(winnerWorld) else GameBackground(top = Theme.violet, bottom = Theme.violetDeep)
    }) {
        PinnedColumn(
            spacing = 14.dp,
            modifier = Modifier.padding(20.dp),
            top = {
                MatchHeader(controller)
            },
            bottom = {
                ChunkyButton(
                    text = if (s.status == MatchStatus.finished) "See the final" else "Continue",
                    onClick = {
                        Haptics.tap()
                        controller.acknowledgeReveal()
                    },
                    modifier = Modifier.testTag("reveal-continue"),
                    color = Theme.gold,
                )
            },
        ) {
            Kicker("ROUND $round · ${MatchEngine.roundLabel(round)}")
            if (winner != null) {
                CrownIcon(
                    size = 84f,
                    modifier = Modifier.graphicsLayer {
                        scaleX = crownScale
                        scaleY = crownScale
                        rotationZ = crownTilt
                    },
                )
            }
            StickerText(headline(s, winner, me), size = TypeScale.title, modifier = Modifier.tuckUp(UI.s(6f).dp))
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp), verticalAlignment = Alignment.CenterVertically) {
                for (p in s.players) {
                    SidePanel(p, r, winner, scoreScale, scoreAlpha, Modifier.weight(1f))
                }
            }
            OlaSays(text = olaLine(iWon = iWon, tie = winner == null))
        }
        if (iWon) ConfettiBurst()
    }
    LaunchedEffect(Unit) {
        shown = true
        if (winner == null) SoundKit.play(Sound.Swoosh) else SoundKit.play(if (iWon) Sound.Crown else Sound.Lose)
        delay(100)
        crownPop = true
    }
}

/** One side's card: a couple's per-member rows, or the solo player's mascot and score. */
@Composable
private fun SidePanel(p: MatchPlayer, r: Round, winner: String?, scoreScale: Float, scoreAlpha: Float, modifier: Modifier) {
    val won = winner == p.id
    val scorePop = Modifier.graphicsLayer {
        scaleX = scoreScale
        scaleY = scoreScale
        alpha = scoreAlpha
    }
    Column(
        modifier.winnerRing(won).panel(padding = 12f),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        if (p.isTeam) {
            SideAvatars(player = p, size = 30f)
            val name = AppText.label(11f)
            GameText(
                p.name.uppercase(), name, Theme.ink, maxLines = 1,
                autoSize = TextAutoSize.StepBased(minFontSize = name.fontSize * 0.6f, maxFontSize = name.fontSize, stepSize = 0.5f.sp),
            )
            GameText(r.score(p).grouped(), AppText.score(40f), Theme.ink, scorePop)
            for (m in p.members) {
                val res = r.results[m.id]
                val deck = r.picks[m.id]?.let(Decks::byID)
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(5.dp), verticalAlignment = Alignment.CenterVertically) {
                    if (deck != null) DeckIcon(deck.id, fill = Color.White, ink = deck.color, modifier = Modifier.size(UI.s(14f).dp))
                    // The name takes the slack (Swift's `Spacer(minLength: 2)`), so the score keeps the trailing edge.
                    GameText(
                        m.name, AppText.bodyBold(11f), Theme.ink, Modifier.weight(1f).padding(end = 2.dp),
                        maxLines = 1, overflow = TextOverflow.Ellipsis,
                    )
                    GameText(res?.score?.toString() ?: "—", AppText.score(14f), Theme.ink2)
                }
            }
        } else {
            val member = p.members[0]
            val res = r.results[member.id]
            val deck = r.picks[member.id]?.let(Decks::byID)
            if (deck != null) {
                Mascot(deck, mood = if (won) Mood.Happy else if (winner == null) Mood.Idle else Mood.Sad, size = 64f)
            }
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                Avatar(name = p.name, world = p.world, size = 24f)
                GameText(p.name.uppercase(), AppText.label(12f), Theme.ink, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
            GameText((res?.score ?: 0).grouped(), AppText.score(44f), Theme.ink, scorePop)
            if (deck != null && res != null) {
                GameText(
                    "${res.correct}/${res.questionIDs.size} · ${deck.title}", AppText.bodyRegular(11f), Theme.ink2,
                    align = TextAlign.Center, maxLines = 2,
                )
            }
        }
    }
}

private fun headline(state: MatchState, winner: String?, me: String): String {
    if (winner == null) return "DEAD HEAT"
    return if (winner == me) "YOU TAKE IT" else "${state.player(winner)?.name?.uppercase() ?: "THEY"} TAKES IT"
}

private fun olaLine(iWon: Boolean, tie: Boolean): String {
    if (tie) return "Same score. Nobody gets the crown. Awkward."
    return if (iWon) "First to three crowns wins the match. Keep it up." else "They picked well. Pick better."
}

/**
 * The gold ring iOS overlays on the winning panel. Stroked on the panel's own edge, so half of it
 * sits outside the card exactly as SwiftUI's `.stroke` does; nothing here clips, so it shows.
 */
private fun Modifier.winnerRing(on: Boolean): Modifier =
    if (!on) this else drawWithContent {
        drawContent()
        drawRoundRect(Theme.gold, cornerRadius = CornerRadius(UI.s(22f).dp.toPx()), style = Stroke(4.dp.toPx()))
    }

/**
 * SwiftUI's negative top padding (`.padding(.top, UI.s(-6))`): the content is laid out [by]
 * shorter and drawn that much higher, so it tucks under whatever sits above it.
 */
private fun Modifier.tuckUp(by: Dp): Modifier = layout { measurable, constraints ->
    val placeable = measurable.measure(constraints)
    val pull = by.roundToPx()
    layout(placeable.width, (placeable.height - pull).coerceAtLeast(0)) { placeable.placeRelative(0, -pull) }
}

/** SwiftUI's `.spring(duration:bounce:)`: bounce is 1 − damping ratio, duration sets stiffness as in [smoothSpring]. */
private fun <T> popSpring(seconds: Float, bounce: Float): SpringSpec<T> =
    spring(dampingRatio = 1f - bounce, stiffness = (2f * PI.toFloat() / seconds).pow(2))
