package co.nsgsolutions.spinola.ui.screens

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import co.nsgsolutions.spinola.engine.MatchController
import co.nsgsolutions.spinola.engine.MatchEngine
import co.nsgsolutions.spinola.model.Decks
import co.nsgsolutions.spinola.model.MatchMode
import co.nsgsolutions.spinola.model.Member
import co.nsgsolutions.spinola.model.World
import co.nsgsolutions.spinola.ui.hud.GameBackground
import co.nsgsolutions.spinola.ui.hud.Kicker
import co.nsgsolutions.spinola.ui.hud.OlaSays
import co.nsgsolutions.spinola.ui.hud.Stage
import co.nsgsolutions.spinola.ui.hud.StageScroll
import co.nsgsolutions.spinola.ui.hud.StickerText
import co.nsgsolutions.spinola.ui.hud.WheelView
import co.nsgsolutions.spinola.ui.theme.TypeScale
import co.nsgsolutions.spinola.ui.theme.UI

// Port of Views/DeckPickView.swift.

/** You pick the deck your partner has to answer. Spin, or just tap the slice you want. */
@Composable
fun DeckPickScreen(controller: MatchController, round: Int, target: Member) {
    val snap by controller.snapshot.collectAsState()
    val world = target.answers
    val decks = Decks.decks(world)
    val who = target.name
    Stage(background = { GameBackground(world) }) {
        StageScroll {
            Column(
                Modifier.fillMaxWidth().padding(20.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(14.dp),
            ) {
                MatchHeader(controller)
                Column(
                    Modifier.padding(top = 6.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(4.dp),
                ) {
                    Kicker("ROUND $round · ${MatchEngine.roundLabel(round)}")
                    StickerText("WHAT DOES ${who.uppercase()} GET?", size = TypeScale.title)
                }
                // Keyed on the target (`.id(target.id)` on iOS) so the wheel starts fresh for each
                // member of a couple instead of carrying the last spin over.
                key(target.id) {
                    WheelView(decks = decks, onPick = controller::pick, enabled = !snap.isSubmitting)
                }
                OlaSays(
                    text = if (snap.state.mode == MatchMode.teams) {
                        "$who answers ${if (world == World.his) "his" else "her"} world. Spin, or tap a slice. Be kind. Or don't."
                    } else {
                        "Spin for a suggestion, or tap the slice you want. Be kind. Or don't."
                    },
                )
                if (snap.isSubmitting) {
                    CircularProgressIndicator(Modifier.size(UI.s(24f).dp), color = Color.White, strokeWidth = 2.5.dp)
                }
            }
        }
    }
}
