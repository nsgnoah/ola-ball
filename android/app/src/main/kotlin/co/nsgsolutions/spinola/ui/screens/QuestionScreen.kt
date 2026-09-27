package co.nsgsolutions.spinola.ui.screens

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateIntAsState
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsPressedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import co.nsgsolutions.spinola.audio.Haptics
import co.nsgsolutions.spinola.engine.MatchController
import co.nsgsolutions.spinola.engine.MatchEngine
import co.nsgsolutions.spinola.model.Deck
import co.nsgsolutions.spinola.model.MatchMode
import co.nsgsolutions.spinola.model.Question
import co.nsgsolutions.spinola.ui.hud.Art
import co.nsgsolutions.spinola.ui.hud.ChunkyButton
import co.nsgsolutions.spinola.ui.hud.ConfettiBurst
import co.nsgsolutions.spinola.ui.hud.DeckIcon
import co.nsgsolutions.spinola.ui.hud.GameBackground
import co.nsgsolutions.spinola.ui.hud.GameText
import co.nsgsolutions.spinola.ui.hud.Glyph
import co.nsgsolutions.spinola.ui.hud.GlyphKind
import co.nsgsolutions.spinola.ui.hud.Kicker
import co.nsgsolutions.spinola.ui.hud.Mascot
import co.nsgsolutions.spinola.ui.hud.Mood
import co.nsgsolutions.spinola.ui.hud.OlaSays
import co.nsgsolutions.spinola.ui.hud.Stage
import co.nsgsolutions.spinola.ui.hud.TimerRing
import co.nsgsolutions.spinola.ui.hud.panel
import co.nsgsolutions.spinola.ui.hud.shake
import co.nsgsolutions.spinola.ui.hud.smoothSpring
import co.nsgsolutions.spinola.ui.theme.AppText
import co.nsgsolutions.spinola.ui.theme.LocalReduceMotion
import co.nsgsolutions.spinola.ui.theme.Theme
import co.nsgsolutions.spinola.ui.theme.TypeScale
import co.nsgsolutions.spinola.ui.theme.UI
import co.nsgsolutions.spinola.ui.theme.color
import co.nsgsolutions.spinola.ui.theme.mix
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlin.math.PI
import kotlin.math.pow
import co.nsgsolutions.spinola.ui.theme.grouped
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.foundation.rememberScrollState
import androidx.compose.runtime.withFrameNanos
import co.nsgsolutions.spinola.ui.hud.PinnedColumn

// Port of Views/QuestionView.swift. One question at a time on the deck's colour: the mascot peeks
// over the card, the timer sits on its corner until the answer is in, then the stamp takes over,
// the options light up, Ola has her say and the Next button appears.

@Composable
fun QuestionScreen(controller: MatchController) {
    val snap by controller.snapshot.collectAsState()
    val deck = snap.deck
    val color = deck?.color ?: Theme.violet
    val q = snap.questions.getOrNull(snap.index)

    val shake = remember { Animatable(0f) }
    var confetti by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    // `onChange(of: controller.revealed)` on iOS: confetti for a right answer, a shake for a wrong one.
    LaunchedEffect(snap.revealed, snap.index) {
        if (!snap.revealed || q == null) return@LaunchedEffect
        if (snap.selected == q.correctIndex) {
            // Its own coroutine, like `asyncAfter`: tapping Next inside the 1.8 s must still clear it.
            scope.launch {
                confetti = true
                delay(1800)
                confetti = false
            }
        } else {
            shake.snapTo(0f)
            shake.animateTo(1f, tween(450, easing = LinearEasing))
            shake.snapTo(0f)
        }
    }

    // Only moves on a screen too short for the whole question: each new question starts at the top,
    // and a reveal scrolls down to Ola's verdict (under the options, where it would otherwise sit
    // out of sight). Where everything fits, maxValue is 0 and nothing moves.
    val scroll = rememberScrollState()
    val reduceMotion = LocalReduceMotion.current
    LaunchedEffect(snap.index, snap.revealed) {
        if (!snap.revealed) {
            scroll.scrollTo(0)
        } else {
            withFrameNanos { }   // one frame, so the verdict is laid out and counted in maxValue
            if (reduceMotion) scroll.scrollTo(scroll.maxValue) else scroll.animateScrollTo(scroll.maxValue)
        }
    }
    Stage(background = { GameBackground(top = color, bottom = color.mix(Color.Black, 0.4f)) }) {
        // Centred like the iOS VStack: everything else fills the width, but Ola's verdict is only
        // as wide as its line and sits in the middle under the options. The header and the Next
        // button are pinned; on a short phone the card, options and verdict scroll between them.
        val title = deck?.let {
            if (snap.state.mode == MatchMode.teams) snap.currentMember?.name?.uppercase() ?: "" else it.title.uppercase()
        } ?: ""
        PinnedColumn(
            spacing = 12.dp,
            modifier = Modifier.padding(20.dp),
            scrollState = scroll,
            top = {
                QuestionHeader(deck = deck, title = title, score = snap.runningScore)
                QuestionProgress(snap)
            },
            bottom = {
                if (snap.revealed) {
                    EnterFromBottom(slide = false) {
                        ChunkyButton(
                            text = if (snap.index + 1 >= snap.questions.size) "See the round" else "Next question",
                            onClick = {
                                Haptics.tap()
                                controller.nextQuestion()
                            },
                            modifier = Modifier.testTag("next-question"),
                            color = Theme.gold,
                        )
                    }
                }
            },
        ) {
            if (q != null && deck != null) {
                QuestionCard(q, deck, snap)
                Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                    q.options.forEachIndexed { i, option ->
                        val shaking = snap.revealed && snap.selected == i && i != q.correctIndex
                        OptionRow(
                            index = i, text = option, q = q, snap = snap,
                            shakeProgress = if (shaking) shake.value else 0f,
                            onClick = { controller.select(i) },
                        )
                    }
                }
                if (snap.revealed) {
                    // Picked once per reveal. iOS rolls the line on every body pass, which could
                    // swap it mid-read; remembering it keeps Ola to one verdict.
                    val line = remember(snap.index) { feedbackText(q, snap) }
                    EnterFromBottom { OlaSays(line) }
                }
            }
        }
        if (confetti) ConfettiBurst()
    }
}

// MARK: Pieces

/** Deck badge and title (or, in teams mode, whose turn it is) on the left, the running score on the right. */
@Composable
private fun QuestionHeader(deck: Deck?, title: String, score: Int) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
        Box(Modifier.weight(1f), contentAlignment = Alignment.CenterStart) {
            if (deck != null) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(UI.s(26).dp).background(Color.White, CircleShape)) {
                        DeckIcon(deck.id, fill = Color.White, ink = deck.color, modifier = Modifier.padding(4.dp))
                    }
                    // `.lineLimit(1).minimumScaleFactor(0.7)`: shrink to seven tenths before truncating.
                    val style = AppText.label(TypeScale.label).copy(letterSpacing = 0.8.sp)
                    GameText(
                        title, style, Color.White, Modifier.weight(1f, fill = false),
                        maxLines = 1, overflow = TextOverflow.Ellipsis,
                        autoSize = TextAutoSize.StepBased(minFontSize = style.fontSize * 0.7f, maxFontSize = style.fontSize, stepSize = 0.5.sp),
                    )
                }
            }
        }
        ScorePill(score)
    }
}

/** "NNN PTS" in a white capsule on a panel-edge shadow; the number counts up to each new total. */
@Composable
private fun ScorePill(score: Int) {
    val shown by animateIntAsState(score, smoothSpring(0.4f), label = "score")
    Box(
        Modifier
            .drawBehind {
                val r = CornerRadius(size.height / 2f)
                drawRoundRect(Theme.panelEdge, topLeft = Offset(0f, 3.dp.toPx()), cornerRadius = r)
                drawRoundRect(Color.White, cornerRadius = r)
            }
            .height(UI.s(34).dp)
            .padding(horizontal = UI.s(12).dp),
        contentAlignment = Alignment.Center,
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            GameText(shown.grouped(), AppText.score(26f), Theme.ink, Modifier.alignByBaseline())
            GameText("PTS", AppText.label(10f), Theme.ink2, Modifier.alignByBaseline())
        }
    }
}

/** One capsule per question: green or red once answered, white for the current one, faint for the rest. */
@Composable
private fun QuestionProgress(snap: MatchController.Snapshot) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        for (i in snap.questions.indices) {
            val done = i < snap.answers.size
            val right = done && snap.answers[i] == snap.questions[i].correctIndex
            val target = when {
                done -> if (right) Theme.good else Theme.bad
                i == snap.index -> Color.White
                else -> Color.White.copy(alpha = 0.3f)
            }
            val fill by animateColorAsState(target, smoothSpring(0.3f), label = "dot")
            Box(Modifier.weight(1f).height(6.dp).background(fill, CircleShape))
        }
    }
}

/** The question card with the mascot peeking over its top edge and the timer on its corner. */
@Composable
private fun QuestionCard(q: Question, deck: Deck, snap: MatchController.Snapshot) {
    val mood = when {
        !snap.revealed -> Mood.Think
        snap.selected == q.correctIndex -> Mood.Happy
        else -> Mood.Sad
    }
    Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.TopCenter) {
        Column(
            Modifier
                .padding(top = UI.s(56).dp)
                .fillMaxWidth()
                .panel(padding = 0f)
                .padding(horizontal = UI.s(18).dp)
                .padding(top = UI.s(50).dp, bottom = UI.s(18).dp),   // clearance for the mascot peeking over the card
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            Kicker(
                "${MatchEngine.tierName(q.tier)} · ${snap.index + 1} of ${snap.questions.size}",
                color = Art.darker(deck.color, 0.5f),   // the deck colour itself is too pale on cream
                size = 12f,
            )
            GameText(
                q.prompt, AppText.headline(TypeScale.heading), Theme.ink,
                Modifier.fillMaxWidth().testTag("question-prompt"),
                align = TextAlign.Center,
            )
        }
        // Re-keyed per question and mood, as `.id()` does on iOS, so the mascot re-enters each time.
        key(snap.index, mood) { Mascot(deck, mood = mood, size = 84f) }
        Box(Modifier.align(Alignment.TopEnd).offset(x = (-UI.s(6)).dp, y = UI.s(30).dp)) {
            if (snap.revealed) {
                ResultStamp(correct = snap.selected == q.correctIndex, points = lastPoints(q, snap))
            } else {
                TimerRing(startMs = snap.questionStartMs, durationSeconds = MatchEngine.secondsPerQuestion, size = 54f, color = deck.color)
            }
        }
    }
}

/** "+points" or a cross on a good/bad capsule, tilted, popping in from 0.4 scale. */
@Composable
private fun ResultStamp(correct: Boolean, points: Int) {
    // `.spring(duration: 0.35, bounce: 0.5)`: damping ratio is 1 - bounce, stiffness follows from the duration.
    val pop = remember { Animatable(0.4f) }
    LaunchedEffect(Unit) {
        pop.animateTo(1f, spring(dampingRatio = 0.5f, stiffness = (2f * PI.toFloat() / 0.35f).pow(2)))
    }
    val face = if (correct) Theme.good else Theme.bad
    val edge = if (correct) Theme.goodDeep else Theme.badDeep
    Box(
        Modifier
            .graphicsLayer {
                rotationZ = if (correct) -6f else 6f
                scaleX = pop.value
                scaleY = pop.value
            }
            .drawBehind {
                val r = CornerRadius(size.height / 2f)
                drawRoundRect(edge, topLeft = Offset(0f, 3.dp.toPx()), cornerRadius = r)
                drawRoundRect(face, cornerRadius = r)
            }
            .height(UI.s(40).dp)
            .padding(horizontal = UI.s(12).dp),
        contentAlignment = Alignment.Center,
    ) {
        GameText(
            if (correct) "+$points" else "✕", AppText.score(24f), Color.White,
            Modifier.clearAndSetSemantics { contentDescription = if (correct) "+$points points" else "Wrong" },
        )
    }
}

/** The points the stamp shows, from the recorded time and streak, exactly as `lastPoints` on iOS. */
private fun lastPoints(q: Question, snap: MatchController.Snapshot): Int {
    if (snap.index >= snap.timesMs.size) return 0
    return MatchEngine.points(correct = snap.selected == q.correctIndex, elapsedMs = snap.timesMs[snap.index], streak = snap.streak)
}

/**
 * One answer: a lettered badge, the option, and once revealed a lit face (green for the right one,
 * red for a wrong pick) with a check or cross. Not tappable after the reveal.
 */
@Composable
private fun OptionRow(
    index: Int,
    text: String,
    q: Question,
    snap: MatchController.Snapshot,
    shakeProgress: Float,
    onClick: () -> Unit,
) {
    val isCorrect = index == q.correctIndex
    val isMine = snap.selected == index
    val showState = snap.revealed
    val lit = showState && (isCorrect || isMine)
    // The 0.3 s spring the whole screen gets on `revealed` over on iOS.
    val face by animateColorAsState(if (lit) (if (isCorrect) Theme.good else Theme.bad) else Color.White, smoothSpring(0.3f), label = "face")
    val edge by animateColorAsState(if (lit) (if (isCorrect) Theme.goodDeep else Theme.badDeep) else Theme.panelEdge, smoothSpring(0.3f), label = "edge")
    val ink = if (lit) Color.White else Theme.ink
    val interaction = remember { MutableInteractionSource() }
    val pressed by interaction.collectIsPressedAsState()
    Row(
        Modifier
            .fillMaxWidth()
            .shake(shakeProgress)
            .testTag("option-$index")
            // `.buttonStyle(.plain)` dims the label while pressed; no ripple, which reads as generic.
            .graphicsLayer { alpha = if (pressed) 0.75f else 1f }
            .clickable(interactionSource = interaction, indication = null, enabled = !showState, role = Role.Button, onClick = onClick)
            // Colour and a drawn glyph carry the verdict on screen; say it for screen readers too.
            .semantics {
                if (showState && isCorrect) stateDescription = "Correct answer"
                else if (showState && isMine) stateDescription = "Your answer, wrong"
            }
            .drawBehind {
                val r = CornerRadius(16.dp.toPx())
                drawRoundRect(edge, topLeft = Offset(0f, 5.dp.toPx()), cornerRadius = r)
                drawRoundRect(face, cornerRadius = r)
            }
            .padding(horizontal = UI.s(12).dp, vertical = UI.s(12).dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier.size(UI.s(34).dp).background(if (lit) Color.White else Theme.cream, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            GameText(listOf("A", "B", "C", "D")[index], AppText.headline(18f), if (lit) face else Theme.ink)
        }
        GameText(text, AppText.bodyBold(18f), ink, Modifier.weight(1f), align = TextAlign.Start)
        if (lit) {
            Glyph(kind = if (isCorrect) GlyphKind.Check else GlyphKind.Close, size = 16f, weight = 18f)
        }
    }
}

/** Ola's verdict: a line for the outcome, the right answer when it was missed, the fact, and the streak. */
private fun feedbackText(q: Question, snap: MatchController.Snapshot): String {
    val correct = snap.selected == q.correctIndex
    val timedOut = snap.selected == null
    val line = when {
        timedOut -> "Time!"
        correct -> listOf("Nailed it.", "Yes.", "Look at you.", "Correct, obviously.").random()
        else -> listOf("Nope.", "Not that one.", "Close. Not really.").random()
    }
    var text = line
    if (!correct) text += " It's ${q.correct}."
    q.fact?.let { text += " $it" }
    if (correct && snap.streak >= 2) text += " Streak ×${snap.streak}!"
    return text
}

/**
 * SwiftUI's insertion transition here, `.move(edge: .bottom).combined(with: .opacity)` under the
 * screen's 0.3 s spring: the content fades in while rising from one height below its resting place.
 * Removal is instant, because the state change that removes it swaps the whole question anyway.
 * Composed inside an `if` rather than an `AnimatedVisibility` so a hidden piece adds no column spacing.
 */
@Composable
private fun EnterFromBottom(slide: Boolean = true, content: @Composable () -> Unit) {
    val reduceMotion = LocalReduceMotion.current
    val t = remember { Animatable(0f) }
    LaunchedEffect(Unit) {
        if (reduceMotion) t.snapTo(1f) else t.animateTo(1f, smoothSpring(0.3f))
    }
    Box(
        Modifier.graphicsLayer {
            alpha = t.value
            translationY = if (slide) (1f - t.value) * size.height else 0f
        },
    ) { content() }
}
