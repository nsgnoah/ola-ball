package co.nsgsolutions.spinola.ui.screens

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.core.content.pm.PackageInfoCompat
import co.nsgsolutions.spinola.ui.hud.ChunkyButton
import co.nsgsolutions.spinola.ui.hud.GameBackground
import co.nsgsolutions.spinola.ui.hud.GameText
import co.nsgsolutions.spinola.ui.hud.GlyphKind
import co.nsgsolutions.spinola.ui.hud.Kicker
import co.nsgsolutions.spinola.ui.hud.RoundIconButton
import co.nsgsolutions.spinola.ui.hud.Stage
import co.nsgsolutions.spinola.ui.hud.StageScroll
import co.nsgsolutions.spinola.ui.hud.StickerText
import co.nsgsolutions.spinola.ui.hud.panel
import co.nsgsolutions.spinola.ui.theme.AppText
import co.nsgsolutions.spinola.ui.theme.Theme
import co.nsgsolutions.spinola.ui.theme.TypeScale

// Port of Views/AboutView.swift, with the online-play sections rewritten for a build that has none.

private const val SUPPORT = "noah@nsgsolutions.co"

/**
 * Play's User Data policy asks for a link to the policy inside the app. The full text is here too,
 * so this still works with no signal; the link is for anyone who wants the canonical copy.
 */
private const val POLICY_URL = "https://nsgnoah.github.io/ola/privacy.html"

/**
 * Privacy and support, in the app itself. Google Play's User Data policy wants the privacy policy
 * reachable inside the app, not only from the store listing, and the listing needs a way to reach
 * support. Both live here rather than behind a link, so they work with no network at all.
 *
 * Keep this in step with `docs/privacy-policy.md`; they are the same statement in two places.
 */
@Composable
fun AboutScreen(onClose: () -> Unit) {
    BackHandler { onClose() }
    val context = LocalContext.current
    val version = remember(context) { versionLabel(context) }

    Stage(background = { GameBackground(top = Theme.violet, bottom = Theme.violetDeep) }) {
        StageScroll {
            Column(
                Modifier.fillMaxWidth().padding(20.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
                horizontalAlignment = Alignment.Start,
            ) {
                Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                    Kicker("SPINOLA")
                    Spacer(Modifier.weight(1f))
                    RoundIconButton(GlyphKind.Close, contentDescription = "Close", onClick = onClose)
                }

                StickerText("PRIVACY\n& SUPPORT", size = TypeScale.title, align = TextAlign.Start, modifier = Modifier.testTag("about-screen"))

                Column(Modifier.fillMaxWidth().panel(padding = 16f), verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    Section(
                        "THE SHORT VERSION",
                        "Spinola has no accounts, no servers of ours, and no analytics. There is no service of ours for your data to go to, and we never receive it.",
                    )

                    Section(
                        "WHAT STAYS ON YOUR PHONE",
                        "Your profile, a first name and which world you know, and any pass-and-play matches are stored in the app on this phone. Clear them any time with Start over on the home screen, or by deleting the app.",
                    )

                    Section(
                        "ONLINE PLAY",
                        "This Android version plays on one phone only. You pass it across the couch, and nothing is sent anywhere.\n\nPlaying from two phones is iPhone-only today, through Apple's Game Center.",
                    )

                    Section(
                        "REMOVING A MATCH",
                        "Once a match has finished, a delete button appears beside it. That removes the match from this phone, and this phone is the only place it ever was.\n\nStart over is separate: it clears your profile and every match on this phone.",
                    )

                    Section(
                        "NOTHING ELSE LEAVES",
                        "No network requests at all. No advertising, no tracking, no third-party SDKs, and no device permissions: no contacts, no location, no photos, no microphone.",
                    )

                    Section(
                        "SUPPORT",
                        "Questions, bugs, or a wrong answer you want corrected: $SUPPORT",
                    )
                }

                ChunkyButton(
                    text = "Read this policy on the web",
                    onClick = { openPolicy(context) },
                    modifier = Modifier.testTag("policy-link"),
                    color = Color.White,
                    edge = Theme.panelEdge,
                    ink = Theme.ink,
                    height = 48f,
                    fontSize = 17f,
                )

                GameText(
                    "Version $version",
                    AppText.label(11f),
                    Color.White.copy(alpha = 0.7f),
                    Modifier.fillMaxWidth(),
                    align = TextAlign.Center,
                )
            }
        }
    }
}

@Composable
private fun Section(title: String, body: String) {
    Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(5.dp), horizontalAlignment = Alignment.Start) {
        Kicker(title, color = Theme.ink2, size = 11f)
        GameText(body, AppText.bodyRegular(14f), Theme.ink)
    }
}

/** The system browser, or whatever handles https. A phone with no browser at all just stays here. */
private fun openPolicy(context: Context) {
    try {
        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(POLICY_URL)))
    } catch (_: ActivityNotFoundException) {
        // The policy text is on this screen already.
    }
}

/** "1.0 (1)": the marketing version and the version code, as `CFBundleShortVersionString (CFBundleVersion)` on iOS. */
private fun versionLabel(context: Context): String {
    val info = try {
        context.packageManager.getPackageInfo(context.packageName, 0)
    } catch (_: PackageManager.NameNotFoundException) {
        null
    }
    val v = info?.versionName ?: "1.0"
    val b = info?.let { PackageInfoCompat.getLongVersionCode(it) } ?: 1L
    return "$v ($b)"
}
