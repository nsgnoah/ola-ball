import SwiftUI

struct PlaybookView: View {
    @Environment(ProgressStore.self) private var store

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(store.learnedCount) of \(store.totalConcepts) learned").font(.display(22)).foregroundStyle(Theme.textPrimary)
                        Text("Every concept here was taught mid-game, right when it mattered. Locked ones unlock when you run into them.")
                            .font(.body(14)).foregroundStyle(Theme.textSecondary)
                        ProgressView(value: Double(store.learnedCount), total: Double(store.totalConcepts)).tint(Theme.gold)
                    }
                    ForEach(Concept.Category.allCases, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(category.rawValue.uppercased()).font(.label(12)).foregroundStyle(Theme.gold)
                            ForEach(Concept.all.filter { $0.category == category }) { concept in
                                row(concept, learned: store.progress.seen.contains(concept.id))
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Playbook")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.background, for: .navigationBar)
    }

    private func row(_ concept: Concept, learned: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: learned ? concept.symbol : "lock.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(learned ? Theme.gold : Theme.textSecondary)
                .frame(width: 36, height: 36)
                .background((learned ? Theme.gold : Theme.textSecondary).opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(learned ? concept.title : "???").font(.display(16)).foregroundStyle(Theme.textPrimary)
                Text(learned ? concept.body : "Unlock: \(concept.unlockHint)")
                    .font(.body(14)).foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .opacity(learned ? 1 : 0.7)
    }
}
