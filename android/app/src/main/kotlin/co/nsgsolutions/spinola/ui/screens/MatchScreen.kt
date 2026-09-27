package co.nsgsolutions.spinola.ui.screens

import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.EaseInOut
import androidx.compose.animation.core.EaseOut
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.State
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shadow
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.layout
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import co.nsgsolutions.spinola.LocalMatchStore
import co.nsgsolutions.spinola.audio.Haptics
import co.nsgsolutions.spinola.engine.MatchController
import co.nsgsolutions.spinola.engine.MatchEngine
import co.nsgsolutions.spinola.engine.Stage as MatchStage
import co.nsgsolutions.spinola.model.Deck
import co.nsgsolutions.spinola.model.Decks
import co.nsgsolutions.spinola.model.MatchMode
import co.nsgsolutions.spinola.model.MatchPlayer
import co.nsgsolutions.spinola.model.MatchState
import co.nsgsolutions.spinola.ui.hud.ChunkyButton
import co.nsgsolutions.spinola.ui.hud.CrownIcon
import co.nsgsolutions.spinola.ui.hud.Crowns
import co.nsgsolutions.spinola.ui.hud.DeckIcon
import co.nsgsolutions.spinola.ui.hud.GameBackground
import co.nsgsolutions.spinola.ui.hud.GameText
import co.nsgsolutions.spinola.ui.hud.GlyphKind
import co.nsgsolutions.spinola.ui.hud.HandoffIcon
import co.nsgsolutions.spinola.ui.hud.Kicker
import co.nsgsolutions.spinola.ui.hud.Mascot
import co.nsgsolutions.spinola.ui.hud.Mood
import co.nsgsolutions.spinola.ui.hud.OlaSays
import co.nsgsolutions.spinola.ui.hud.RoundIconButton
import co.nsgsolutions.spinola.ui.hud.SideAvatars
import co.nsgsolutions.spinola.ui.hud.Stage
import co.nsgsolutions.spinola.ui.hud.StickerText
import co.nsgsolutions.spinola.ui.hud.panel
import co.nsgsolutions.spinola.ui.theme.AppText
import co.nsgsolutions.spinola.ui.theme.LocalReduceMotion
import co.nsgsolutions.spinola.ui.theme.Theme
import co.nsgsolutions.spinola.ui.theme.TypeScale
import co.nsgsolutions.spinola.ui.theme.UI
import co.nsgsolutions.spinola.ui.theme.color
import co.nsgsolutions.spinola.ui.theme.grouped
import co.nsgsolutions.spinola.ui.theme.mix
import co.nsgsolutions.spinola.ui.hud.PinnedColumn

// Port of Views/MatchView.swift: the stage switch, the shared header, the hand-off, round-intro and
// waiting screens, and the scorecard. `Stage` the composable (ui/hud) and `Stage` the controller's
// state (engine) share a name, so the engine's is imported as `MatchStage` here.

/**
 * How a screen inside the match dismisses it, the way `@Environment(\.dismiss)` closes the
 * fullScreenCover on iOS. [MatchScreen] provides it; [MatchHeader] falls back to it when the screen
 * passes no `onClose` of its own.
 */
val LocalCloseMatch = staticCompositionLocalOf<() -> Unit> { {} }

/** One match. Renders whatever stage the controller says we're in. */
@Composable
fun MatchScreen(matchID: String, onClose: () -> Unit, onRematch: (String) -> Unit) {
    val store = LocalMatchStore.current
    // The controller lives in the activity's MatchHost, not in this composition, so a rotation or
    // any other activity recreation keeps the round in progress (see MatchHost). From here on the
    // controller is the single owner of the state; the store only receives its saves.
    val host = viewModel<MatchHost>()
    val controller = remember(matchID) { host.controller(matchID, store) }
    if (controller == null) {
        LaunchedEffect(matchID) { onClose() }
        return
    }
    // `start` decides the first stage. Until it has run the snapshot still says `Waiting`, and a
    // frame of that fading into the hand-off reads as a glitch, so the switch waits for it (iOS
    // runs `start` in `onAppear`, before the first frame is committed). After a recreation the
    // controller has long since started and keeps its stage.
    var started by remember(controller) { mutableStateOf(host.isStarted(matchID)) }
    LaunchedEffect(controller) {
        if (host.claimStart(matchID)) controller.start(announce = true)
        started = true
    }
    val snap by controller.snapshot.collectAsState()
    // Back closes the match, like the close button, except mid-question: iOS gives the question
    // screen no way out (no close button, and a full-screen cover cannot be swiped away), and here
    // the answers so far this round live only in the controller. A stray edge swipe must not
    // throw them away.
    BackHandler { if (snap.stage != MatchStage.Answering) onClose() }

    // No Stage here on purpose: every screen below brings its own full-bleed Stage. Nesting one
    // Stage inside another clips the inner background to the outer play column, which shows up
    // on a tablet as a seam down both sides of the screen.
    CompositionLocalProvider(LocalCloseMatch provides onClose) {
        AnimatedContent(
            targetState = if (started) snap.stage else null,
            modifier = Modifier.fillMaxSize(),
            transitionSpec = { fadeIn(tween(250, easing = EaseOut)) togetherWith fadeOut(tween(250, easing = EaseOut)) },
            label = "stage",
        ) { stage ->
            when (stage) {
                null -> Stage(background = { GameBackground(top = Theme.violet, bottom = Theme.violetDeep) }) {}
                MatchStage.SetupTeam -> JoinTeamScreen(controller, onClose)
                is MatchStage.Handoff -> HandoffScreen(stage.to) { controller.continueAfterHandoff() }
                is MatchStage.Intro -> RoundIntroScreen(controller, stage.round)
                MatchStage.Answering -> QuestionScreen(controller)
                is MatchStage.Picking -> DeckPickScreen(controller, stage.round, stage.target)
                is MatchStage.RoundReveal -> RoundRevealScreen(controller, stage.round)
                MatchStage.Waiting -> WaitingScreen(controller, onClose)
                MatchStage.Finished -> MatchOverScreen(controller, onClose, onRematch)
            }
        }
    }
}

// MARK: - Header

/** Top strip shared by in-match screens: close, both players with crowns. */
@Composable
fun MatchHeader(controller: MatchController, onClose: (() -> Unit)? = null) {
    val snap by controller.snapshot.collectAsState()
    val closeMatch = LocalCloseMatch.current
    val density = LocalDensity.current.density
    val me = controller.me
    val mine = snap.state.player(me)
    val them = snap.state.partner(me)
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
        RoundIconButton(
            kind = GlyphKind.Close,
            contentDescription = "Close match",
            onClick = { (onClose ?: closeMatch)() },
            modifier = Modifier.testTag("close-match"),
        )
        if (mine != null) Side(mine, crowns = snap.state.crowns(mine.id), leading = true)
        GameText(
            "VS",
            AppText.headline(18f).copy(shadow = Shadow(Theme.ink.copy(alpha = 0.6f), Offset(0f, 1f * density), 1f * density)),
            Theme.gold,
        )
        if (them != null) {
            Side(them, crowns = snap.state.crowns(them.id), leading = false)
        } else {
            GameText("Waiting for partner", AppText.body(12f), Color.White.copy(alpha = 0.7f))
        }
    }
}

@Composable
private fun RowScope.Side(p: MatchPlayer, crowns: Int, leading: Boolean) {
    Box(Modifier.weight(1f), contentAlignment = if (leading) Alignment.CenterStart else Alignment.CenterEnd) {
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
            if (leading) SideAvatars(p, size = 30f)
            // weight(fill = false): the avatars are measured first at their fixed size and the name
            // takes what is left, so a long couple's name at a large text size ellipsizes instead of
            // running under the avatars.
            Column(
                Modifier.weight(1f, fill = false),
                horizontalAlignment = if (leading) Alignment.Start else Alignment.End,
                verticalArrangement = Arrangement.spacedBy(1.dp),
            ) {
                val name = AppText.label(11f)
                GameText(p.name.uppercase(), name, Color.White, maxLines = 1, overflow = TextOverflow.Ellipsis, autoSize = shrinkable(name, 0.7f))
                Crowns(count = crowns, size = 12f, empty = Color.White.copy(alpha = 0.5f))
            }
            if (!leading) SideAvatars(p, size = 30f)
        }
    }
}

/** SwiftUI's `.minimumScaleFactor`: the text may shrink to [minScale] of [style]'s size before it truncates. */
internal fun shrinkable(style: TextStyle, minScale: Float): TextAutoSize {
    val max = style.fontSize.value
    return TextAutoSize.StepBased(minFontSize = (max * minScale).sp, maxFontSize = max.sp, stepSize = 0.5f.sp)
}

// MARK: - Hand-off

@Composable
fun HandoffScreen(name: String, onContinue: () -> Unit) {
    val reduceMotion = LocalReduceMotion.current
    // The icon rocks between -6 and 6 degrees; under Reduce Motion it rests at the first pose, as on iOS.
    val tilt: State<Float> = if (reduceMotion) {
        remember { mutableFloatStateOf(-6f) }
    } else {
        rememberInfiniteTransition(label = "handoff").animateFloat(
            initialValue = -6f, targetValue = 6f,
            animationSpec = infiniteRepeatable(tween(400, easing = EaseInOut), RepeatMode.Reverse),
            label = "tilt",
        )
    }
    Stage(background = { GameBackground(top = Theme.violet, bottom = Theme.violetDeep) }) {
        PinnedColumn(
            spacing = 18.dp,
            modifier = Modifier.padding(20.dp),
            bottom = {
                ChunkyButton(
                    text = if (name.contains("&")) "We're ready" else "I'm $name, let's go",
                    onClick = {
                        Haptics.tap()
                        onContinue()
                    },
                    modifier = Modifier.testTag("handoff-continue"),
                    color = Theme.gold,
                )
            },
        ) {
            HandoffIcon(size = 96f, modifier = Modifier.graphicsLayer { rotationZ = tilt.value })
            Kicker("HAND THE PHONE TO")
            StickerText(name.uppercase(), size = TypeScale.display)
            OlaSays("No peeking. Their questions are next.")
        }
    }
}

// MARK: - Round intro

@Composable
fun RoundIntroScreen(controller: MatchController, round: Int) {
    val snap by controller.snapshot.collectAsState()
    val deck = snap.deck
    val top = deck?.color ?: Theme.violet
    Stage(background = { GameBackground(top = top, bottom = top.mix(Color.Black, 0.35f)) }) {
        PinnedColumn(
            spacing = 14.dp,
            modifier = Modifier.padding(20.dp),
            top = {
                MatchHeader(controller)
            },
            bottom = {
                ChunkyButton(
                    text = "Start round $round",
                    onClick = {
                        Haptics.heavy()
                        controller.beginAnswering()
                    },
                    modifier = Modifier.testTag("start-round"),
                    color = Theme.gold,
                )
            },
        ) {
            if (deck != null) {
                Mascot(deck, mood = Mood.Think, size = 170f)
                val member = snap.currentMember
                if (snap.state.mode == MatchMode.teams && member != null) {
                    StickerText("${member.name.uppercase()}, YOU'RE UP", size = TypeScale.heading, color = Theme.gold)
                }
                Kicker("ROUND $round OF ${MatchState.maxRounds} · ${MatchEngine.roundLabel(round)}")
                StickerText(deck.title.uppercase(), size = TypeScale.title, modifier = Modifier.liftTop(UI.s(6.dp)))
                OlaSays(introLine(deck, partnerName = snap.state.partner(controller.me)?.name, round = round))
            }
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                Fact("${MatchState.questionsPerRound}", "QUESTIONS")
                Fact("${MatchEngine.secondsPerQuestion.toInt()}s", "EACH")
                Fact(MatchEngine.tierName(MatchEngine.tiers(round).maxOrNull() ?: 1), "TOP TIER")
            }
        }
    }
}

private fun introLine(deck: Deck, partnerName: String?, round: Int): String {
    val who = partnerName ?: "Your partner"
    return when (round) {
        1 -> "$who picked this one for you. Warm-up questions. Deep breath."
        5 -> "$who chose ${deck.title} for the last word. All legend-tier. No pressure."
        else -> "$who thinks you don't know ${deck.title}. Time to find out."
    }
}

@Composable
private fun RowScope.Fact(value: String, label: String) {
    Column(Modifier.weight(1f).panel(padding = 10f, radius = 14f), horizontalAlignment = Alignment.CenterHorizontally) {
        GameText(value, AppText.score(26f), Theme.ink, maxLines = 1)
        // One line, shrinking rather than breaking "QUESTIONS" mid-word at large text sizes, so the
        // three panels stay the same height.
        val style = AppText.label(10f).copy(letterSpacing = 1.sp)
        GameText(label, style, Theme.ink2, maxLines = 1, autoSize = shrinkable(style, 0.6f))
    }
}

/** SwiftUI's `.padding(.top, -x)`: pulls the view up by [amount] and shortens its slot to match. */
private fun Modifier.liftTop(amount: Dp): Modifier = layout { measurable, constraints ->
    val placeable = measurable.measure(constraints)
    val lift = amount.roundToPx()
    layout(placeable.width, (placeable.height - lift).coerceAtLeast(0)) { placeable.place(0, -lift) }
}

// MARK: - Waiting

@Composable
fun WaitingScreen(controller: MatchController, onClose: () -> Unit) {
    val snap by controller.snapshot.collectAsState()
    // Picked once. Chosen inside the body it changed on every redraw, so the mascot flickered
    // through decks whenever anything else on the screen moved.
    val companion = remember { Decks.all.randomOrNull() }
    var confirmLeave by remember { mutableStateOf(false) }
    // The last turn failed to reach the other side. It is still only on this phone.
    val unsent = snap.error != null
    val partnerName = snap.state.partner(controller.me)?.name
    // Leaving with an unsent turn throws the round away, so say so rather than letting it vanish.
    val attemptClose: () -> Unit = { if (unsent) confirmLeave = true else onClose() }

    Stage(background = { GameBackground(top = Theme.violet, bottom = Theme.violetDeep) }) {
        PinnedColumn(
            spacing = 16.dp,
            modifier = Modifier.padding(20.dp),
            top = {
                MatchHeader(controller, onClose = attemptClose)
            },
            bottom = {
                ChunkyButton(text = "Back to matches", onClick = attemptClose, color = Color.White, edge = Theme.panelEdge, ink = Theme.ink)
            },
        ) {
            if (companion != null) Mascot(companion, mood = if (unsent) Mood.Sad else Mood.Think, size = 130f)
            // Saying "their turn" when the upload failed is simply untrue: the move never left
            // this phone. Say what actually happened.
            Kicker(if (unsent) "STILL ON THIS PHONE" else "THEIR MOVE")
            StickerText(if (unsent) "NOT SENT YET" else "${partnerName?.uppercase() ?: "YOUR PARTNER"}'S TURN", size = TypeScale.title)
            OlaSays(
                when {
                    unsent -> "Your last turn didn't reach them. Try again when you have a signal."
                    controller.transport.isPassAndPlay -> "Hand the phone over when they're ready."
                    else -> "You'll get a notification when they've played. Go live your life."
                },
            )
            val err = snap.error
            if (err != null) {
                Column(
                    Modifier.padding(horizontal = 8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    GameText(err, AppText.body(13f), Theme.gold, align = TextAlign.Center)
                    ChunkyButton(
                        text = "Try again",
                        onClick = { controller.retrySubmit() },
                        modifier = Modifier.testTag("retry-submit"),
                        color = Theme.gold,
                        height = 48f,
                        fontSize = 18f,
                    )
                }
            }
            RoundHistory(controller)
        }
    }

    if (confirmLeave) {
        AlertDialog(
            onDismissRequest = { confirmLeave = false },
            title = { GameText("This round hasn't been sent", AppText.headline(TypeScale.heading), Theme.ink) },
            text = { GameText("Your answers are only on this phone. Leaving now means playing the round again.", AppText.body(15f), Theme.ink2) },
            confirmButton = {
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    DialogAction("Try again", Theme.ink) {
                        confirmLeave = false
                        controller.retrySubmit()
                    }
                    DialogAction("Leave and lose it", Theme.bad) {
                        confirmLeave = false
                        onClose()
                    }
                }
            },
            dismissButton = { DialogAction("Stay", Theme.ink) { confirmLeave = false } },
            containerColor = Theme.panel,
            titleContentColor = Theme.ink,
            textContentColor = Theme.ink2,
        )
    }
}

/** One choice in a confirmation: the game's type on the platform's dialog button. */
@Composable
private fun DialogAction(text: String, color: Color, onClick: () -> Unit) {
    TextButton(onClick = onClick) { GameText(text, AppText.bodyBold(15f), color) }
}

// MARK: - Scorecard

/** The scoreboard of completed rounds. */
@Composable
fun RoundHistory(controller: MatchController) {
    val snap by controller.snapshot.collectAsState()
    val s = snap.state
    Column(Modifier.fillMaxWidth().panel(padding = 14f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Kicker("SCORECARD", color = Theme.ink2, size = 11f)
        for (r in s.rounds) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                GameText("R${r.number}", AppText.label(12f), Theme.ink2, Modifier.width(28.dp))
                for (p in s.players) {
                    val picked = p.members.any { r.picks[it.id] != null }
                    val done = p.members.all { r.results[it.id] != null }
                    Row(Modifier.weight(1f), horizontalArrangement = Arrangement.spacedBy(6.dp), verticalAlignment = Alignment.CenterVertically) {
                        for (m in p.members) {
                            val deck = r.picks[m.id]?.let(Decks::byID)
                            if (deck != null) DeckIcon(deck.id, fill = Color.White, ink = deck.color, modifier = Modifier.size(16.dp))
                        }
                        GameText(if (done) r.score(p).grouped() else if (picked) "…" else "—", AppText.score(20f), Theme.ink)
                        if (s.roundWinner(r) == p.id) CrownIcon(size = 15f)
                    }
                }
            }
        }
        if (s.rounds.isEmpty()) GameText("No rounds yet.", AppText.body(13f), Theme.ink2)
    }
}
