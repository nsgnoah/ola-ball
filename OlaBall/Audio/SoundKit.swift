import AVFoundation

/// Every sound is synthesized at launch. No audio files.
enum Sound: CaseIterable { case tap, tick, correct, wrong, swoosh, crown, fanfare, lose }

final class SoundKit {
    static let shared = SoundKit()
    var isEnabled = true

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var buffers: [Sound: AVAudioPCMBuffer] = [:]
    private var players: [AVAudioPlayerNode] = []
    private var next = 0
    private var started = false
    private var ready = false

    private init() {}

    func start() {
        guard !started else { return }
        started = true

        // If the session will not activate, the audio server is not answering. Touching
        // AVAudioEngine after that can abort the process from inside CoreAudio (an RPC timeout
        // calls abort(), which no Swift error handling can catch), so give up and run silently.
        // A game with no sound is a small loss; a game that dies on launch is a rejection.
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            isEnabled = false
            return
        }

        for _ in 0..<6 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        let format = self.format
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var rendered: [Sound: AVAudioPCMBuffer] = [:]
            for s in Sound.allCases { rendered[s] = Synth.buffer(Synth.render(s), format: format) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.buffers = rendered
                do { try self.engine.start() } catch { return }
                for p in self.players { p.play() }
                self.ready = true
            }
        }
    }

    func play(_ sound: Sound, volume: Float = 1) {
        guard isEnabled, ready, engine.isRunning, let b = buffers[sound] else { return }
        let p = players[next]
        next = (next + 1) % players.count
        p.volume = volume
        p.scheduleBuffer(b, at: nil, options: [.interrupts])
        if !p.isPlaying { p.play() }
    }
}

enum Synth {
    static let sr: Float = 44_100
    static func frames(_ s: Float) -> Int { Int(s * sr) }

    static func render(_ sound: Sound) -> [Float] {
        switch sound {
        case .tap: return tap()
        case .tick: return tick()
        case .correct: return correct()
        case .wrong: return wrong()
        case .swoosh: return swoosh()
        case .crown: return crown()
        case .fanfare: return fanfare()
        case .lose: return lose()
        }
    }

    static func buffer(_ samples: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer {
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buf.frameLength = AVAudioFrameCount(samples.count)
        for i in 0..<samples.count { buf.floatChannelData![0][i] = samples[i] }
        return buf
    }

    static func noise(_ n: Int, seed: UInt64) -> [Float] {
        var rng = SeededRNG(seed: seed)
        return (0..<n).map { _ in Float.random(in: -1...1, using: &rng) }
    }

    static func lowpass(_ x: [Float], cutoff: Float) -> [Float] {
        var y = [Float](repeating: 0, count: x.count); var s: Float = 0
        let a = 1 - exp(-2 * Float.pi * cutoff / sr)
        for i in 0..<x.count { s += a * (x[i] - s); y[i] = s }
        return y
    }

    static func decay(_ n: Int, tau: Float) -> [Float] { (0..<n).map { exp(-Float($0) / (tau * sr)) } }

    static func envelope(_ n: Int, attack: Float, hold: Float, release: Float) -> [Float] {
        let a = max(1, frames(attack)), h = frames(hold), r = max(1, frames(release))
        return (0..<n).map { i in
            if i < a { return Float(i) / Float(a) }
            if i < a + h { return 1 }
            let t = Float(i - a - h) / Float(r)
            return t >= 1 ? 0 : 1 - t
        }
    }

    static func tone(_ n: Int, frequency: (Int) -> Float, harmonics: [Float] = [1]) -> [Float] {
        var phase: Float = 0
        return (0..<n).map { i in
            phase += 2 * Float.pi * frequency(i) / sr
            var v: Float = 0
            for (k, amp) in harmonics.enumerated() { v += amp * sin(phase * Float(k + 1)) }
            return v
        }
    }

    static func mix(_ layers: [[Float]]) -> [Float] {
        let n = layers.map(\.count).max() ?? 0
        var out = [Float](repeating: 0, count: n)
        for l in layers { for i in 0..<l.count { out[i] += l[i] } }
        return out
    }

    static func mul(_ a: [Float], _ b: [Float]) -> [Float] { zip(a, b).map { $0 * $1 } }

    static func normalized(_ x: [Float], peak: Float = 0.8) -> [Float] {
        let m = x.map { abs($0) }.max() ?? 1
        return m > 0 ? x.map { $0 / m * peak } : x
    }

    static func delayed(_ x: [Float], by s: Float, total: Int) -> [Float] {
        let d = frames(s); var out = [Float](repeating: 0, count: total)
        for i in 0..<x.count where i + d < total { out[i + d] = x[i] }
        return out
    }

    static func note(_ f: Float, length: Float, harmonics: [Float] = [1, 0.4, 0.15], tau: Float = 0.18) -> [Float] {
        let n = frames(length)
        return mul(tone(n, frequency: { _ in f }, harmonics: harmonics), decay(n, tau: tau))
    }

    static func tap() -> [Float] {
        let n = frames(0.04)
        return normalized(mul(lowpass(noise(n, seed: 1), cutoff: 3800), decay(n, tau: 0.005)), peak: 0.4)
    }

    static func tick() -> [Float] {
        let n = frames(0.05)
        return normalized(mul(tone(n, frequency: { _ in 1500 }), decay(n, tau: 0.006)), peak: 0.35)
    }

    /// A soft-edged bell: a few ms of attack so it doesn't click, a slightly detuned twin for
    /// warmth, and a fade to silence at the end instead of being chopped off mid-ring.
    static func chime(_ f: Float, length: Float, tau: Float = 0.22, gain: Float = 1) -> [Float] {
        let n = frames(length)
        let body = mix([tone(n, frequency: { _ in f }, harmonics: [1, 0.3, 0.1, 0.04]), tone(n, frequency: { _ in f * 1.004 }, harmonics: [0.45])])
        let env = mul(decay(n, tau: tau), envelope(n, attack: 0.005, hold: max(0, length - 0.065), release: 0.06))
        return mul(body, env).map { $0 * gain }
    }

    /// High, quiet twinkles on top of a win: the arcade "sparkle".
    static func sparkle(_ notes: [Float], from: Float, gap: Float, total: Int) -> [[Float]] {
        notes.enumerated().map { i, f in delayed(chime(f, length: 0.22, tau: 0.07, gain: 0.16), by: from + Float(i) * gap, total: total) }
    }

    static func correct() -> [Float] {
        // "ba-DING": a grace note up to a major chord, pitched mid-range so it lands bright, not shrill.
        let total = frames(0.75)
        return normalized(mix([
            delayed(chime(659, length: 0.12, tau: 0.06, gain: 0.7), by: 0, total: total),
            delayed(chime(784, length: 0.6, tau: 0.22), by: 0.075, total: total),
            delayed(chime(988, length: 0.55, tau: 0.2, gain: 0.4), by: 0.075, total: total),
            delayed(chime(392, length: 0.5, tau: 0.2, gain: 0.35), by: 0.075, total: total),
        ] + sparkle([1568, 1976, 2349], from: 0.12, gap: 0.045, total: total)), peak: 0.55)
    }

    static func wrong() -> [Float] {
        let n = frames(0.35)
        let buzz = tone(n, frequency: { i in 180 - Float(i) / Float(n) * 40 }, harmonics: [1, 0.5, 0.3, 0.2])
        return normalized(mul(lowpass(buzz, cutoff: 900), envelope(n, attack: 0.005, hold: 0.15, release: 0.18)), peak: 0.5)
    }

    static func swoosh() -> [Float] {
        let n = frames(0.28)
        var x = noise(n, seed: 3)
        x = lowpass(x, cutoff: 2500)
        return normalized(mul(x, envelope(n, attack: 0.08, hold: 0.02, release: 0.17)), peak: 0.35)
    }

    static func crown() -> [Float] {
        // Quick run up the chord, then the whole chord rings out with twinkles.
        let total = frames(1.5)
        let run: [Float] = [523, 659, 784]
        return normalized(mix(
            run.enumerated().map { i, f in delayed(chime(f, length: 0.2, tau: 0.1, gain: 0.8), by: Float(i) * 0.085, total: total) } + [
                delayed(chime(1047, length: 1.1, tau: 0.35), by: 0.255, total: total),
                delayed(chime(784, length: 1.0, tau: 0.3, gain: 0.45), by: 0.255, total: total),
                delayed(chime(659, length: 1.0, tau: 0.3, gain: 0.4), by: 0.255, total: total),
                delayed(chime(262, length: 0.9, tau: 0.3, gain: 0.4), by: 0.255, total: total),
            ] + sparkle([2093, 2637, 3136, 2637, 3136], from: 0.32, gap: 0.06, total: total)
        ), peak: 0.6)
    }

    static func fanfare() -> [Float] {
        // Ta-ta-ta-TAAA on mellow brass, landing on a full chord with a little vibrato.
        let total = frames(2.0)
        func brass(_ f: Float, at: Float, len: Float, gain: Float = 1) -> [Float] {
            let n = frames(len)
            let raw = lowpass(tone(n, frequency: { i in
                let t = Float(i) / sr
                return f * (1 + 0.005 * sin(2 * Float.pi * 5.5 * t) * min(1, max(0, t - 0.2) / 0.3))
            }, harmonics: [1, 0.5, 0.28, 0.14, 0.06]), cutoff: 1900)
            return delayed(mul(raw, envelope(n, attack: 0.025, hold: max(0, len - 0.25), release: 0.22)).map { $0 * gain }, by: at, total: total)
        }
        let held: Float = 1.3
        return normalized(mix([
            brass(392, at: 0, len: 0.15), brass(523, at: 0.13, len: 0.15), brass(659, at: 0.26, len: 0.15),
            brass(784, at: 0.4, len: held), brass(659, at: 0.4, len: held, gain: 0.5),
            brass(523, at: 0.4, len: held, gain: 0.5), brass(262, at: 0.4, len: held, gain: 0.45),
        ] + sparkle([2093, 2637, 3136, 4186], from: 0.45, gap: 0.07, total: total)), peak: 0.65)
    }

    static func lose() -> [Float] {
        let total = frames(1.0)
        return normalized(mix([delayed(note(392, length: 0.4, tau: 0.25), by: 0, total: total), delayed(note(330, length: 0.6, tau: 0.3), by: 0.3, total: total)]), peak: 0.5)
    }
}
