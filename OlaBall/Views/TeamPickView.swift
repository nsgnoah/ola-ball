import SwiftUI

/// First launch: pick a club. Pennant tiles in team colors over a night-sky gradient.
struct TeamPickView: View {
    @Environment(ProgressStore.self) private var store
    @State private var selected: Team?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "0A1230"), Theme.background, Color(hex: "060A16")], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        Kicker("OLA BALL")
                        Rectangle().fill(Theme.textSecondary.opacity(0.5)).frame(width: 1, height: 10)
                        Kicker("SEASON ONE", color: Theme.textSecondary)
                    }
                    Text("PICK YOUR")
                        .font(.system(size: 20, weight: .heavy)).tracking(3).foregroundStyle(.white.opacity(0.8))
                        .padding(.top, 8)
                    Text("CLUB")
                        .font(.system(size: 56, weight: .black)).tracking(-1.5).foregroundStyle(.white)
                        .padding(.top, -6)
                    Text("You're the head coach. You'll call every play, and the rules get explained as you go.")
                        .font(.body(15)).foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Team.all) { team in
                            Button {
                                Haptics.tap()
                                withAnimation(.spring(duration: 0.3)) { selected = team }
                            } label: {
                                pennant(team, isSelected: selected == team)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(team.city) \(team.name)")
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 12)
                }

                Button {
                    if let selected {
                        Haptics.success()
                        SoundKit.shared.play(.stinger, volume: 0.7)
                        store.setTeam(selected)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text(selected.map { "Coach the \($0.name)" } ?? "Pick a club")
                        Image(systemName: "arrow.right").font(.system(size: 14, weight: .black))
                    }
                }
                .buttonStyle(BroadcastButtonStyle())
                .disabled(selected == nil)
                .opacity(selected == nil ? 0.45 : 1)
                .accessibilityLabel("Let's go")
                .padding(.horizontal, 18)
                .padding(.bottom, 12)
            }
        }
    }

    private func pennant(_ team: Team, isSelected: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(colors: [Art.swiftUI(team.color, brightness: 0.05), Art.swiftUI(team.color, brightness: -0.18)], startPoint: .topLeading, endPoint: .bottomTrailing))
            // Diagonal stripe
            GeometryReader { geo in
                Path { p in
                    p.move(to: CGPoint(x: geo.size.width * 0.55, y: 0))
                    p.addLine(to: CGPoint(x: geo.size.width, y: 0))
                    p.addLine(to: CGPoint(x: geo.size.width * 0.45, y: geo.size.height))
                    p.addLine(to: CGPoint(x: 0, y: geo.size.height))
                    p.closeSubpath()
                }
                .fill(.white.opacity(0.07))
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(team.emoji).font(.system(size: 40))
                    .shadow(color: .black.opacity(0.4), radius: 6, y: 3)
                Spacer(minLength: 8)
                Text(team.city.uppercased()).font(.system(size: 10, weight: .black)).tracking(1.8).foregroundStyle(.white.opacity(0.85))
                Text(team.name.uppercased()).font(.system(size: 20, weight: .black)).tracking(-0.5).foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(14)
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(isSelected ? Theme.gold : .white.opacity(0.12), lineWidth: isSelected ? 3 : 1))
        .shadow(color: isSelected ? Theme.gold.opacity(0.35) : .clear, radius: 14)
        .scaleEffect(isSelected ? 1.03 : 1)
    }
}
