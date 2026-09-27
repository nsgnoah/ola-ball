package co.nsgsolutions.spinola.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.TextAutoSize
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import co.nsgsolutions.spinola.LocalMatchStore
import co.nsgsolutions.spinola.LocalProfileStore
import co.nsgsolutions.spinola.audio.Haptics
import co.nsgsolutions.spinola.model.MatchMode
import co.nsgsolutions.spinola.model.MatchState
import co.nsgsolutions.spinola.model.MatchStatus
import co.nsgsolutions.spinola.model.Profile
import co.nsgsolutions.spinola.model.World
import co.nsgsolutions.spinola.ui.hud.Avatar
import co.nsgsolutions.spinola.ui.hud.ChunkyButton
import co.nsgsolutions.spinola.ui.hud.Crowns
import co.nsgsolutions.spinola.ui.hud.GameBackground
import co.nsgsolutions.spinola.ui.hud.GameText
import co.nsgsolutions.spinola.ui.hud.GameTextField
import co.nsgsolutions.spinola.ui.hud.Glyph
import co.nsgsolutions.spinola.ui.hud.GlyphKind
import co.nsgsolutions.spinola.ui.hud.Kicker
import co.nsgsolutions.spinola.ui.hud.OlaSays
import co.nsgsolutions.spinola.ui.hud.RoundIconButton
import co.nsgsolutions.spinola.ui.hud.SideAvatars
import co.nsgsolutions.spinola.ui.hud.Stage
import co.nsgsolutions.spinola.ui.hud.StageScroll
import co.nsgsolutions.spinola.ui.hud.StickerText
import co.nsgsolutions.spinola.ui.hud.TeamDraft
import co.nsgsolutions.spinola.ui.hud.TeamSetupFields
import co.nsgsolutions.spinola.ui.hud.Wordmark
import co.nsgsolutions.spinola.ui.hud.WorldTag
import co.nsgsolutions.spinola.ui.hud.panel
import co.nsgsolutions.spinola.ui.theme.AppText
import co.nsgsolutions.spinola.ui.theme.Theme
import co.nsgsolutions.spinola.ui.theme.TypeScale
import co.nsgsolutions.spinola.ui.theme.color
import co.nsgsolutions.spinola.ui.theme.mix
import kotlinx.coroutines.launch
import kotlin.math.max
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.text.style.TextOverflow
import co.nsgsolutions.spinola.ui.theme.LocalReduceMotion

// Port of Views/HomeView.swift. Android has no Game Center, so the "ONLINE · TWO PHONES" section
// and everything that hung off it (the matchmaker, the my-team sheet, the sign-in panel) is not
// here. The MatchTransport seam in the core module stays, so an online transport can be added later.

/** The lobby: who you are, the pass-and-play matches on this phone, and the way to start one. */
@Composable
fun HomeScreen(onOpenMatch: (String) -> Unit) {
    val profiles = LocalProfileStore.current
    val localMatches = LocalMatchStore.current
    val profile by profiles.profile.collectAsState()
    val matches by localMatches.matches.collectAsState()
    // Saveable, so a tablet rotation keeps an open sheet, dialog or About screen where it was, as
    // `@State` does on iOS.
    var showNewLocal by rememberSaveable { mutableStateOf(false) }
    var showResetConfirm by rememberSaveable { mutableStateOf(false) }
    var showAbout by rememberSaveable { mutableStateOf(false) }
    val reduceMotion = LocalReduceMotion.current

    Box(Modifier.fillMaxSize()) {
        // Home stays composed under About (it keeps its scroll position), and is hidden from
        // screen readers while About covers it.
        Box(Modifier.fillMaxSize().then(if (showAbout) Modifier.clearAndSetSemantics {} else Modifier)) {
        Stage(background = { GameBackground(top = Theme.violet, bottom = Theme.violetDeep) }) {
            StageScroll {
                Column(
                    Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 8.dp, bottom = 24.dp),
                    verticalArrangement = Arrangement.spacedBy(18.dp),
                ) {
                    Header()
                    profile?.let { YouCard(it) }
                    PassAndPlaySection(
                        matches = matches,
                        onOpen = onOpenMatch,
                        onDelete = { localMatches.delete(it) },
                        onNew = {
                            Haptics.tap()
                            showNewLocal = true
                        },
                    )
                    Footer(onAbout = { showAbout = true }, onStartOver = { showResetConfirm = true })
                }
            }
        }
        }
        // The iOS fullScreenCover: About slides up over Home and back down (a fade under Reduce
        // Motion), the same presentation the match cover uses. AboutScreen handles back itself.
        AnimatedVisibility(
            visible = showAbout,
            enter = if (reduceMotion) fadeIn() else slideInVertically { it },
            exit = if (reduceMotion) fadeOut() else slideOutVertically { it },
        ) {
            AboutScreen(onClose = { showAbout = false })
        }
    }

    if (showNewLocal) {
        NewLocalMatchSheet(
            onDismiss = { showNewLocal = false },
            onCreate = { id ->
                showNewLocal = false
                onOpenMatch(id)
            },
        )
    }

    if (showResetConfirm) {
        StartOverDialog(
            onConfirm = {
                showResetConfirm = false
                localMatches.reset()
                profiles.reset()
            },
            onCancel = { showResetConfirm = false },
        )
    }
}

// MARK: Sections

@Composable
private fun Header() {
    Column(
        Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Kicker("SPINOLA · TRIVIA FOR TWO")
        Wordmark()
        GameText(
            "Pick what your partner gets quizzed on. They pick yours. First to three crowns.",
            AppText.body(13f), Color.White.copy(alpha = 0.85f), align = TextAlign.Center,
        )
    }
}

@Composable
private fun YouCard(p: Profile) {
    Row(
        Modifier.fillMaxWidth().panel(padding = 14f),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Avatar(name = p.name, world = p.world, size = 48f)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            GameText(p.name.uppercase(), AppText.headline(24f), Theme.ink)
            GameText(p.world.iKnowLine, AppText.body(13f), Theme.ink2)
        }
        WorldTag(world = p.world)
    }
}

@Composable
private fun PassAndPlaySection(
    matches: Map<String, MatchState>,
    onOpen: (String) -> Unit,
    onDelete: (String) -> Unit,
    onNew: () -> Unit,
) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Kicker("PASS & PLAY · ONE PHONE")
        val sorted = matches.entries.sortedByDescending { it.value.updatedAt }
        for ((id, state) in sorted) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                LocalMatchRow(
                    state,
                    Modifier
                        .weight(1f)
                        .clickable(interactionSource = null, indication = null, role = Role.Button) { onOpen(id) }
                        .testTag("local-match-$id"),
                )
                if (state.status == MatchStatus.finished) {
                    RoundIconButton(
                        kind = GlyphKind.Trash,
                        contentDescription = "Delete match",
                        onClick = { onDelete(id) },
                        glyphSize = 17f,
                    )
                }
            }
        }
        ChunkyButton(
            text = "New pass & play",
            onClick = onNew,
            modifier = Modifier.testTag("new-local-match"),
            color = Color.White,
            edge = Theme.panelEdge,
            ink = Theme.ink,
            leading = { Glyph(kind = GlyphKind.People, size = 22f, color = Theme.ink) },
        )
    }
}

@Composable
private fun LocalMatchRow(state: MatchState, modifier: Modifier = Modifier) {
    val a = state.players[0]
    val b = state.players.getOrNull(1)
    val turnName = state.turnPlayerID?.let { state.player(it)?.name } ?: ""
    val status = buildString {
        if (state.mode == MatchMode.teams) append("Couples · ")
        if (state.status == MatchStatus.finished) {
            val winner = state.winnerID?.let { state.player(it)?.name }
            append("Final · ").append(winner?.let { "$it won" } ?: "Tie")
        } else {
            append("Round ${max(1, state.rounds.size)} · $turnName's move")
        }
    }
    Row(
        modifier.fillMaxWidth().panel(padding = 12f, radius = 18f),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SideAvatars(player = a, size = 36f)
        Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
            val name = AppText.headline(20f)
            GameText(
                "${a.name.uppercase()} VS ${b?.name?.uppercase() ?: "?"}", name, Theme.ink,
                maxLines = 1, overflow = TextOverflow.Ellipsis, autoSize = shrink(name, 0.6f),
            )
            val line = AppText.body(12f)
            GameText(status, line, Theme.ink2, maxLines = 2, overflow = TextOverflow.Ellipsis, autoSize = shrink(line, 0.7f))
        }
        Column(horizontalAlignment = Alignment.End, verticalArrangement = Arrangement.spacedBy(3.dp)) {
            Crowns(count = state.crowns(a.id), size = 13f)
            if (b != null) Crowns(count = state.crowns(b.id), size = 13f)
        }
    }
}

@Composable
private fun Footer(onAbout: () -> Unit, onStartOver: () -> Unit) {
    var expanded by remember { mutableStateOf(false) }
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
        // The menu anchors to the button, so both share a Box.
        Box {
            RoundIconButton(kind = GlyphKind.More, contentDescription = "More", onClick = { expanded = true }, glyphSize = 18f)
            DropdownMenu(
                expanded = expanded,
                onDismissRequest = { expanded = false },
                shape = RoundedCornerShape(16.dp),
                containerColor = Theme.panel,
            ) {
                DropdownMenuItem(
                    text = { GameText("Privacy & support", AppText.body(17f), Theme.ink) },
                    onClick = {
                        expanded = false
                        onAbout()
                    },
                    modifier = Modifier.testTag("open-about"),
                )
                DropdownMenuItem(
                    text = { GameText("Start over", AppText.body(17f), Theme.bad) },
                    onClick = {
                        expanded = false
                        onStartOver()
                    },
                )
            }
        }
    }
}

/** The iOS confirmation dialog, minus its message, which is only about Game Center. */
@Composable
private fun StartOverDialog(onConfirm: () -> Unit, onCancel: () -> Unit) {
    AlertDialog(
        onDismissRequest = onCancel,
        title = { GameText("Start over?", AppText.headline(TypeScale.heading), Theme.ink) },
        // No message: the iOS one is only the Game Center sentence, and the button already says what goes.
        text = null,
        confirmButton = {
            TextButton(onClick = onConfirm, colors = ButtonDefaults.textButtonColors(contentColor = Theme.bad)) {
                GameText("Reset profile and pass-and-play matches", AppText.bodyBold(15f), Theme.bad)
            }
        },
        dismissButton = {
            TextButton(onClick = onCancel, colors = ButtonDefaults.textButtonColors(contentColor = Theme.ink)) {
                GameText("Cancel", AppText.bodyBold(15f), Theme.ink)
            }
        },
        shape = RoundedCornerShape(22.dp),
        containerColor = Theme.panel,
        titleContentColor = Theme.ink,
        textContentColor = Theme.ink2,
    )
}

// MARK: New match

/** Set up a pass-and-play match: you vs your partner, or your couple vs another couple, all on this phone. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NewLocalMatchSheet(onDismiss: () -> Unit, onCreate: (String) -> Unit) {
    val profiles = LocalProfileStore.current
    val localMatches = LocalMatchStore.current
    val profile by profiles.profile.collectAsState()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    // Saveable, so rotating a tablet with the sheet open keeps what was typed. Prefilled from the
    // profile as iOS does in onAppear; the sheet is composed fresh each time it opens.
    var mode by rememberSaveable { mutableStateOf(MatchMode.couple) }
    var partnerName by rememberSaveable { mutableStateOf("") }
    var partnerWorld by rememberSaveable { mutableStateOf(profile?.world?.other) }
    var ours by rememberSaveable(stateSaver = TeamDraft.Saver) { mutableStateOf(TeamDraft.mine(profile)) }
    var theirs by rememberSaveable(stateSaver = TeamDraft.Saver) { mutableStateOf(TeamDraft()) }
    // Set on the first tap. The sheet takes a moment to slide away and the button is still on
    // screen meanwhile; on iOS the sheet closes at once, so a second tap cannot make a second match.
    var starting by remember { mutableStateOf(false) }

    val canStart = when (mode) {
        MatchMode.couple -> partnerWorld != null && partnerName.trimSpaces().isNotEmpty()
        MatchMode.teams -> ours.isComplete && theirs.isComplete
    }

    fun start() {
        val me = profile ?: return
        if (!canStart || starting) return
        starting = true
        Haptics.heavy()
        val id = when (mode) {
            MatchMode.couple -> localMatches.create(
                me = me,
                partnerName = partnerName.trimSpaces(),
                partnerWorld = partnerWorld ?: me.world.other,
            )
            MatchMode.teams -> {
                // Remember the couple, so the next teams match starts filled in.
                profiles.set(me.copy(teamPartnerName = ours.name2.trimSpaces(), teamMyLane = ours.lane1, teamPartnerLane = ours.lane2))
                localMatches.createTeams(ours = ours.members, theirs = theirs.members)
            }
        }
        // Let the sheet slide away before the match cover comes up; a sheet dismissed at the same
        // moment would otherwise linger on top of the match for a beat.
        scope.launch { sheetState.hide() }.invokeOnCompletion { onCreate(id) }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        shape = RoundedCornerShape(topStart = 28.dp, topEnd = 28.dp),
        // GameBackground's own base colour, so the strips Material pads for the system bars match it.
        containerColor = Theme.violet.mix(Theme.night, 0.34f),
        dragHandle = null,
    ) {
        Box(Modifier.fillMaxWidth()) {
            // The backdrop sizes itself to the sheet, not the window: a medium sheet, as on iOS, not a second screen.
            Box(Modifier.matchParentSize()) { GameBackground(top = Theme.violet, bottom = Theme.violetDeep) }
            // imePadding outside the scroll so the viewport itself shrinks above the keyboard.
            Column(Modifier.fillMaxWidth().imePadding().verticalScroll(rememberScrollState())) {
                // The grabber, in place of Material's grey pill.
                Box(
                    Modifier
                        .align(Alignment.CenterHorizontally)
                        .padding(top = 10.dp)
                        .size(40.dp, 4.dp)
                        .background(Color.White.copy(alpha = 0.5f), CircleShape),
                )
                Column(
                    Modifier.fillMaxWidth().padding(start = 20.dp, end = 20.dp, top = 12.dp, bottom = 20.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp),
                ) {
                    Kicker("PASS & PLAY")
                    StickerText("WHO'S PLAYING?", size = TypeScale.title, align = TextAlign.Start)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        for (m in listOf(MatchMode.couple, MatchMode.teams)) {
                            val selected = mode == m
                            ChunkyButton(
                                text = m.title,
                                onClick = {
                                    Haptics.tap()
                                    mode = m
                                },
                                modifier = Modifier.weight(1f).testTag("mode-${m.name}"),
                                color = if (selected) Theme.gold else Color.White,
                                edge = if (selected) null else Theme.panelEdge,
                                ink = Theme.ink,
                                height = 46f,
                                fontSize = 17f,
                            )
                        }
                    }
                    when (mode) {
                        MatchMode.couple -> {
                            GameTextField(
                                value = partnerName,
                                onValueChange = { partnerName = it },
                                placeholder = "Partner's first name",
                                textStyle = AppText.bodyBold(20f),
                                testTag = "partner-name",
                            )
                            Kicker("THEY KNOW")
                            Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                                for (w in World.entries) {
                                    val selected = partnerWorld == w
                                    ChunkyButton(
                                        text = w.title.uppercase(),
                                        onClick = {
                                            Haptics.tap()
                                            partnerWorld = w
                                        },
                                        modifier = Modifier.weight(1f).testTag("partner-world-${w.name}"),
                                        color = if (selected) w.color else Color.White,
                                        edge = if (selected) null else Theme.panelEdge,
                                        ink = if (selected) Color.White else Theme.ink,
                                        height = 50f,
                                        fontSize = 20f,
                                    )
                                }
                            }
                            OlaSays("You get quizzed on their world. They get quizzed on yours.")
                        }
                        MatchMode.teams -> {
                            TeamSetupFields(title = "YOUR COUPLE", draft = ours, onDraftChange = { ours = it })
                            TeamSetupFields(
                                title = "THE OTHER COUPLE",
                                draft = theirs,
                                onDraftChange = { theirs = it },
                                placeholder1 = "Their first name",
                                placeholder2 = "Their partner's first name",
                            )
                            OlaSays("Each couple picks decks for the other couple. Scores add up. First to three crowns.")
                        }
                    }
                    ChunkyButton(
                        text = "Start the match",
                        onClick = { start() },
                        modifier = Modifier.padding(top = 4.dp).testTag("create-local-match"),
                        color = Theme.gold,
                        enabled = canStart && !starting,
                    )
                }
            }
        }
    }
}

// MARK: Helpers

/** SwiftUI's `minimumScaleFactor`: the type shrinks, never past [factor] of its size, before it would overflow. */
private fun shrink(style: TextStyle, factor: Float): TextAutoSize =
    TextAutoSize.StepBased(minFontSize = style.fontSize * factor, maxFontSize = style.fontSize, stepSize = 0.5f.sp)

/** Swift's `trimmingCharacters(in: .whitespaces)`: spaces and tabs, not line breaks. */
private fun String.trimSpaces(): String = trim { it == ' ' || it == '\t' || it.category == CharCategory.SPACE_SEPARATOR }
