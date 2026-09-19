import SwiftUI

/// First launch: pick a club. Paper page, team-color pennants.
struct TeamPickView: View {
    @Environment(ProgressStore.self) private var store
    @State private var selected: Team?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("OLA BALL").font(.condensed(13)).tracking(3).foregroundStyle(Theme.ink)
                        Circle().fill(Theme.ink3).frame(width: 3, height: 3)
                        Text("SEASON ONE").font(.condensed(13)).tracking(3).foregroundStyle(Theme.ink3)
                    }
                    Text("PICK YOUR")
                        .font(.condensed(22)).tracking(4).foregroundStyle(Theme.ink2)
                        .padding(.top, 10)
                    Text("CLUB")
                        .font(.headline(84)).foregroundStyle(Theme.ink)
                        .padding(.top, -14)
                    Text("You're the head coach. You'll draw every play, and Ola on the headset explains the rules the moment they matter.")
                        .font(.body(15)).foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
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
                    .padding(.horizontal, 20)
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
                        Image(systemName: "arrow.right").font(.system(size: 15, weight: .black))
                    }
                }
                .buttonStyle(InkButtonStyle())
                .disabled(selected == nil)
                .opacity(selected == nil ? 0.35 : 1)
                .accessibilityLabel("Let's go")
                .accessibilityIdentifier("lets-go")
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
            }
        }
        .preferredColorScheme(.light)
    }

    private func pennant(_ team: Team, isSelected: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [Art.swiftUI(team.color, brightness: 0.06), Art.swiftUI(team.color, brightness: -0.16)], startPoint: .topLeading, endPoint: .bottomTrailing))
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
                Monogram(team: team, size: 44)
                Spacer(minLength: 8)
                Text(team.city.uppercased()).font(.condensed(11)).tracking(2).foregroundStyle(.white.opacity(0.85))
                Text(team.name.uppercased()).font(.headline(30)).foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
            .padding(14)
        }
        .frame(height: 148)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(isSelected ? Theme.ink : .clear, lineWidth: 3))
        .shadow(color: .black.opacity(isSelected ? 0.25 : 0.10), radius: isSelected ? 16 : 8, y: 6)
        .scaleEffect(isSelected ? 1.03 : 1)
    }
}
