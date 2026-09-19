import AVFoundation

/// Every sound in the game is synthesized at launch. No audio files, nothing downloaded.
enum Sound: CaseIterable {
    case tap, snap, whistle, thud, bigHit, catchBall, kick, incomplete, firstDown, touchdown, cheer, groan, stinger
}

final class SoundKit {
    static let shared = SoundKit()

    var isEnabled = true

    private let engine = AVAudioEngine()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var buffers: [Sound: AVAudioPCMBuffer] = [:]
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private let crowdNode = AVAudioPlayerNode()
    private var started = false
    private var ready = false

    /// Crowd bed: a base level for the current scene plus a decaying excitement term.
    private(set) var crowdBase: Float = 0
    private var excitement: Float = 0

    private init() {}

    func start() {
        guard !started else { return }
        started = true
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Sound is a nicety; the game plays fine silent.
        }
        for _ in 0..<8 {
            let p = AVAudioPlayerNode()
            engine.attach(p)
            engine.connect(p, to: engine.mainMixerNode, format: format)
            players.append(p)
        }
        engine.attach(crowdNode)
        engine.connect(crowdNode, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.9

        let format = self.format
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let rendered = Synth.renderAll(format: format)
            let crowd = Synth.crowdLoop(format: format)
            DispatchQueue.main.async {
                guard let self else { return }
                self.buffers = rendered
                do { try self.engine.start() } catch { return }
                for p in self.players { p.play() }
                self.crowdNode.volume = 0
                self.crowdNode.scheduleBuffer(crowd, at: nil, options: [.loops])
                self.crowdNode.play()
                self.ready = true
            }
        }
    }

    func play(_ sound: Sound, volume: Float = 1) {
        guard isEnabled, ready, engine.isRunning, let buffer = buffers[sound] else { return }
        let p = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        p.volume = volume
        p.scheduleBuffer(buffer, at: nil, options: [.interrupts])
        if !p.isPlaying { p.play() }
    }

    func setScene(crowd level: Float) {
        crowdBase = level
        applyCrowd()
    }

    /// Bump the crowd; it settles back over a couple of seconds.
    func excite(_ amount: Float) {
        excitement = min(0.6, excitement + amount)
        applyCrowd()
    }

    /// Call once per frame from whoever owns the clock.
    func update(dt: Float) {
        guard excitement > 0.001 else { return }
        excitement *= exp(-dt / 1.6)
        applyCrowd()
    }

    private func applyCrowd() {
        guard ready else { return }
        crowdNode.volume = isEnabled ? min(0.9, crowdBase + excitement) : 0
    }
}

// MARK: - Synthesis

enum Synth {
    static let sr: Float = 44_100

    static func renderAll(format: AVAudioFormat) -> [Sound: AVAudioPCMBuffer] {
        var out: [Sound: AVAudioPCMBuffer] = [:]
        for s in Sound.allCases {
            out[s] = buffer(render(s), format: format)
        }
        return out
    }

    static func render(_ sound: Sound) -> [Float] {
        switch sound {
        case .tap: return tap()
        case .snap: return snap()
        case .whistle: return whistle()
        case .thud: return thud(big: false)
        case .bigHit: return thud(big: true)
        case .catchBall: return catchBall()
        case .kick: return kick()
        case .incomplete: return groan(duration: 1.1, depth: 0.7)
        case .firstDown: return chime()
        case .touchdown: return fanfare()
        case .cheer: return cheer()
        case .groan: return groan(duration: 1.9, depth: 1.0)
        case .stinger: return stinger()
        }
    }

    // MARK: Building blocks

    static func buffer(_ samples: [Float], format: AVAudioFormat) -> AVAudioPCMBuffer {
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buf.frameLength = AVAudioFrameCount(samples.count)
        let ptr = buf.floatChannelData![0]
        for i in 0..<samples.count { ptr[i] = samples[i] }
        return buf
    }

    static func frames(_ seconds: Float) -> Int { Int(seconds * sr) }

    static func noise(_ n: Int, seed: UInt64) -> [Float] {
        var rng = SeededRNG(seed: seed)
        return (0..<n).map { _ in Float.random(in: -1...1, using: &rng) }
    }

    /// One-pole low-pass with a per-sample cutoff.
    static func lowpass(_ x: [Float], cutoff: (Int) -> Float) -> [Float] {
        var y = [Float](repeating: 0, count: x.count)
        var state: Float = 0
        for i in 0..<x.count {
            let a = 1 - exp(-2 * Float.pi * cutoff(i) / sr)
            state += a * (x[i] - state)
            y[i] = state
        }
        return y
    }

    static func lowpass(_ x: [Float], cutoff: Float) -> [Float] { lowpass(x) { _ in cutoff } }

    static func highpass(_ x: [Float], cutoff: Float) -> [Float] {
        let lp = lowpass(x, cutoff: cutoff)
        return zip(x, lp).map { $0 - $1 }
    }

    /// Attack / decay envelope in seconds, with an optional hold.
    static func envelope(_ n: Int, attack: Float, hold: Float = 0, release: Float, curve: Float = 1) -> [Float] {
        let a = max(1, frames(attack)), h = frames(hold), r = max(1, frames(release))
        return (0..<n).map { i in
            if i < a { return pow(Float(i) / Float(a), curve) }
            if i < a + h { return 1 }
            let t = Float(i - a - h) / Float(r)
            return t >= 1 ? 0 : pow(1 - t, curve)
        }
    }

    static func exponentialDecay(_ n: Int, tau: Float) -> [Float] {
        (0..<n).map { exp(-Float($0) / (tau * sr)) }
    }

    static func tone(_ n: Int, frequency: (Int) -> Float, harmonics: [Float] = [1]) -> [Float] {
        var phase: Float = 0
        var out = [Float](repeating: 0, count: n)
        for i in 0..<n {
            phase += 2 * Float.pi * frequency(i) / sr
            var v: Float = 0
            for (k, amp) in harmonics.enumerated() where amp != 0 {
                v += amp * sin(phase * Float(k + 1))
            }
            out[i] = v
        }
        return out
    }

    static func mix(_ layers: [[Float]]) -> [Float] {
        let n = layers.map(\.count).max() ?? 0
        var out = [Float](repeating: 0, count: n)
        for layer in layers { for i in 0..<layer.count { out[i] += layer[i] } }
        return out
    }

    static func multiply(_ a: [Float], _ b: [Float]) -> [Float] { zip(a, b).map { $0 * $1 } }

    static func normalized(_ x: [Float], peak: Float = 0.85) -> [Float] {
        let m = x.map { abs($0) }.max() ?? 1
        guard m > 0 else { return x }
        return x.map { $0 / m * peak }
    }

    static func delayed(_ x: [Float], by seconds: Float, total: Int) -> [Float] {
        let d = frames(seconds)
        var out = [Float](repeating: 0, count: total)
        for i in 0..<x.count where i + d < total { out[i + d] = x[i] }
        return out
    }

    // MARK: Sounds

    static func tap() -> [Float] {
        let n = frames(0.05)
        let click = multiply(tone(n, frequency: { _ in 1900 }), exponentialDecay(n, tau: 0.006))
        let body = multiply(lowpass(noise(n, seed: 1), cutoff: 4000), exponentialDecay(n, tau: 0.004))
        return normalized(mix([click, body.map { $0 * 0.6 }]), peak: 0.5)
    }

    static func snap() -> [Float] {
        let n = frames(0.09)
        let hit = multiply(lowpass(noise(n, seed: 2), cutoff: 2600), exponentialDecay(n, tau: 0.018))
        let slap = multiply(tone(n, frequency: { i in 420 - Float(i) / Float(n) * 250 }), exponentialDecay(n, tau: 0.02))
        return normalized(mix([hit, slap.map { $0 * 0.5 }]), peak: 0.7)
    }

    static func whistle() -> [Float] {
        let n = frames(0.5)
        let f: (Int) -> Float = { i in
            let t = Float(i) / sr
            return 2350 + 35 * sin(2 * Float.pi * 6 * t)
        }
        var x = tone(n, frequency: f, harmonics: [1, 0.25, 0.08])
        // Pea rattle: fast amplitude warble
        for i in 0..<n {
            let t = Float(i) / sr
            x[i] *= 0.65 + 0.35 * sin(2 * Float.pi * 38 * t)
        }
        let env = envelope(n, attack: 0.012, hold: 0.32, release: 0.12, curve: 1.5)
        return normalized(multiply(x, env), peak: 0.6)
    }

    static func thud(big: Bool) -> [Float] {
        let n = frames(big ? 0.42 : 0.3)
        let sweep = tone(n, frequency: { i in
            let t = Float(i) / sr
            return max(38, (big ? 170 : 140) * exp(-t / 0.09))
        })
        let body = multiply(sweep, exponentialDecay(n, tau: big ? 0.12 : 0.08))
        let crack = multiply(lowpass(noise(n, seed: 3), cutoff: big ? 1400 : 900), exponentialDecay(n, tau: big ? 0.05 : 0.035))
        return normalized(mix([body, crack.map { $0 * (big ? 0.9 : 0.6) }]), peak: 0.9)
    }

    static func catchBall() -> [Float] {
        let n = frames(0.08)
        let band = highpass(lowpass(noise(n, seed: 4), cutoff: 2400), cutoff: 500)
        return normalized(multiply(band, exponentialDecay(n, tau: 0.014)), peak: 0.55)
    }

    static func kick() -> [Float] {
        let n = frames(0.28)
        let boom = multiply(tone(n, frequency: { i in max(45, 190 * exp(-Float(i) / sr / 0.07)) }), exponentialDecay(n, tau: 0.07))
        let leather = multiply(lowpass(noise(n, seed: 5), cutoff: 1800), exponentialDecay(n, tau: 0.03))
        return normalized(mix([boom, leather.map { $0 * 0.7 }]), peak: 0.85)
    }

    static func chime() -> [Float] {
        let n = frames(0.9)
        func note(_ f: Float, at: Float) -> [Float] {
            let len = frames(0.7)
            let x = multiply(tone(len, frequency: { _ in f }, harmonics: [1, 0.45, 0.2, 0.1]), exponentialDecay(len, tau: 0.22))
            return delayed(x, by: at, total: n)
        }
        return normalized(mix([note(659.3, at: 0), note(987.8, at: 0.13)]), peak: 0.6)
    }

    static func fanfare() -> [Float] {
        let n = frames(1.7)
        func brass(_ f: Float, at: Float, length: Float) -> [Float] {
            let len = frames(length)
            let raw = tone(len, frequency: { i in f * (1 + 0.004 * sin(2 * Float.pi * 5.5 * Float(i) / sr)) },
                           harmonics: [1, 0.7, 0.55, 0.4, 0.3, 0.22, 0.15])
            let shaped = lowpass(raw, cutoff: 2600)
            let env = envelope(len, attack: 0.02, hold: max(0, length - 0.22), release: 0.2, curve: 1.2)
            return delayed(multiply(shaped, env), by: at, total: n)
        }
        let notes = mix([
            brass(523.3, at: 0.0, length: 0.16),
            brass(659.3, at: 0.14, length: 0.16),
            brass(784.0, at: 0.28, length: 0.16),
            brass(1046.5, at: 0.42, length: 1.1),
            brass(523.3, at: 0.42, length: 1.1).map { $0 * 0.6 },
        ])
        return normalized(notes, peak: 0.7)
    }

    static func cheer() -> [Float] {
        let n = frames(3.2)
        let bed = lowpass(noise(n, seed: 6), cutoff: { i in 1800 + 900 * sin(Float(i) / sr * 2.1) })
        let bright = highpass(lowpass(noise(n, seed: 7), cutoff: 6000), cutoff: 2200).map { $0 * 0.35 }
        let env = envelope(n, attack: 0.28, hold: 1.4, release: 1.5, curve: 1.3)
        var x = multiply(mix([bed, bright]), env)
        for i in 0..<n {
            let t = Float(i) / sr
            x[i] *= 0.85 + 0.15 * sin(2 * Float.pi * 0.9 * t) * sin(2 * Float.pi * 3.3 * t)
        }
        return normalized(x, peak: 0.75)
    }

    static func groan(duration: Float, depth: Float) -> [Float] {
        let n = frames(duration)
        let bed = lowpass(noise(n, seed: 8), cutoff: { i in max(250, 1100 - 700 * depth * Float(i) / Float(n)) })
        let env = envelope(n, attack: 0.12, hold: 0.15, release: duration - 0.3, curve: 1.6)
        return normalized(multiply(bed, env), peak: 0.55)
    }

    /// Two-note PA hit for kickoff.
    static func stinger() -> [Float] {
        let n = frames(0.9)
        func hit(_ f: Float, at: Float, length: Float) -> [Float] {
            let len = frames(length)
            let raw = lowpass(tone(len, frequency: { _ in f }, harmonics: [1, 0.6, 0.45, 0.3, 0.2]), cutoff: 2200)
            let env = envelope(len, attack: 0.01, hold: length - 0.25, release: 0.22)
            return delayed(multiply(raw, env), by: at, total: n)
        }
        return normalized(mix([hit(392, at: 0, length: 0.25), hit(523.3, at: 0.2, length: 0.65), hit(261.6, at: 0.2, length: 0.65).map { $0 * 0.6 }]), peak: 0.7)
    }

    /// Eight seconds of stadium murmur that loops seamlessly.
    static func crowdLoop(format: AVAudioFormat) -> AVAudioPCMBuffer {
        let n = frames(8)
        var x = lowpass(noise(n, seed: 9), cutoff: { i in 900 + 500 * sin(Float(i) / sr * 0.7) })
        let air = highpass(lowpass(noise(n, seed: 10), cutoff: 5000), cutoff: 1800).map { $0 * 0.18 }
        x = mix([x, air])
        for i in 0..<n {
            let t = Float(i) / sr
            x[i] *= 0.8 + 0.12 * sin(2 * Float.pi * 0.21 * t) + 0.08 * sin(2 * Float.pi * 0.067 * t + 1)
        }
        // Crossfade the tail into the head so the loop point is inaudible.
        let fade = frames(0.6)
        for i in 0..<fade {
            let t = Float(i) / Float(fade)
            x[n - fade + i] = x[n - fade + i] * (1 - t) + x[i] * t
        }
        return buffer(normalized(x, peak: 0.6), format: format)
    }
}
