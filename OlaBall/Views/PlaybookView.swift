import SwiftUI

struct PlaybookView: View {
    @Environment(ProgressStore.self) private var store

    var body: some View {
        ZStack {
            Theme.paper.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Kicker("OLA'S NOTES · COLLECTED IN-GAME", color: Theme.ink3)
                        Text("PLAYBOOK").font(.headline(64)).foregroundStyle(Theme.ink).padding(.top, -6)
                        Text("\(store.learnedCount) of \(store.totalConcepts) concepts. Every one was taught mid-game, right when it mattered. Locked ones unlock when you run into them.")
                            .font(.body(14)).foregroundStyle(Theme.ink2)
                            .fixedSize(horizontal: false, vertical: true)
                        ProgressView(value: Double(store.learnedCount), total: Double(store.totalConcepts)).tint(Theme.ink)
                            .scaleEffect(x: 1, y: 1.6, anchor: .center)
                            .padding(.top, 4)
                    }
                    ForEach(Concept.Category.allCases, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                Kicker(category.rawValue.uppercased(), color: Theme.ink)
                                Rectangle().fill(Theme.rule).frame(height: 1)
                            }
                            ForEach(Concept.all.filter { $0.category == category }) { concept in
                                row(concept, learned: store.progress.seen.contains(concept.id))
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .tint(Theme.ink)
        .preferredColorScheme(.light)
    }

    private func row(_ concept: Concept, learned: Bool) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: learned ? concept.symbol : "lock.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(learned ? Theme.paper : Theme.ink3)
                .frame(width: 36, height: 36)
                .background(learned ? Theme.ink : Theme.rule, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(learned ? concept.title : "???").font(.headline(21)).foregroundStyle(Theme.ink)
                Text(learned ? concept.body : "Unlock: \(concept.unlockHint)")
                    .font(.body(14)).foregroundStyle(Theme.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .paperCard(padding: 14, radius: 14)
        .opacity(learned ? 1 : 0.7)
    }
}
