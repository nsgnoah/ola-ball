package co.nsgsolutions.spinola

import co.nsgsolutions.spinola.audio.Sound
import co.nsgsolutions.spinola.audio.SoundKit
import co.nsgsolutions.spinola.audio.Synth
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs
import kotlin.math.max

/** The synth runs on the JVM with no Android: every cue renders, stays in range and is finite. */
class SynthTest {
    @Test
    fun everySoundRendersCleanly() {
        val all = SoundKit.renderAll()
        assertEquals(Sound.entries.toSet(), all.keys)
        for ((sound, samples) in all) {
            assertTrue("$sound is empty", samples.isNotEmpty())
            var peak = 0f
            for (v in samples) {
                assertFalse("$sound has NaN", v.isNaN())
                assertFalse("$sound is infinite", v.isInfinite())
                peak = max(peak, abs(v))
            }
            assertTrue("$sound peaks at $peak", peak <= 0.8f)
            assertTrue("$sound is silent", peak > 0.1f)
        }
    }

    @Test
    fun lengthsMatchTheSwiftRenders() {
        // frames(seconds) truncates like Swift's Int(s * sr).
        assertEquals(1_764, Synth.render(Sound.Tap).size)
        assertEquals(2_205, Synth.render(Sound.Tick).size)
        assertEquals(33_075, Synth.render(Sound.Correct).size)
        assertEquals(15_435, Synth.render(Sound.Wrong).size)
        assertEquals(12_348, Synth.render(Sound.Swoosh).size)
        assertEquals(66_150, Synth.render(Sound.Crown).size)
        assertEquals(88_200, Synth.render(Sound.Fanfare).size)
        assertEquals(44_100, Synth.render(Sound.Lose).size)
    }

    @Test
    fun noiseIsDeterministicAndSpansTheClosedRange() {
        val a = Synth.noise(4_096, seed = 1uL)
        val b = Synth.noise(4_096, seed = 1uL)
        assertArrayEquals(a, b, 0f)
        assertFalse(a.contentEquals(Synth.noise(4_096, seed = 3uL)))
        var lo = 1f
        var hi = -1f
        var sum = 0.0
        for (v in a) {
            assertTrue("$v out of -1...1", v >= -1f && v <= 1f)
            lo = minOf(lo, v)
            hi = maxOf(hi, v)
            sum += v
        }
        assertTrue("noise never goes low: $lo", lo < -0.95f)
        assertTrue("noise never goes high: $hi", hi > 0.95f)
        assertTrue("noise is biased: ${sum / a.size}", abs(sum / a.size) < 0.05)
    }

    @Test
    fun envelopeRampsHoldsAndReleases() {
        val n = Synth.frames(0.1f)
        val env = Synth.envelope(n, attack = 0.01f, hold = 0.02f, release = 0.03f)
        assertEquals(0f, env[0], 0f)
        assertEquals(1f, env[Synth.frames(0.015f)], 0f)
        assertEquals(0f, env[n - 1], 0f)
        assertTrue(env[Synth.frames(0.04f)] in 0.1f..0.9f)
    }
}
