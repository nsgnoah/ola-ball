import SwiftUI

struct HomeView: View {
    @Environment(ProgressStore.self) private var store
    @State private var showGame = false
    @State private var showResetConfirm = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        header
                        rankCard
                        Button {
                            Haptics.heavy()
                            showGame = true
                        } label: {
                            Label("Play a Game", systemImage: "play.fill")
                        }
                        .buttonStyle(BigButtonStyle())
                        statsRow
                        NavigationLink {
                            PlaybookView()
                        } label: {
                            playbookCard
                        }
                        .buttonStyle(.plain)
                        Spacer(minLength: 24)
                        Button("Reset progress") { showResetConfirm = true }
                            .font(.label(13)).foregroundStyle(Theme.textSecondary)
                    }
                    .padding()
                }
            }
            .navigationTitle("")
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(isPresented: $showGame) {
                if let team = store.team {
                    var rng = SystemRandomNumberGenerator()
                    let opponent = Team.randomOpponent(for: team, using: &rng)
                    GameView(session: GameSession(userTeam: team, opponentTeam: opponent, store: store))
                        .environment(store)
                }
            }
            .confirmationDialog("Reset all progress?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Reset everything", role: .destructive) { store.reset() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This erases your team, XP, record, and Playbook on this device. Nothing is stored anywhere else.")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Text(store.team?.emoji ?? "🏈")
                .font(.system(size: 40))
                .frame(width: 68, height: 68)
                .background((store.team?.color ?? Theme.grass).opacity(0.5), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Ola Ball").font(.label(13)).foregroundStyle(Theme.gold)
                Text(store.team?.fullName ?? "").font(.display(24)).foregroundStyle(Theme.textPrimary)
                Text("Coached by you").font(.body(14)).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
    }

    private var rankCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(store.rank.title).font(.display(20)).foregroundStyle(Theme.textPrimary)
                Spacer()
                Text("\(store.progress.xp) XP").font(.label(14)).foregroundStyle(Theme.gold)
            }
            ProgressView(value: store.rankProgress)
                .tint(Theme.gold)
                .scaleEffect(x: 1, y: 2, anchor: .center)
            if let next = store.nextRank {
                Text("\(next.minXP - store.progress.xp) XP to \(next.title)")
                    .font(.body(13)).foregroundStyle(Theme.textSecondary)
            } else {
                Text("Top of the profession.").font(.body(13)).foregroundStyle(Theme.textSecondary)
            }
        }
        .padding()
        .card()
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            stat(value: "\(store.progress.wins)-\(store.progress.losses)\(store.progress.ties > 0 ? "-\(store.progress.ties)" : "")", label: "Record")
            stat(value: "\(store.progress.streak)🔥", label: "Day streak")
            stat(value: "\(store.progress.touchdowns)", label: "Touchdowns")
        }
    }

    private func stat(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.display(20)).foregroundStyle(Theme.textPrimary)
            Text(label).font(.label(12)).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .card()
    }

    private var playbookCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "book.closed.fill").font(.system(size: 28)).foregroundStyle(Theme.gold)
            VStack(alignment: .leading, spacing: 3) {
                Text("Playbook").font(.display(18)).foregroundStyle(Theme.textPrimary)
                Text("\(store.learnedCount) of \(store.totalConcepts) concepts learned")
                    .font(.body(14)).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.textSecondary)
        }
        .padding()
        .card()
    }
}
