import SwiftUI

/// A stylized football field. Absolute x: 0 = user's goal line (left), 100 = opponent's goal line (right).
struct FieldView: View {
    let ballX: Int
    let firstDownX: Int?
    let userTeam: Team
    let opponentTeam: Team
    let possessor: GameSession.Possessor

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let endZone = w * 10 / 120
            let fieldW = w - endZone * 2
            let x: (Int) -> CGFloat = { yard in endZone + fieldW * CGFloat(yard) / 100 }

            ZStack(alignment: .leading) {
                Canvas { ctx, size in
                    // Grass
                    ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.grass))
                    for i in 0..<10 where i % 2 == 1 {
                        let rect = CGRect(x: x(i * 10), y: 0, width: fieldW / 10, height: h)
                        ctx.fill(Path(rect), with: .color(Theme.grassDark))
                    }
                    // End zones
                    ctx.fill(Path(CGRect(x: 0, y: 0, width: endZone, height: h)), with: .color(userTeam.color.opacity(0.85)))
                    ctx.fill(Path(CGRect(x: w - endZone, y: 0, width: endZone, height: h)), with: .color(opponentTeam.color.opacity(0.85)))
                    // Yard lines
                    for yard in stride(from: 0, through: 100, by: 5) {
                        var p = Path()
                        p.move(to: CGPoint(x: x(yard), y: 0))
                        p.addLine(to: CGPoint(x: x(yard), y: h))
                        ctx.stroke(p, with: .color(.white.opacity(yard % 10 == 0 ? 0.55 : 0.25)), lineWidth: yard % 50 == 0 ? 2 : 1)
                    }
                    // Numbers
                    for yard in stride(from: 10, through: 90, by: 10) {
                        let label = yard <= 50 ? yard : 100 - yard
                        let text = Text("\(label)").font(.system(size: 9, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.7))
                        ctx.draw(text, at: CGPoint(x: x(yard), y: h - 9))
                    }
                }

                // End zone labels
                Text(userTeam.abbreviation)
                    .font(.label(10)).foregroundStyle(.white).rotationEffect(.degrees(-90))
                    .frame(width: endZone, height: h)
                Text(opponentTeam.abbreviation)
                    .font(.label(10)).foregroundStyle(.white).rotationEffect(.degrees(90))
                    .frame(width: endZone, height: h)
                    .offset(x: w - endZone)

                // First-down line
                if let firstDownX {
                    Rectangle()
                        .fill(Theme.firstDownYellow)
                        .frame(width: 3, height: h)
                        .offset(x: x(firstDownX) - 1.5)
                        .animation(.spring(duration: 0.6), value: firstDownX)
                }

                // Ball
                Text("🏈")
                    .font(.system(size: 22))
                    .shadow(color: .black.opacity(0.5), radius: 3, y: 2)
                    .scaleEffect(x: possessor == .user ? 1 : -1, y: 1)
                    .position(x: x(ballX), y: h / 2 - 4)
                    .animation(.spring(duration: 0.7, bounce: 0.2), value: ballX)

                // Direction hint
                Image(systemName: possessor == .user ? "chevron.right.2" : "chevron.left.2")
                    .font(.system(size: 12, weight: .black))
                    .foregroundStyle(.white.opacity(0.6))
                    .position(x: x(ballX) + (possessor == .user ? 22 : -22), y: h / 2 - 4)
                    .animation(.spring(duration: 0.7), value: ballX)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}
