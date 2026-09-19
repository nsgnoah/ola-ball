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
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
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

    static func correct() -> [Float] {
        let total = frames(0.6)
        return normalized(mix([delayed(note(784, length: 0.35), by: 0, total: total), delayed(note(1175, length: 0.45), by: 0.09, total: total)]), peak: 0.6)
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
        let total = frames(1.2)
        return normalized(mix([
            delayed(note(523, length: 0.3), by: 0, total: total),
            delayed(note(659, length: 0.3), by: 0.12, total: total),
            delayed(note(784, length: 0.3), by: 0.24, total: total),
            delayed(note(1047, length: 0.8, tau: 0.3), by: 0.36, total: total),
        ]), peak: 0.65)
    }

    static func fanfare() -> [Float] {
        let total = frames(1.8)
        func brass(_ f: Float, at: Float, len: Float) -> [Float] {
            let n = frames(len)
            let raw = lowpass(tone(n, frequency: { _ in f }, harmonics: [1, 0.7, 0.5, 0.35, 0.25]), cutoff: 2600)
            return delayed(mul(raw, envelope(n, attack: 0.02, hold: max(0, len - 0.22), release: 0.2)), by: at, total: total)
        }
        return normalized(mix([brass(523, at: 0, len: 0.16), brass(659, at: 0.14, len: 0.16), brass(784, at: 0.28, len: 0.16), brass(1047, at: 0.42, len: 1.2), brass(523, at: 0.42, len: 1.2).map { $0 * 0.5 }]), peak: 0.65)
    }

    static func lose() -> [Float] {
        let total = frames(1.0)
        return normalized(mix([delayed(note(392, length: 0.4, tau: 0.25), by: 0, total: total), delayed(note(330, length: 0.6, tau: 0.3), by: 0.3, total: total)]), peak: 0.5)
    }
}
