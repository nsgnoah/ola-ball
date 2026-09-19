import SwiftUI

struct TeamPickView: View {
    @Environment(ProgressStore.self) private var store
    @State private var selected: Team?

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer(minLength: 20)
                Text("🏈").font(.system(size: 56))
                Text("Ola Ball").font(.display(40)).foregroundStyle(Theme.textPrimary)
                Text("You're the coach now.\nPick your team and call the shots.")
                    .font(.body(17)).foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Team.all) { team in
                        Button {
                            Haptics.tap()
                            selected = team
                        } label: {
                            VStack(spacing: 6) {
                                Text(team.emoji).font(.system(size: 34))
                                Text(team.city).font(.label(12)).foregroundStyle(Theme.textSecondary)
                                Text(team.name).font(.display(18)).foregroundStyle(Theme.textPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(team.color.opacity(selected == team ? 0.9 : 0.35), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(selected == team ? Theme.gold : .clear, lineWidth: 3))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)

                Spacer()

                Button("Let's go") {
                    if let selected {
                        Haptics.success()
                        store.setTeam(selected)
                    }
                }
                .buttonStyle(BigButtonStyle())
                .disabled(selected == nil)
                .opacity(selected == nil ? 0.5 : 1)
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
        }
    }
}
