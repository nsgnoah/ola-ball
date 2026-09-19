import SwiftUI

struct PlaybookView: View {
    @Environment(ProgressStore.self) private var store

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "0A1230"), Theme.background, Color(hex: "060A16")], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Kicker("COLLECTED IN-GAME")
                        Text("PLAYBOOK").font(.system(size: 44, weight: .black)).tracking(-1).foregroundStyle(.white)
                        Text("\(store.learnedCount) of \(store.totalConcepts) concepts. Every one was taught mid-game, right when it mattered. Locked ones unlock when you run into them.")
                            .font(.body(14)).foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        ProgressView(value: Double(store.learnedCount), total: Double(store.totalConcepts)).tint(Theme.gold)
                            .scaleEffect(x: 1, y: 1.6, anchor: .center)
                            .padding(.top, 4)
                    }
                    ForEach(Concept.Category.allCases, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Kicker(category.rawValue.uppercased())
                                Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
                            }
                            ForEach(Concept.all.filter { $0.category == category }) { concept in
                                row(concept, learned: store.progress.seen.contains(concept.id))
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func row(_ concept: Concept, learned: Bool) -> some View {
        BroadcastPanel(accent: learned ? Theme.gold : .white.opacity(0.15)) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: learned ? concept.symbol : "lock.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(learned ? Theme.gold : Theme.textSecondary)
                    .frame(width: 34, height: 34)
                    .background((learned ? Theme.gold : Color.white).opacity(0.12), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(learned ? concept.title : "???").font(.system(size: 16, weight: .heavy)).foregroundStyle(.white)
                    Text(learned ? concept.body : "Unlock: \(concept.unlockHint)")
                        .font(.body(14)).foregroundStyle(learned ? .white.opacity(0.85) : Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .opacity(learned ? 1 : 0.75)
    }
}
