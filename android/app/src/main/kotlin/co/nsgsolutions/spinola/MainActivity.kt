package co.nsgsolutions.spinola

import android.content.pm.ActivityInfo
import android.database.ContentObserver
import android.graphics.Color
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.SystemBarStyle
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.Density
import co.nsgsolutions.spinola.audio.Haptics
import co.nsgsolutions.spinola.audio.SoundKit
import co.nsgsolutions.spinola.ui.theme.LocalReduceMotion
import co.nsgsolutions.spinola.ui.theme.Viewport
import co.nsgsolutions.spinola.ui.theme.reduceMotionEnabled
import kotlin.math.min

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Light status and navigation icons, always. Every screen is a dark stage (iOS forces
        // `.preferredColorScheme(.dark)`), but the default style follows the phone's theme and would
        // draw a near-black clock on the violet backdrop whenever the phone is in light mode.
        enableEdgeToEdge(
            statusBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
            navigationBarStyle = SystemBarStyle.dark(Color.TRANSPARENT),
        )
        // Portrait on phones, any orientation on tablets: the same rule as the iOS build.
        val isTablet = resources.configuration.smallestScreenWidthDp >= 600
        requestedOrientation = if (isTablet) ActivityInfo.SCREEN_ORIENTATION_UNSPECIFIED else ActivityInfo.SCREEN_ORIENTATION_PORTRAIT
        Viewport.seed(isTablet)
        // A fresh launch re-reads the stores (see SpinolaApp.reloadStores); a rotation keeps them,
        // because a match in progress is talking to the instances it already has.
        if (savedInstanceState == null) SpinolaApp.of(this).reloadStores()
        Haptics.attach(window.decorView)
        SoundKit.start()
        setContent {
            SpinolaRoot { RootView() }
        }
    }
}

/**
 * The window-level wrapper every screen sits inside. It measures the window for [Viewport] (HERE
 * and nowhere else, so a sheet can never shrink the whole app), caps the text-size setting the way
 * iOS caps Dynamic Type at xxLarge, and publishes the reduce-motion preference.
 */
@Composable
fun SpinolaRoot(content: @Composable () -> Unit) {
    val context = LocalContext.current
    val density = LocalDensity.current
    val capped = remember(density) { Density(density.density, min(density.fontScale, 1.5f)) }
    // Followed live, like `@Environment(\.accessibilityReduceMotion)`: "Remove animations" is not a
    // configuration change, so nothing would otherwise re-read it until the process restarts.
    var reduceMotion by remember { mutableStateOf(reduceMotionEnabled(context)) }
    DisposableEffect(context) {
        val observer = object : ContentObserver(Handler(Looper.getMainLooper())) {
            override fun onChange(selfChange: Boolean) {
                reduceMotion = reduceMotionEnabled(context)
            }
        }
        val uri = Settings.Global.getUriFor(Settings.Global.ANIMATOR_DURATION_SCALE)
        context.contentResolver.registerContentObserver(uri, false, observer)
        onDispose { context.contentResolver.unregisterContentObserver(observer) }
    }
    BoxWithConstraints(Modifier.fillMaxSize()) {
        val w = maxWidth.value
        val h = maxHeight.value
        LaunchedEffect(w, h) { Viewport.fit(w, h) }
        CompositionLocalProvider(LocalDensity provides capped, LocalReduceMotion provides reduceMotion) {
            content()
        }
    }
}
