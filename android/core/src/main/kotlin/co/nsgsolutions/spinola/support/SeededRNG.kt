package co.nsgsolutions.spinola.support

/**
 * Deterministic generator (SplitMix64) so tests and replays are reproducible, and so both phones
 * draw the same questions from the same seed. Bit-for-bit the same stream as `SeededRNG.swift`.
 */
class SeededRNG(seed: ULong) {
    private var state: ULong = seed

    fun next(): ULong {
        state += 0x9E3779B97F4A7C15uL
        var z = state
        z = (z xor (z shr 30)) * 0xBF58476D1CE4E5B9uL
        z = (z xor (z shr 27)) * 0x94D049BB133111EBuL
        return z xor (z shr 31)
    }

    /**
     * Swift's `Int.random(in: 0..<upperBound, using: &rng)`: Lemire's nearly divisionless method
     * as implemented by `RandomNumberGenerator.next(upperBound:)` in the Swift standard library.
     * Returns the high 64 bits of `random * upperBound`, redrawing on the rare biased low words.
     */
    fun nextInt(upperBound: Int): Int {
        require(upperBound > 0) { "upperBound must be positive" }
        val bound = upperBound.toULong()
        var random = next()
        var low = random * bound
        var high = mulHigh(random, bound)
        if (low < bound) {
            val t = (0uL - bound) % bound
            while (low < t) {
                random = next()
                low = random * bound
                high = mulHigh(random, bound)
            }
        }
        return high.toInt()
    }

    private companion object {
        /** High 64 bits of the unsigned 128-bit product, without `Math.multiplyHigh` (API 33+ only). */
        fun mulHigh(a: ULong, b: ULong): ULong {
            val mask = 0xFFFFFFFFuL
            val aLo = a and mask
            val aHi = a shr 32
            val bLo = b and mask
            val bHi = b shr 32
            val loLo = aLo * bLo
            val hiLo = aHi * bLo
            val loHi = aLo * bHi
            val hiHi = aHi * bHi
            val mid = (loLo shr 32) + (hiLo and mask) + (loHi and mask)
            return hiHi + (hiLo shr 32) + (loHi shr 32) + (mid shr 32)
        }
    }
}

/**
 * Swift's `MutableCollection.shuffle(using:)`: a forward Fisher–Yates that swaps position `i` with
 * `i + random(0 ..< remaining)`. The order of draws matters, so it is spelled out rather than
 * delegated to `java.util.Collections.shuffle`.
 */
fun <T> List<T>.shuffled(rng: SeededRNG): List<T> {
    val out = toMutableList()
    var amount = out.size
    var current = 0
    while (amount > 1) {
        val random = rng.nextInt(amount)
        amount -= 1
        val j = current + random
        val tmp = out[current]
        out[current] = out[j]
        out[j] = tmp
        current += 1
    }
    return out
}

/**
 * FNV-1a over the UTF-8 bytes, as the `Int` bit pattern of the 64-bit hash. Deterministic across
 * launches and devices, unlike `hashCode`, and identical to `String.stableHash` on iOS.
 */
val String.stableHash: Long
    get() {
        var h = 1469598103934665603uL
        for (b in encodeToByteArray()) {
            h = (h xor (b.toInt() and 0xFF).toULong()) * 1099511628211uL
        }
        return h.toLong()
    }
