import SwiftUI

/// Tap-timing kick meter. A needle sweeps back and forth; tap when it's in the green zone.
/// `targetWidth` (0...1) is how wide the green zone is: short kicks are forgiving, long ones are not.
struct KickMeterView: View {
    let title: String
    let subtitle: String
    let targetWidth: Double
    let onKick: (_ accuracy: Double) -> Void   // 0 = dead center, 1 = far edge

    @State private var start = Date()
    @State private var kicked = false
    @State private var kickedAt: Double?

    private let period: Double = 1.5   // seconds for a full left-right-left sweep

    private func needlePosition(at t: Double) -> Double {
        // Triangle wave in 0...1
        let phase = (t / period).truncatingRemainder(dividingBy: 1)
        return phase < 0.5 ? phase * 2 : (1 - phase) * 2
    }

    var body: some View {
        VStack(spacing: 14) {
            Text(title).font(.display(22)).foregroundStyle(Theme.textPrimary)
            Text(subtitle).font(.body(14)).foregroundStyle(Theme.textSecondary).multilineTextAlignment(.center)
            TimelineView(.animation(paused: kicked)) { timeline in
                let t = kickedAt ?? timeline.date.timeIntervalSince(start)
                let x = needlePosition(at: t)
                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10).fill(Theme.bad.opacity(0.35))
                        RoundedRectangle(cornerRadius: 10).fill(Theme.gold.opacity(0.5))
                            .frame(width: w * min(0.9, targetWidth * 2.2))
                            .position(x: w / 2, y: geo.size.height / 2)
                        RoundedRectangle(cornerRadius: 10).fill(Theme.good)
                            .frame(width: w * targetWidth)
                            .position(x: w / 2, y: geo.size.height / 2)
                        RoundedRectangle(cornerRadius: 3).fill(.white)
                            .frame(width: 6, height: geo.size.height + 10)
                            .position(x: w * x, y: geo.size.height / 2)
                            .shadow(radius: 3)
                    }
                }
                .frame(height: 44)
            }
            Button(kicked ? "..." : "KICK!") {
                guard !kicked else { return }
                let t = Date().timeIntervalSince(start)
                kickedAt = t
                kicked = true
                let x = needlePosition(at: t)
                let accuracy = min(1, abs(x - 0.5) * 2)
                Haptics.heavy()
                onKick(accuracy)
            }
            .buttonStyle(BroadcastButtonStyle())
            .disabled(kicked)
        }
        .padding()
        .background(Color.black.opacity(0.30))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onAppear { start = Date() }
    }
}
