package co.nsgsolutions.spinola.ui.hud

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import co.nsgsolutions.spinola.audio.Haptics
import co.nsgsolutions.spinola.model.MatchPlayer
import co.nsgsolutions.spinola.model.Profile
import co.nsgsolutions.spinola.model.World
import co.nsgsolutions.spinola.ui.theme.AppText
import co.nsgsolutions.spinola.ui.theme.Theme
import co.nsgsolutions.spinola.ui.theme.UI
import co.nsgsolutions.spinola.ui.theme.color
import androidx.compose.runtime.saveable.Saver
import androidx.compose.runtime.saveable.listSaver

// Port of the shared half of Views/TeamSetup.swift. JoinTeamView and MyTeamSheet are screens.

/** Two people and the lane each of them answers. */
data class TeamDraft(
    val name1: String = "",
    val name2: String = "",
    val lane1: World = World.his,
    val lane2: World = World.hers,
) {
    val isComplete: Boolean
        get() = name1.trimSpaces().isNotEmpty() && name2.trimSpaces().isNotEmpty()

    val members: List<Pair<String, World>>
        get() = listOf(name1.trimSpaces() to lane1, name2.trimSpaces() to lane2)

    companion object {
        fun mine(profile: Profile?): TeamDraft {
            val lane1 = profile?.teamMyLane ?: profile?.world ?: World.his
            return TeamDraft(
                name1 = profile?.name ?: "",
                lane1 = lane1,
                name2 = profile?.teamPartnerName ?: "",
                lane2 = profile?.teamPartnerLane ?: lane1.other,
            )
        }

        /** Lets a half-typed draft survive rotation and activity recreation (`rememberSaveable`). */
        val Saver: Saver<TeamDraft, Any> = listSaver(
            save = { listOf(it.name1, it.name2, it.lane1.name, it.lane2.name) },
            restore = { TeamDraft(it[0], it[1], World.valueOf(it[2]), World.valueOf(it[3])) },
        )
    }
}

/** Swift's `trimmingCharacters(in: .whitespaces)`: spaces and tabs, not line breaks. */
private fun String.trimSpaces(): String = trim { it == ' ' || it == '\t' || it.category == CharCategory.SPACE_SEPARATOR }

/** Name fields plus a lane toggle per person. */
@Composable
fun TeamSetupFields(
    title: String,
    draft: TeamDraft,
    onDraftChange: (TeamDraft) -> Unit,
    placeholder1: String = "First name",
    placeholder2: String = "Partner's first name",
) {
    Column(Modifier.fillMaxWidth().panel(padding = 14f), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Kicker(title, color = Theme.ink2, size = 12f)
        MemberRow(
            name = draft.name1, onName = { onDraftChange(draft.copy(name1 = it)) },
            lane = draft.lane1, onToggleLane = { onDraftChange(draft.copy(lane1 = draft.lane1.other)) },
            placeholder = placeholder1, imeAction = ImeAction.Next, id = "$title-1",
        )
        MemberRow(
            name = draft.name2, onName = { onDraftChange(draft.copy(name2 = it)) },
            lane = draft.lane2, onToggleLane = { onDraftChange(draft.copy(lane2 = draft.lane2.other)) },
            placeholder = placeholder2, imeAction = ImeAction.Done, id = "$title-2",
        )
        GameText("Tap the pill to change which questions each person answers.", AppText.bodyRegular(11f), Theme.ink2)
    }
}

@Composable
private fun MemberRow(
    name: String,
    onName: (String) -> Unit,
    lane: World,
    onToggleLane: () -> Unit,
    placeholder: String,
    imeAction: ImeAction,
    id: String,
) {
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
        GameTextField(
            value = name,
            onValueChange = onName,
            placeholder = placeholder,
            modifier = Modifier.weight(1f),
            textStyle = AppText.bodyBold(17f),
            height = 46f,
            radius = 12f,
            imeAction = imeAction,
            testTag = "team-name-$id",
        )
        Box(
            Modifier
                .height(46.dp)
                .background(lane.color, RoundedCornerShape(12.dp))
                .clickable(interactionSource = null, indication = null, role = Role.Button) {
                    Haptics.tap()
                    onToggleLane()
                }
                .testTag("team-lane-$id")
                .padding(horizontal = 10.dp),
            contentAlignment = Alignment.Center,
        ) {
            GameText("ANSWERS ${if (lane == World.his) "HIS" else "HER"}", AppText.label(11f).copy(letterSpacing = 0.8.sp), Color.White)
        }
    }
}

/** Stacked avatars for a side, solo or couple. */
@Composable
fun SideAvatars(player: MatchPlayer, size: Float = 36f) {
    // Avatar scales itself, so it gets the raw size; the layout around it needs the scaled one.
    val s = UI.s(size)
    if (player.isTeam) {
        Box(Modifier.size((s * 1.6f).dp, s.dp), contentAlignment = Alignment.Center) {
            player.members.forEachIndexed { i, m ->
                Avatar(name = m.name, world = m.knows, size = size, modifier = Modifier.offset(x = (i * s * 0.55f - s * 0.27f).dp))
            }
        }
    } else {
        Avatar(name = player.name, world = player.world, size = size)
    }
}
