package co.nsgsolutions.spinola

import co.nsgsolutions.spinola.support.SeededRNG
import co.nsgsolutions.spinola.support.shuffled
import co.nsgsolutions.spinola.support.stableHash
import org.junit.Assert.assertEquals
import org.junit.Test

/** `SeededRNG`, `nextInt`, `shuffled` and `stableHash` against the streams Swift wrote. */
class GoldenSupportTests {
    private val golden = Fixtures.engine

    @Test
    fun splitMix64StreamsMatchSwift() {
        for (stream in golden.rng) {
            val rng = SeededRNG(stream.seed)
            val values = List(stream.values.size) { rng.next() }
            assertEquals("seed ${stream.seed}", stream.values, values)
        }
    }

    @Test
    fun stableHashMatchesSwift() {
        for (h in golden.hashes) {
            assertEquals("stableHash(\"${h.string}\")", h.hash, h.string.stableHash)
        }
    }

    @Test
    fun boundedDrawsMatchSwiftIntRandom() {
        for (b in golden.bounded) {
            val rng = SeededRNG(b.seed)
            val values = List(b.values.size) { rng.nextInt(b.upperBound) }
            assertEquals("seed ${b.seed} bound ${b.upperBound}", b.values, values)
        }
    }

    @Test
    fun shufflesMatchSwiftShuffled() {
        for (s in golden.shuffles) {
            val rng = SeededRNG(s.seed)
            assertEquals("seed ${s.seed} count ${s.count}", s.order, (0 until s.count).toList().shuffled(rng))
        }
    }
}
