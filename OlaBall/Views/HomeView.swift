import SwiftUI

/// Home: the stadium as the hero up top, a paper sheet with tonight's ticket below.
struct HomeView: View {
    @Environment(ProgressStore.self) private var store
    @State private var showGame = false
    @State private var showResetConfirm = false
    @State private var opponent: Team = Team.all[1]
    @State private var pickedOpponent = false
    @State private var session: GameSession?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Theme.background.ignoresSafeArea()
                if let team = store.team {
                    HomeSceneView(userTeam: team, opponentTeam: opponent, paused: showGame)
                        .ignoresSafeArea()
                        .id(opponent.id)
                }
                LinearGradient(colors: [Theme.background.opacity(0.85), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 260)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                if let team = store.team {
                    VStack(spacing: 0) {
                        hero(team: team)
                        Spacer(minLength: 0)
                        sheet(team: team)
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
            .onAppear { if !pickedOpponent { pickOpponent() }; SoundKit.shared.setScene(crowd: 0.14); SoundKit.shared.setMusic(true) }
            .fullScreenCover(isPresented: $showGame, onDismiss: { session = nil; pickOpponent(); SoundKit.shared.setScene(crowd: 0.14); SoundKit.shared.setMusic(true) }) {
                // The session is created once, at kickoff. Creating it inside this closure would build a new
                // game on every re-evaluation, and each copy would consume Coach Ola's opening notes.
                if let session {
                    GameView(session: session)
                        .environment(store)
                }
            }
            .confirmationDialog("Reset all progress?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Reset everything", role: .destructive) { store.reset() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This erases your club, XP, record, and Playbook on this device. Nothing is stored anywhere else.")
            }
        }
    }

    private func pickOpponent() {
        guard let team = store.team else { return }
        var rng = SystemRandomNumberGenerator()
        opponent = Team.randomOpponent(for: team, using: &rng)
        pickedOpponent = true
    }

    // MARK: Hero

    private func hero(team: Team) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text("OLA BALL").font(.condensed(13)).tracking(3).foregroundStyle(Theme.gold)
                Circle().fill(.white.opacity(0.4)).frame(width: 3, height: 3)
                Text("NIGHT GAME").font(.condensed(13)).tracking(3).foregroundStyle(.white.opacity(0.7))
                Circle().fill(.white.opacity(0.4)).frame(width: 3, height: 3)
                Text("WEEK \(store.progress.games + 1)").font(.condensed(13)).tracking(3).foregroundStyle(.white.opacity(0.7))
            }
            .padding(.bottom, 6)
            Text(team.city.uppercased())
                .font(.condensed(22)).tracking(4)
                .foregroundStyle(.white.opacity(0.85))
            Text(team.name.uppercased())
                .font(.headline(74))
                .lineLimit(1).minimumScaleFactor(0.55)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.6), radius: 16, y: 8)
                .padding(.top, -10)
            HStack(spacing: 8) {
                OlaBadge(size: 18)
                Text("Head coach: you. Ola's on the headset.").font(.body(14)).foregroundStyle(.white.opacity(0.8))
            }
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    // MARK: Sheet

    private func sheet(team: Team) -> some View {
        VStack(spacing: 14) {
            // Ticket
            VStack(spacing: 10) {
                HStack {
                    Kicker("TONIGHT", color: Theme.ink2)
                    Spacer()
                    Kicker("HOME · 4 QUARTERS", color: Theme.ink3)
                }
                HStack(spacing: 12) {
                    Monogram(team: team, size: 48)
                    VStack(spacing: 0) {
                        Text(team.name.uppercased()).font(.headline(30)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.6)
                        Text("VS").font(.condensed(12)).tracking(3).foregroundStyle(Theme.ink3).padding(.vertical, 1)
                        Text(opponent.name.uppercased()).font(.headline(30)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.6)
                    }
                    .frame(maxWidth: .infinity)
                    Monogram(team: opponent, size: 48)
                }
                Rectangle().fill(Theme.rule).frame(height: 1)
                Text("Draw every play. Ola explains the rules the moment they matter.")
                    .font(.body(13)).foregroundStyle(Theme.ink2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .paperCard(padding: 14)

            kickoff

            HStack(spacing: 0) {
                stat(value: recordText, label: "RECORD")
                divider
                stat(value: "\(store.progress.streak)", label: "DAY STREAK")
                divider
                stat(value: "\(store.progress.touchdowns)", label: "TOUCHDOWNS")
                divider
                stat(value: store.rank.title.uppercased(), label: "\(store.progress.xp) XP", small: true)
            }

            HStack {
                NavigationLink {
                    PlaybookView()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "book.closed.fill").foregroundStyle(Theme.ink)
                        Text("PLAYBOOK").font(.condensed(14)).tracking(2).foregroundStyle(Theme.ink)
                        Text("\(store.learnedCount)/\(store.totalConcepts)").font(.condensed(14)).foregroundStyle(Theme.ink3)
                        Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.ink3)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 42)
                    .background(Theme.paperCard, in: Capsule())
                    .overlay(Capsule().stroke(Theme.rule, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Playbook, \(store.learnedCount) of \(store.totalConcepts) concepts learned")
                Spacer()
                Menu {
                    Button("Reset progress", role: .destructive) { showResetConfirm = true }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Theme.ink)
                        .frame(width: 42, height: 42)
                        .background(Theme.paperCard, in: Circle())
                        .overlay(Circle().stroke(Theme.rule, lineWidth: 1))
                }
                .accessibilityLabel("More")
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, 40)
        .background(Theme.paper, in: UnevenRoundedRectangle(topLeadingRadius: 28, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.35), radius: 24, y: -8)
    }

    private var kickoff: some View {
        Button {
            guard let team = store.team else { return }
            Haptics.heavy()
            SoundKit.shared.play(.stinger, volume: 0.8)
            session = GameSession(userTeam: team, opponentTeam: opponent, store: store, autoplay: CommandLine.arguments.contains("-ui-testing-autoplay"))
            showGame = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "play.fill").font(.system(size: 16, weight: .black))
                Text("Kickoff")
            }
        }
        .buttonStyle(InkButtonStyle())
        .accessibilityLabel("Play a Game")
        .accessibilityIdentifier("kickoff")
    }

    private var recordText: String {
        let p = store.progress
        return "\(p.wins)-\(p.losses)" + (p.ties > 0 ? "-\(p.ties)" : "")
    }

    private var divider: some View {
        Rectangle().fill(Theme.rule).frame(width: 1, height: 30)
    }

    private func stat(value: String, label: String, small: Bool = false) -> some View {
        VStack(spacing: 1) {
            Text(value).font(small ? .condensed(15) : .score(24)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.condensed(10)).tracking(1.4).foregroundStyle(Theme.ink3)
        }
        .frame(maxWidth: .infinity)
    }
}
