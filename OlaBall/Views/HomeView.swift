import SwiftUI
import GameKit

struct HomeView: View {
    @Environment(ProfileStore.self) private var profiles
    @Environment(LocalMatchStore.self) private var localMatches
    @State private var gc = GameCenterService.shared
    @State private var showMatchmaker = false
    @State private var showNewLocal = false
    @State private var showResetConfirm = false
    @State private var openLocalID: String?
    @State private var openGCMatch: GKTurnBasedMatch?

    var body: some View {
        ZStack {
            GameBackground(top: Theme.violet, bottom: Theme.violetDeep)
            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    header
                    if let p = profiles.profile { youCard(p) }
                    gameCenterSection
                    passAndPlaySection
                    footer
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $openLocalID) { id in
            if let state = localMatches.matches[id] {
                MatchView(controller: MatchController(state: state, transport: PassAndPlayTransport(id: id, state: state, store: localMatches)))
                    .environment(localMatches)
                    .environment(profiles)
            }
        }
        .fullScreenCover(item: $openGCMatch) { match in
            if let p = profiles.profile {
                let state = gc.state(for: match) ?? MatchState(seed: UInt64.random(in: 0...UInt64.max), creator: MatchPlayer(id: gc.localPlayerID, name: p.name, world: p.world))
                MatchView(controller: MatchController(state: state, transport: GameCenterTransport(match: match, profile: p)))
                    .environment(localMatches)
                    .environment(profiles)
            }
        }
        .sheet(isPresented: $showMatchmaker) {
            MatchmakerView { showMatchmaker = false }.ignoresSafeArea()
        }
        .sheet(isPresented: $showNewLocal) {
            NewLocalMatchSheet { id in
                showNewLocal = false
                openLocalID = id
            }
            .presentationDetents([.medium, .large])
        }
        .sheet(item: Binding(get: { gc.pendingAuthController.map { AuthSheet(controller: $0) } }, set: { _ in gc.pendingAuthController = nil })) { sheet in
            GameCenterControllerPresenter(controller: sheet.controller).ignoresSafeArea()
        }
        .onChange(of: gc.activeMatchID) { _, id in
            guard let id, let m = gc.matches.first(where: { $0.matchID == id }) else { return }
            gc.activeMatchID = nil
            openGCMatch = m
        }
        .confirmationDialog("Start over?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset profile and pass-and-play matches", role: .destructive) { localMatches.reset(); profiles.reset() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Game Center matches are kept by Game Center and aren't affected.")
        }
        .task { await gc.reload() }
    }

    private struct AuthSheet: Identifiable { let controller: UIViewController; var id: ObjectIdentifier { ObjectIdentifier(controller) } }

    // MARK: Sections

    private var header: some View {
        VStack(spacing: 0) {
            Kicker("OLA · TRIVIA FOR TWO")
            HStack(alignment: .center, spacing: 10) {
                worldBadge(.his, "HIS")
                Text("VS").font(.headline(30)).foregroundStyle(Theme.gold)
                    .rotationEffect(.degrees(-8))
                worldBadge(.hers, "HER")
            }
            .padding(.top, 8)
            Text("WORLD").font(.headline(46)).foregroundStyle(.white).padding(.top, -6)
                .shadow(color: .black.opacity(0.3), radius: 0, y: 3)
            Text("Pick what your partner gets quizzed on. They pick yours. First to three crowns.")
                .font(.body(13)).foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 2)
        }
    }

    private func worldBadge(_ w: World, _ label: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(w.color.mix(with: .black, by: 0.3)).offset(y: 5)
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(w.color)
            Text(label).font(.headline(40)).foregroundStyle(.white)
        }
        .frame(width: 118, height: 66)
    }

    private func youCard(_ p: Profile) -> some View {
        HStack(spacing: 12) {
            Avatar(name: p.name, world: p.world, size: 48)
            VStack(alignment: .leading, spacing: 2) {
                Text(p.name.uppercased()).font(.headline(24)).foregroundStyle(Theme.ink)
                Text(p.world.iKnowLine).font(.body(13)).foregroundStyle(Theme.ink2)
            }
            Spacer()
            WorldTag(world: p.world)
        }
        .panel(padding: 14)
    }

    private var gameCenterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker("ONLINE · TWO PHONES")
            if gc.isAuthenticated {
                if gc.matches.isEmpty {
                    Text("No matches yet. Challenge your partner and they'll get a notification.")
                        .font(.body(14)).foregroundStyle(.white.opacity(0.85))
                }
                ForEach(gc.matches, id: \.matchID) { m in
                    Button { openGCMatch = m } label: { matchRow(gc: m) }.buttonStyle(.plain)
                }
                Button {
                    Haptics.tap()
                    showMatchmaker = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "paperplane.fill").font(.system(size: 16, weight: .black))
                        Text("Challenge your partner")
                    }
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.gold))
                .accessibilityIdentifier("new-gc-match")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sign in to Game Center to play from two phones.")
                        .font(.bodyBold(15)).foregroundStyle(Theme.ink)
                    Text(gc.authError ?? "Uses the Apple ID already on this phone. No new account, no password.")
                        .font(.bodyRegular(13)).foregroundStyle(Theme.ink2)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(gc.authError == nil ? "Sign in" : "Open Settings") {
                        if gc.pendingAuthController != nil { return }
                        if gc.authError == nil { gc.authenticate() }
                        else if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.his, ink: .white, height: 50, fontSize: 20))
                }
                .panel(padding: 14)
            }
        }
    }

    private var passAndPlaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Kicker("PASS & PLAY · ONE PHONE")
            let sorted = localMatches.matches.sorted { $0.value.updatedAt > $1.value.updatedAt }
            ForEach(sorted, id: \.key) { id, state in
                HStack(spacing: 8) {
                    Button { openLocalID = id } label: { matchRow(local: state) }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("local-match-\(id)")
                    if state.status == .finished {
                        Button {
                            localMatches.delete(id)
                        } label: {
                            Image(systemName: "trash.fill").font(.system(size: 14, weight: .bold)).foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(.white.opacity(0.2), in: Circle())
                        }
                        .accessibilityLabel("Delete match")
                    }
                }
            }
            Button {
                Haptics.tap()
                showNewLocal = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "person.2.fill").font(.system(size: 16, weight: .black))
                    Text("New pass & play")
                }
            }
            .buttonStyle(ChunkyButtonStyle(color: .white, edge: Theme.panelEdge, ink: Theme.ink))
            .accessibilityIdentifier("new-local-match")
        }
    }

    private func matchRow(local state: MatchState) -> some View {
        let a = state.players[0], b = state.players.count > 1 ? state.players[1] : nil
        let turnName = state.player(state.turnPlayerID ?? "")?.name ?? ""
        return HStack(spacing: 12) {
            ZStack {
                Avatar(name: a.name, world: a.world, size: 40).offset(x: -10)
                if let b { Avatar(name: b.name, world: b.world, size: 40).offset(x: 12) }
            }
            .frame(width: 66)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(a.name.uppercased()) VS \(b?.name.uppercased() ?? "?")").font(.headline(22)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
                Text(state.status == .finished ? "Final · \(state.winnerID.flatMap { state.player($0)?.name }.map { "\($0) won" } ?? "Tie")" : "Round \(max(1, state.rounds.count)) · \(turnName)'s move")
                    .font(.body(13)).foregroundStyle(Theme.ink2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Crowns(count: state.crowns(for: a.id), size: 13)
                if let b { Crowns(count: state.crowns(for: b.id), size: 13) }
            }
        }
        .panel(padding: 12, radius: 18)
    }

    private func matchRow(gc m: GKTurnBasedMatch) -> some View {
        let state = gc.state(for: m)
        let mine = gc.isMyTurn(m)
        let me = gc.localPlayerID
        let opponent = gc.opponentName(m)
        return HStack(spacing: 12) {
            Avatar(name: opponent, world: state?.partner(of: me)?.world ?? (profiles.profile?.world.other ?? .his), size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("VS \(opponent.uppercased())").font(.headline(22)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.7)
                Text(m.status == .ended ? "Final" : (mine ? "Your move" : "Their move") + (state.map { " · Round \(max(1, $0.rounds.count))" } ?? ""))
                    .font(.body(13)).foregroundStyle(mine ? Theme.hers : Theme.ink2)
            }
            Spacer()
            if let state {
                VStack(alignment: .trailing, spacing: 3) {
                    Crowns(count: state.crowns(for: me), size: 13)
                    if let p = state.partner(of: me) { Crowns(count: state.crowns(for: p.id), size: 13) }
                }
            }
        }
        .panel(padding: 12, radius: 18)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Menu {
                Button("Start over", role: .destructive) { showResetConfirm = true }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(.white.opacity(0.2), in: Circle())
            }
            .accessibilityLabel("More")
        }
    }
}

/// Set up a pass-and-play match: who's the other player and what world they know.
struct NewLocalMatchSheet: View {
    @Environment(ProfileStore.self) private var profiles
    @Environment(LocalMatchStore.self) private var localMatches
    @State private var partnerName = ""
    @State private var partnerWorld: World?
    let onCreate: (String) -> Void

    var body: some View {
        ZStack {
            GameBackground(top: Theme.violet, bottom: Theme.violetDeep)
            VStack(alignment: .leading, spacing: 14) {
                Kicker("PASS & PLAY")
                Text("WHO'S PLAYING?").font(.headline(44)).foregroundStyle(.white).padding(.top, -8)
                TextField("Partner's first name", text: $partnerName)
                    .font(.bodyBold(20)).foregroundStyle(Theme.ink)
                    .textInputAutocapitalization(.words).autocorrectionDisabled()
                    .padding(.horizontal, 14).frame(height: 54)
                    .background(Theme.cream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityIdentifier("partner-name")
                Kicker("THEY KNOW")
                HStack(spacing: 10) {
                    ForEach(World.allCases) { w in
                        Button {
                            Haptics.tap(); partnerWorld = w
                        } label: {
                            Text(w.title.uppercased())
                        }
                        .buttonStyle(ChunkyButtonStyle(color: partnerWorld == w ? w.color : .white, edge: partnerWorld == w ? nil : Theme.panelEdge, ink: partnerWorld == w ? .white : Theme.ink, height: 50, fontSize: 20))
                        .accessibilityIdentifier("partner-world-\(w.rawValue)")
                    }
                }
                Spacer()
                Button("Start the match") {
                    guard let me = profiles.profile, let partnerWorld, !partnerName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                    Haptics.heavy()
                    onCreate(localMatches.create(me: me, partnerName: partnerName.trimmingCharacters(in: .whitespaces), partnerWorld: partnerWorld))
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.gold))
                .disabled(partnerWorld == nil || partnerName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(partnerWorld == nil || partnerName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)
                .accessibilityIdentifier("create-local-match")
            }
            .padding(20)
        }
        .onAppear { partnerWorld = profiles.profile?.world.other }
        .preferredColorScheme(.dark)
    }
}
