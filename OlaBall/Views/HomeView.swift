import SwiftUI

/// Home is the stadium: your team warming up under the lights, and a broadcast-style pre-game package over it.
struct HomeView: View {
    @Environment(ProgressStore.self) private var store
    @State private var showGame = false
    @State private var showResetConfirm = false
    @State private var opponent: Team = Team.all[1]
    @State private var pickedOpponent = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                if let team = store.team {
                    HomeSceneView(userTeam: team, opponentTeam: opponent, paused: showGame)
                        .ignoresSafeArea()
                        .id(opponent.id)
                }
                scrims
                if let team = store.team {
                    content(team: team)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { if !pickedOpponent { pickOpponent() }; SoundKit.shared.setScene(crowd: 0.14) }
            .fullScreenCover(isPresented: $showGame, onDismiss: { pickOpponent() }) {
                if let team = store.team {
                    GameView(session: GameSession(userTeam: team, opponentTeam: opponent, store: store, autoplay: CommandLine.arguments.contains("-ui-testing-autoplay")))
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

    private func pickOpponent() {
        guard let team = store.team else { return }
        var rng = SystemRandomNumberGenerator()
        opponent = Team.randomOpponent(for: team, using: &rng)
        pickedOpponent = true
    }

    // MARK: Layers

    private var scrims: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [Theme.background.opacity(0.95), Theme.background.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 300)
            Spacer()
            LinearGradient(colors: [.clear, Theme.background.opacity(0.75), Theme.background.opacity(0.97)], startPoint: .top, endPoint: .bottom)
                .frame(height: 440)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private func content(team: Team) -> some View {
        VStack(spacing: 0) {
            header(team: team)
            Spacer()
            matchup(team: team)
            kickoff
                .padding(.top, 12)
            seasonStrip
                .padding(.top, 12)
            footer
                .padding(.top, 8)
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }

    // MARK: Pieces

    private func header(team: Team) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                kicker("OLA BALL", color: Theme.gold)
                Rectangle().fill(Theme.textSecondary.opacity(0.5)).frame(width: 1, height: 10)
                kicker("NIGHT GAME", color: Theme.textSecondary)
                Rectangle().fill(Theme.textSecondary.opacity(0.5)).frame(width: 1, height: 10)
                kicker("WEEK \(store.progress.games + 1)", color: Theme.textSecondary)
            }
            .padding(.bottom, 10)
            Text(team.city.uppercased())
                .font(.system(size: 20, weight: .heavy))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.8))
            Text(team.name.uppercased())
                .font(.system(size: 56, weight: .black))
                .tracking(-1.5)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.7), radius: 14, y: 6)
                .padding(.top, -6)
            HStack(spacing: 6) {
                Image(systemName: "person.fill").font(.system(size: 11, weight: .bold))
                Text("Head coach: you")
                Text("·")
                Text(store.rank.title)
            }
            .font(.body(14))
            .foregroundStyle(Theme.textSecondary)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func kicker(_ text: String, color: Color) -> some View {
        Text(text).font(.system(size: 11, weight: .black)).tracking(2.5).foregroundStyle(color)
    }

    private func matchup(team: Team) -> some View {
        HStack(spacing: 0) {
            Rectangle().fill(team.color).frame(width: 6)
            HStack(spacing: 12) {
                crest(team, size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    kicker("KICKOFF", color: Theme.gold)
                    Text("vs \(opponent.fullName)")
                        .font(.system(size: 19, weight: .heavy))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text("Home field · 4 quarters · you call every play")
                        .font(.body(12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 6)
                crest(opponent, size: 38)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            Rectangle().fill(opponent.color).frame(width: 6)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func crest(_ team: Team, size: CGFloat) -> some View {
        Text(team.emoji)
            .font(.system(size: size * 0.55))
            .frame(width: size, height: size)
            .background(team.color.opacity(0.9), in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1.5))
    }

    private var kickoff: some View {
        Button {
            Haptics.heavy()
            SoundKit.shared.play(.stinger, volume: 0.8)
            showGame = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.fill").font(.system(size: 18, weight: .black))
                Text("KICKOFF").font(.system(size: 22, weight: .black)).tracking(3)
            }
            .foregroundStyle(Color(hex: "0B1220"))
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                LinearGradient(colors: [Color(hex: "FFD65C"), Theme.gold, Color(hex: "E8AE1E")], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .shadow(color: Theme.gold.opacity(0.45), radius: 18, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Play a Game")
    }

    private var seasonStrip: some View {
        HStack(spacing: 0) {
            stat(value: recordText, label: "RECORD")
            divider
            stat(value: "\(store.progress.streak)", label: "DAY STREAK", accent: store.progress.streak > 0 ? "🔥" : nil)
            divider
            stat(value: "\(store.progress.touchdowns)", label: "TOUCHDOWNS")
            divider
            stat(value: "\(store.progress.xp)", label: "XP")
        }
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(alignment: .top) { Rectangle().fill(Theme.gold).frame(height: 2).clipShape(RoundedRectangle(cornerRadius: 1)) }
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var recordText: String {
        let p = store.progress
        return "\(p.wins)-\(p.losses)" + (p.ties > 0 ? "-\(p.ties)" : "")
    }

    private var divider: some View {
        Rectangle().fill(.white.opacity(0.15)).frame(width: 1, height: 28)
    }

    private func stat(value: String, label: String, accent: String? = nil) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Text(value).font(.display(20)).foregroundStyle(.white)
                if let accent { Text(accent).font(.system(size: 14)) }
            }
            Text(label).font(.system(size: 9, weight: .black)).tracking(1.5).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack {
            NavigationLink {
                PlaybookView()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "book.closed.fill").foregroundStyle(Theme.gold)
                    Text("PLAYBOOK").font(.system(size: 12, weight: .black)).tracking(2)
                    Text("\(store.learnedCount)/\(store.totalConcepts)").font(.label(12)).foregroundStyle(Theme.textSecondary)
                    Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.textSecondary)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Playbook, \(store.learnedCount) of \(store.totalConcepts) concepts learned")
            Spacer()
            Menu {
                Button("Reset progress", role: .destructive) { showResetConfirm = true }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("More")
        }
    }
}
