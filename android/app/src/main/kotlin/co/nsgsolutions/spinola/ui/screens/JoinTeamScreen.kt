package co.nsgsolutions.spinola.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.unit.dp
import co.nsgsolutions.spinola.LocalProfileStore
import co.nsgsolutions.spinola.audio.Haptics
import co.nsgsolutions.spinola.engine.MatchController
import co.nsgsolutions.spinola.ui.hud.ChunkyButton
import co.nsgsolutions.spinola.ui.hud.GameBackground
import co.nsgsolutions.spinola.ui.hud.GameText
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
import co.nsgsolutions.spinola.ui.hud.panel
import co.nsgsolutions.spinola.ui.theme.AppText
import co.nsgsolutions.spinola.ui.theme.Theme
import co.nsgsolutions.spinola.ui.theme.TypeScale

// Port of JoinTeamView in Views/TeamSetup.swift. TeamDraft, TeamSetupFields and SideAvatars are the
// shared half of that file and live in ui/hud/TeamSetup.kt.

/** Couples mode: the challenged side says who its two people are before joining. */
@Composable
fun JoinTeamScreen(controller: MatchController, onClose: () -> Unit) {
    val profiles = LocalProfileStore.current
    val snap by controller.snapshot.collectAsState()
    val challenger = snap.state.players.firstOrNull()
    // Seeded once, when the screen appears (`onAppear` on iOS), from what the profile remembers.
    var draft by remember { mutableStateOf(TeamDraft.mine(profiles.profile.value)) }

    /** Keep the partner and the lanes for next time. `members` carries the trimmed names. */
    fun rememberCouple() {
        val p = profiles.profile.value ?: return
        profiles.set(p.copy(teamPartnerName = draft.members[1].first, teamMyLane = draft.lane1, teamPartnerLane = draft.lane2))
    }

    Stage(background = { GameBackground(top = Theme.violet, bottom = Theme.violetDeep) }) {
        StageScroll {
            Column(
                Modifier.fillMaxWidth().padding(20.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                Row(Modifier.fillMaxWidth()) {
                    RoundIconButton(kind = GlyphKind.Close, contentDescription = "Close", onClick = onClose)
                    Spacer(Modifier.weight(1f))
                }
                Kicker("COUPLE VS COUPLE")
                StickerText("YOU'VE BEEN\nCHALLENGED", size = TypeScale.title)
                if (challenger != null) {
                    Row(
                        Modifier.fillMaxWidth().panel(padding = 12f),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        SideAvatars(challenger, size = 40f)
                        val style = AppText.headline(24f)
                        GameText(challenger.name.uppercase(), style, Theme.ink, maxLines = 1, autoSize = shrinkable(style, 0.6f))
                        Spacer(Modifier.weight(1f))
                    }
                }
                OlaSays("Who's on your side of the couch? Each of you answers your own lane, unless you'd rather swap.")
                TeamSetupFields(title = "YOUR COUPLE", draft = draft, onDraftChange = { draft = it })
                ChunkyButton(
                    text = "Join the match",
                    onClick = {
                        if (draft.isComplete) {
                            Haptics.heavy()
                            rememberCouple()
                            controller.joinTeam(draft.members)
                        }
                    },
                    modifier = Modifier.testTag("join-team"),
                    color = Theme.gold,
                    enabled = draft.isComplete,
                )
            }
        }
    }
}
