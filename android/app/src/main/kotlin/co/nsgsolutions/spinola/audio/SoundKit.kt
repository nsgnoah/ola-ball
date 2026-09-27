package co.nsgsolutions.spinola.audio

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Handler
import android.os.Looper
import co.nsgsolutions.spinola.support.SeededRNG
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/** Every sound is synthesized at launch. No audio files. Mirrors `Audio/SoundKit.swift`. */
enum class Sound { Tap, Tick, Correct, Wrong, Swoosh, Crown, Fanfare, Lose }

/**
 * Plays the synthesized cues. One static [AudioTrack] per [Sound]; playing a sound restarts it
 * (Swift's `.interrupts`) while different sounds overlap. The tracks mix with whatever else is
 * playing and never take audio focus, the Android reading of the iOS `.ambient` +
 * `.mixWithOthers` session.
 */
object SoundKit {
    @Volatile
    var isEnabled: Boolean = true

    private const val sampleRate = 44_100
    private val tracks = HashMap<Sound, AudioTrack>()
    private var started = false

    @Volatile
    private var ready = false

    /**
     * Call once from the activity on the main thread. Rendering and the track set-up happen on a
     * background thread; [play] is silent until they are done.
     */
    fun start() {
        if (started) return
        started = true
        val main = Handler(Looper.getMainLooper())
        val worker = Thread({
            // On iOS, a dead audio server aborts the process from inside CoreAudio, so the Swift
            // kit gives up on the first failure. Android is gentler (AudioTrack throws or comes
            // back uninitialised) but the policy is the same: a game with no sound is a small
            // loss; a game that dies on launch is a rejection. Every call is guarded in track().
            val built = HashMap<Sound, AudioTrack>()
            for ((sound, samples) in renderAll()) {
                track(samples)?.let { built[sound] = it }
            }
            main.post {
                if (built.isEmpty()) isEnabled = false
                tracks.putAll(built)
                ready = true
            }
        }, "spinola-synth")
        worker.isDaemon = true
        worker.start()
    }

    fun play(sound: Sound, volume: Float = 1f) {
        if (!isEnabled || !ready) return
        val track = tracks[sound] ?: return
        try {
            track.setVolume(volume.coerceIn(0f, 1f))
            track.stop()
            track.reloadStaticData()
            track.play()
        } catch (e: RuntimeException) {
            // IllegalStateException when the audio server restarted or the route was torn down
            // under us, or whatever else a vendor AudioTrack throws. Stay quiet; see start().
        }
    }

    /** Every sound rendered, with no Android in sight, so a JVM test can check the synth. */
    internal fun renderAll(): Map<Sound, FloatArray> = Sound.entries.associateWith { Synth.render(it) }

    /** A static, mono, float track holding [samples], or null when this device cannot give us one. */
    private fun track(samples: FloatArray): AudioTrack? {
        if (samples.isEmpty()) return null
        var track: AudioTrack? = null
        return try {
            track = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_GAME)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_FLOAT)
                        .setSampleRate(sampleRate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build(),
                )
                .setTransferMode(AudioTrack.MODE_STATIC)
                .setBufferSizeInBytes(samples.size * Float.SIZE_BYTES)
                // A hint only: the framework falls back to a normal track when it cannot honour it.
                .setPerformanceMode(AudioTrack.PERFORMANCE_MODE_LOW_LATENCY)
                .build()
            if (track.state == AudioTrack.STATE_UNINITIALIZED) {
                track.release()
                return null
            }
            val written = track.write(samples, 0, samples.size, AudioTrack.WRITE_BLOCKING)
            if (written != samples.size) {
                track.release()
                return null
            }
            track
        } catch (e: RuntimeException) {
            // UnsupportedOperationException (no output at all), IllegalArgumentException (a
            // format the device rejects) or IllegalStateException (a track that died mid-write).
            try {
                track?.release()
            } catch (ignored: RuntimeException) {
                // Already gone.
            }
            null
        }
    }
}

/**
 * The synthesizer: plain float math at 44.1 kHz, a straight port of `Synth` in Swift so both apps
 * sound the same. Nothing here touches Android.
 */
object Synth {
    const val sr: Float = 44_100f
    private val twoPi = (2 * PI).toFloat()

    fun frames(s: Float): Int = (s * sr).toInt()

    fun render(sound: Sound): FloatArray = when (sound) {
        Sound.Tap -> tap()
        Sound.Tick -> tick()
        Sound.Correct -> correct()
        Sound.Wrong -> wrong()
        Sound.Swoosh -> swoosh()
        Sound.Crown -> crown()
        Sound.Fanfare -> fanfare()
        Sound.Lose -> lose()
    }

    fun noise(n: Int, seed: ULong): FloatArray {
        val rng = SeededRNG(seed)
        return FloatArray(n) { 2f * closedUnit(rng) - 1f }
    }

    /** 2^24: the number of steps `Float.random` uses across a closed range (23 significand bits plus the hidden one). */
    private const val unitSteps = 16_777_216uL
    private const val unitStep = 1f / 16_777_216f

    /**
     * Swift's `Float.random(in: -1...1, using:)` before the `2 * u - 1` mapping. The standard
     * library draws a `UInt32` (the low 32 bits of the generator's 64-bit word), reduces it to
     * `0...2^24` with Lemire's nearly divisionless method, returns the upper bound itself on the
     * top step and otherwise scales by `ulpOfOne / 2`. Reproduced here so the noise in `tap` and
     * `swoosh` is the same signal as on iOS, not merely the same character.
     */
    private fun closedUnit(rng: SeededRNG): Float {
        val upperBound = unitSteps + 1uL
        var random = rng.next() and 0xFFFF_FFFFuL
        var product = random * upperBound
        var low = product and 0xFFFF_FFFFuL
        if (low < upperBound) {
            val threshold = ((1uL shl 32) - upperBound) % upperBound
            while (low < threshold) {
                random = rng.next() and 0xFFFF_FFFFuL
                product = random * upperBound
                low = product and 0xFFFF_FFFFuL
            }
        }
        val rand = product shr 32
        return if (rand == unitSteps) 1f else rand.toFloat() * unitStep
    }

    fun lowpass(x: FloatArray, cutoff: Float): FloatArray {
        val y = FloatArray(x.size)
        var s = 0f
        val a = 1f - exp(-twoPi * cutoff / sr)
        for (i in x.indices) {
            s += a * (x[i] - s)
            y[i] = s
        }
        return y
    }

    fun decay(n: Int, tau: Float): FloatArray = FloatArray(n) { i -> exp(-i.toFloat() / (tau * sr)) }

    fun envelope(n: Int, attack: Float, hold: Float, release: Float): FloatArray {
        val a = max(1, frames(attack))
        val h = frames(hold)
        val r = max(1, frames(release))
        return FloatArray(n) { i ->
            when {
                i < a -> i.toFloat() / a.toFloat()
                i < a + h -> 1f
                else -> {
                    val t = (i - a - h).toFloat() / r.toFloat()
                    if (t >= 1f) 0f else 1f - t
                }
            }
        }
    }

    fun tone(n: Int, harmonics: FloatArray = floatArrayOf(1f), frequency: (Int) -> Float): FloatArray {
        var phase = 0f
        return FloatArray(n) { i ->
            phase += twoPi * frequency(i) / sr
            var v = 0f
            for (k in harmonics.indices) v += harmonics[k] * sin(phase * (k + 1).toFloat())
            v
        }
    }

    fun mix(layers: List<FloatArray>): FloatArray {
        val n = layers.maxOfOrNull { it.size } ?: 0
        val out = FloatArray(n)
        for (l in layers) for (i in l.indices) out[i] += l[i]
        return out
    }

    fun mul(a: FloatArray, b: FloatArray): FloatArray = FloatArray(min(a.size, b.size)) { a[it] * b[it] }

    fun normalized(x: FloatArray, peak: Float = 0.8f): FloatArray {
        var m = if (x.isEmpty()) 1f else 0f
        for (v in x) m = max(m, abs(v))
        return if (m > 0f) FloatArray(x.size) { x[it] / m * peak } else x
    }

    fun delayed(x: FloatArray, by: Float, total: Int): FloatArray {
        val d = frames(by)
        val out = FloatArray(total)
        for (i in x.indices) if (i + d < total) out[i + d] = x[i]
        return out
    }

    private fun FloatArray.gain(g: Float): FloatArray = FloatArray(size) { this[it] * g }

    fun note(f: Float, length: Float, harmonics: FloatArray = floatArrayOf(1f, 0.4f, 0.15f), tau: Float = 0.18f): FloatArray {
        val n = frames(length)
        return mul(tone(n, harmonics) { f }, decay(n, tau))
    }

    fun tap(): FloatArray {
        val n = frames(0.04f)
        return normalized(mul(lowpass(noise(n, seed = 1uL), cutoff = 3800f), decay(n, tau = 0.005f)), peak = 0.4f)
    }

    fun tick(): FloatArray {
        val n = frames(0.05f)
        return normalized(mul(tone(n) { 1500f }, decay(n, tau = 0.006f)), peak = 0.35f)
    }

    /**
     * A soft-edged bell: a few ms of attack so it doesn't click, a slightly detuned twin for
     * warmth, and a fade to silence at the end instead of being chopped off mid-ring.
     */
    fun chime(f: Float, length: Float, tau: Float = 0.22f, gain: Float = 1f): FloatArray {
        val n = frames(length)
        val body = mix(
            listOf(
                tone(n, floatArrayOf(1f, 0.3f, 0.1f, 0.04f)) { f },
                tone(n, floatArrayOf(0.45f)) { f * 1.004f },
            ),
        )
        val env = mul(decay(n, tau), envelope(n, attack = 0.005f, hold = max(0f, length - 0.065f), release = 0.06f))
        return mul(body, env).gain(gain)
    }

    /** High, quiet twinkles on top of a win: the arcade "sparkle". */
    fun sparkle(notes: List<Float>, from: Float, gap: Float, total: Int): List<FloatArray> =
        notes.mapIndexed { i, f -> delayed(chime(f, length = 0.22f, tau = 0.07f, gain = 0.16f), by = from + i * gap, total = total) }

    fun correct(): FloatArray {
        // "ba-DING": a grace note up to a major chord, pitched mid-range so it lands bright, not shrill.
        val total = frames(0.75f)
        return normalized(
            mix(
                listOf(
                    delayed(chime(659f, length = 0.12f, tau = 0.06f, gain = 0.7f), by = 0f, total = total),
                    delayed(chime(784f, length = 0.6f, tau = 0.22f), by = 0.075f, total = total),
                    delayed(chime(988f, length = 0.55f, tau = 0.2f, gain = 0.4f), by = 0.075f, total = total),
                    delayed(chime(392f, length = 0.5f, tau = 0.2f, gain = 0.35f), by = 0.075f, total = total),
                ) + sparkle(listOf(1568f, 1976f, 2349f), from = 0.12f, gap = 0.045f, total = total),
            ),
            peak = 0.55f,
        )
    }

    fun wrong(): FloatArray {
        val n = frames(0.35f)
        val buzz = tone(n, floatArrayOf(1f, 0.5f, 0.3f, 0.2f)) { i -> 180f - i.toFloat() / n.toFloat() * 40f }
        return normalized(mul(lowpass(buzz, cutoff = 900f), envelope(n, attack = 0.005f, hold = 0.15f, release = 0.18f)), peak = 0.5f)
    }

    fun swoosh(): FloatArray {
        val n = frames(0.28f)
        var x = noise(n, seed = 3uL)
        x = lowpass(x, cutoff = 2500f)
        return normalized(mul(x, envelope(n, attack = 0.08f, hold = 0.02f, release = 0.17f)), peak = 0.35f)
    }

    fun crown(): FloatArray {
        // Quick run up the chord, then the whole chord rings out with twinkles.
        val total = frames(1.5f)
        val run = listOf(523f, 659f, 784f)
        return normalized(
            mix(
                run.mapIndexed { i, f -> delayed(chime(f, length = 0.2f, tau = 0.1f, gain = 0.8f), by = i * 0.085f, total = total) } +
                    listOf(
                        delayed(chime(1047f, length = 1.1f, tau = 0.35f), by = 0.255f, total = total),
                        delayed(chime(784f, length = 1.0f, tau = 0.3f, gain = 0.45f), by = 0.255f, total = total),
                        delayed(chime(659f, length = 1.0f, tau = 0.3f, gain = 0.4f), by = 0.255f, total = total),
                        delayed(chime(262f, length = 0.9f, tau = 0.3f, gain = 0.4f), by = 0.255f, total = total),
                    ) + sparkle(listOf(2093f, 2637f, 3136f, 2637f, 3136f), from = 0.32f, gap = 0.06f, total = total),
            ),
            peak = 0.6f,
        )
    }

    fun fanfare(): FloatArray {
        // Ta-ta-ta-TAAA on mellow brass, landing on a full chord with a little vibrato.
        val total = frames(2.0f)
        fun brass(f: Float, at: Float, len: Float, gain: Float = 1f): FloatArray {
            val n = frames(len)
            val raw = lowpass(
                tone(n, floatArrayOf(1f, 0.5f, 0.28f, 0.14f, 0.06f)) { i ->
                    val t = i.toFloat() / sr
                    f * (1f + 0.005f * sin(twoPi * 5.5f * t) * min(1f, max(0f, t - 0.2f) / 0.3f))
                },
                cutoff = 1900f,
            )
            return delayed(mul(raw, envelope(n, attack = 0.025f, hold = max(0f, len - 0.25f), release = 0.22f)).gain(gain), by = at, total = total)
        }
        val held = 1.3f
        return normalized(
            mix(
                listOf(
                    brass(392f, at = 0f, len = 0.15f), brass(523f, at = 0.13f, len = 0.15f), brass(659f, at = 0.26f, len = 0.15f),
                    brass(784f, at = 0.4f, len = held), brass(659f, at = 0.4f, len = held, gain = 0.5f),
                    brass(523f, at = 0.4f, len = held, gain = 0.5f), brass(262f, at = 0.4f, len = held, gain = 0.45f),
                ) + sparkle(listOf(2093f, 2637f, 3136f, 4186f), from = 0.45f, gap = 0.07f, total = total),
            ),
            peak = 0.65f,
        )
    }

    fun lose(): FloatArray {
        val total = frames(1.0f)
        return normalized(
            mix(
                listOf(
                    delayed(note(392f, length = 0.4f, tau = 0.25f), by = 0f, total = total),
                    delayed(note(330f, length = 0.6f, tau = 0.3f), by = 0.3f, total = total),
                ),
            ),
            peak = 0.5f,
        )
    }
}
