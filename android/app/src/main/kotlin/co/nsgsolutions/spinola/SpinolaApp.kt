package co.nsgsolutions.spinola

import android.app.Application
import android.content.Context
import android.content.SharedPreferences
import co.nsgsolutions.spinola.audio.SoundKit
import co.nsgsolutions.spinola.model.Decks
import co.nsgsolutions.spinola.services.KeyValueStore
import co.nsgsolutions.spinola.services.LocalMatchStore
import co.nsgsolutions.spinola.services.ProfileStore

/**
 * The process-wide state, the Android half of `OlaBallApp.swift`: the question content, the two
 * stores, and the synthesized sounds. Screens reach the stores through the CompositionLocals in
 * `RootView.kt`; nothing else holds them.
 */
class SpinolaApp : Application() {
    /** Who you are on this phone. */
    lateinit var profiles: ProfileStore
        private set

    /** Pass-and-play matches. */
    lateinit var matches: LocalMatchStore
        private set

    private lateinit var prefs: KeyValueStore

    override fun onCreate() {
        super.onCreate()
        // 340 KB of JSON, parsed once, on the main thread on purpose: every screen needs the decks
        // and the first one composes as soon as this returns. A background parse would only buy a
        // frame of empty screen and a race.
        Decks.load(assets.open("decks.json").bufferedReader().use { it.readText() })
        prefs = PrefsStore(getSharedPreferences(PREFS_FILE, MODE_PRIVATE))
        loadStores()
        SoundKit.start()
    }

    /**
     * Re-reads both stores from SharedPreferences. Every change is saved the moment it happens, so
     * in normal use this is a no-op; it exists for the instrumented tests, which seed the
     * preferences AFTER the process (and so this Application) exists, then launch a fresh activity.
     * `MainActivity` calls it on a fresh launch only, never on a rotation.
     */
    fun reloadStores() = loadStores()

    private fun loadStores() {
        profiles = ProfileStore(prefs)
        matches = LocalMatchStore(prefs)
    }

    companion object {
        /** The one preferences file. The keys inside it are the iOS `UserDefaults` keys. */
        const val PREFS_FILE = "ola"

        fun of(context: Context): SpinolaApp = context.applicationContext as SpinolaApp
    }
}

/** [KeyValueStore] over SharedPreferences, the Android reading of `UserDefaults.standard`. */
class PrefsStore(private val prefs: SharedPreferences) : KeyValueStore {
    override fun getString(key: String): String? = prefs.getString(key, null)

    override fun putString(key: String, value: String?) {
        // apply(): the in-memory copy is updated at once, the disk write is queued, and Android
        // flushes the queue before the activity pauses, so a turn is never lost to a home press.
        val editor = prefs.edit()
        if (value == null) editor.remove(key) else editor.putString(key, value)
        editor.apply()
    }
}
