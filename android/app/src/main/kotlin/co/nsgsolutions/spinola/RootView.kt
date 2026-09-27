package co.nsgsolutions.spinola

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.key
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import co.nsgsolutions.spinola.services.LocalMatchStore as MatchStore
import co.nsgsolutions.spinola.services.ProfileStore
import co.nsgsolutions.spinola.ui.screens.HomeScreen
import co.nsgsolutions.spinola.ui.screens.MatchScreen
import co.nsgsolutions.spinola.ui.screens.ProfileSetupScreen
import co.nsgsolutions.spinola.ui.theme.LocalReduceMotion
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.lifecycle.viewmodel.compose.viewModel
import co.nsgsolutions.spinola.ui.screens.MatchHost

/** Who you are on this phone. Provided by [RootView]; the SwiftUI `@Environment(ProfileStore.self)`. */
val LocalProfileStore = staticCompositionLocalOf<ProfileStore> { error("No ProfileStore: is this composable under RootView?") }

/** Pass-and-play matches on this phone. Provided by [RootView]; the SwiftUI `@Environment(LocalMatchStore.self)`. */
val LocalMatchStore = staticCompositionLocalOf<MatchStore> { error("No LocalMatchStore: is this composable under RootView?") }

/**
 * The app shell, `RootView` on iOS: profile setup until there is a profile, then the home screen,
 * with an open match presented full-screen over it (the SwiftUI `fullScreenCover`). The canvas
 * scale is NOT measured here: [SpinolaRoot] does that at the window level.
 */
@Composable
fun RootView() {
    val context = LocalContext.current
    val app = remember(context) { SpinolaApp.of(context) }
    CompositionLocalProvider(LocalProfileStore provides app.profiles, LocalMatchStore provides app.matches) {
        val profile by app.profiles.profile.collectAsState()
        var openMatchID by rememberSaveable { mutableStateOf<String?>(null) }
        // The open match's controller lives in the activity's MatchHost so it survives rotation;
        // closing the cover (or opening another match) is what lets it go.
        val host = viewModel<MatchHost>()
        LaunchedEffect(openMatchID) { host.retainOnly(openMatchID) }
        Box(Modifier.fillMaxSize()) {
            // The lobby stays composed under the cover, as iOS keeps HomeView under its
            // fullScreenCover, but a screen reader must not wander from a question into it.
            Box(Modifier.fillMaxSize().then(if (openMatchID != null) Modifier.clearAndSetSemantics {} else Modifier)) {
                if (profile == null) {
                    ProfileSetupScreen()
                } else {
                    HomeScreen(onOpenMatch = { openMatchID = it })
                }
            }
            MatchCover(openMatchID, onClose = { openMatchID = null }, onRematch = { openMatchID = it })
        }
    }
}

/** The full-screen cover: slides up from the bottom like the iOS one, fades under Reduce Motion. */
@Composable
private fun MatchCover(openMatchID: String?, onClose: () -> Unit, onRematch: (String) -> Unit) {
    val reduceMotion = LocalReduceMotion.current
    // The id keeps showing through the exit slide after the cover has been dismissed.
    var shown by remember { mutableStateOf(openMatchID) }
    if (openMatchID != null) shown = openMatchID
    AnimatedVisibility(
        visible = openMatchID != null,
        enter = if (reduceMotion) fadeIn() else slideInVertically { it },
        exit = if (reduceMotion) fadeOut() else slideOutVertically { it },
    ) {
        val id = shown ?: return@AnimatedVisibility
        // A rematch presents a new cover on iOS; keying on the id gives the new match a fresh screen.
        key(id) {
            MatchScreen(matchID = id, onClose = onClose, onRematch = onRematch)
        }
    }
}
