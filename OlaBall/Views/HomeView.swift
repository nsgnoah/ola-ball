import SwiftUI
import GameKit

struct HomeView: View {
    @Environment(ProfileStore.self) private var profiles
    @Environment(LocalMatchStore.self) private var localMatches
    @State private var gc = GameCenterService.shared
    @State private var showMatchmaker = false
    @State private var showMyTeam = false
    @State private var gcMode: MatchMode = .couple
    @State private var myTeamDraft = TeamDraft()
    @State private var showNewLocal = false
    @State private var showResetConfirm = false
    @State private var showAbout = false
    @State private var openLocalID: String?
    @State private var openGCMatch: GKTurnBasedMatch?

    var body: some View {
        Stage(GameBackground(top: Theme.violet, bottom: Theme.violetDeep)) {
            StageScroll {
                VStack(spacing: 18) {
                    header
                    if let p = profiles.profile { youCard(p) }
                    gameCenterSection
                    passAndPlaySection
                    footer
                }
                .padding(.horizontal, 20)
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
                let state = gc.state(for: match) ?? newGCState(profile: p)
                MatchView(controller: MatchController(state: state, transport: GameCenterTransport(match: match, profile: p)))
                    .environment(localMatches)
                    .environment(profiles)
            }
        }
        .sheet(isPresented: $showMatchmaker) {
            MatchmakerView(mode: gcMode) { showMatchmaker = false }.ignoresSafeArea()
        }
        .sheet(isPresented: $showMyTeam) {
            MyTeamSheet { draft in
                myTeamDraft = draft
                gcMode = .teams
                showMyTeam = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { showMatchmaker = true }
            }
            .presentationDetents([.large])
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
            // The matchmaker is usually still on screen here, and a full-screen cover asked for
            // from behind a sheet is silently dropped. Close the sheet first and open the match
            // once it has actually gone, the same hand-off the team sheet does above.
            if showMatchmaker || showMyTeam {
                showMatchmaker = false
                showMyTeam = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { openGCMatch = m }
            } else {
                openGCMatch = m
            }
        }
        .fullScreenCover(isPresented: $showAbout) {
            AboutView { showAbout = false }
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

    /// A brand-new Game Center match: this phone created it, so it seeds the state.
    private func newGCState(profile p: Profile) -> MatchState {
        let seed = UInt64.random(in: 0...UInt64.max)
        if gcMode == .teams, myTeamDraft.isComplete {
            return MatchState(seed: seed, creator: .team(id: gc.localPlayerID, members: myTeamDraft.members), mode: .teams)
        }
        return MatchState(seed: seed, creator: .solo(id: gc.localPlayerID, name: p.name, world: p.world))
    }

    // MARK: Sections

    private var header: some View {
        VStack(spacing: 12) {
            Kicker("SPINOLA · TRIVIA FOR TWO")
            Wordmark()
            Text("Pick what your partner gets quizzed on. They pick yours. First to three crowns.")
                .font(.body(13)).foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
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
                    HStack(spacing: 8) {
                        Button { openGCMatch = m } label: { matchRow(gc: m) }.buttonStyle(.plain)
                        // Game Center only allows removing a match that has ended, and removing it
                        // takes it off this phone's list only; the other player keeps their copy.
                        if m.status == .ended {
                            Button {
                                Haptics.tap()
                                Task { await gc.remove(m) }
                            } label: {
                                Glyph(kind: .trash, size: 17)
                                    .frame(width: 44, height: 44)
                                    .background(.white.opacity(0.2), in: Circle())
                            }
                            .accessibilityLabel("Remove match from my list")
                        }
                    }
                }
                Button {
                    Haptics.tap()
                    gcMode = .couple
                    showMatchmaker = true
                } label: {
                    HStack(spacing: 10) {
                        Glyph(kind: .send, size: 20, color: Theme.ink)
                        Text("Challenge your partner")
                    }
                }
                .buttonStyle(ChunkyButtonStyle(color: Theme.gold))
                .accessibilityIdentifier("new-gc-match")
                Button {
                    Haptics.tap()
                    showMyTeam = true
                } label: {
                    HStack(spacing: 10) {
                        Glyph(kind: .people, size: 22, color: Theme.ink)
                        Text("Challenge another couple")
                    }
                }
                .buttonStyle(ChunkyButtonStyle(color: .white, edge: Theme.panelEdge, ink: Theme.ink, height: 52, fontSize: 22))
                .accessibilityIdentifier("new-gc-teams")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Glyph(kind: .controller, size: 20)
                            .frame(width: 32, height: 32).background(Theme.his, in: Circle())
                        Text("Play from two phones").font(.headline(TypeScale.heading)).foregroundStyle(Theme.ink)
                    }
                    Text(gc.authError ?? "Sign in to Game Center with the Apple ID already on this phone. No new account, no password.")
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
                            Glyph(kind: .trash, size: 17)
                                .frame(width: 44, height: 44)
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
                    Glyph(kind: .people, size: 22, color: Theme.ink)
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
            SideAvatars(player: a, size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(a.name.uppercased()) VS \(b?.name.uppercased() ?? "?")").font(.headline(20)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.6)
                Text((state.mode == .teams ? "Couples · " : "") + (state.status == .finished ? "Final · \(state.winnerID.flatMap { state.player($0)?.name }.map { "\($0) won" } ?? "Tie")" : "Round \(max(1, state.rounds.count)) · \(turnName)'s move"))
                    .font(.body(12)).foregroundStyle(Theme.ink2).lineLimit(2).minimumScaleFactor(0.7)
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
        let them = state?.partner(of: me)
        return HStack(spacing: 12) {
            if let them { SideAvatars(player: them, size: 36) } else { Avatar(name: opponent, world: profiles.profile?.world.other ?? .his, size: 40) }
            VStack(alignment: .leading, spacing: 2) {
                Text("VS \((them?.name ?? opponent).uppercased())").font(.headline(20)).foregroundStyle(Theme.ink).lineLimit(1).minimumScaleFactor(0.6)
                Text(((state?.mode == .teams) ? "Couples · " : "") + (m.status == .ended ? "Final" : (mine ? "Your move" : "Their move") + (state.map { " · Round \(max(1, $0.rounds.count))" } ?? "")))
                    .font(.body(12)).foregroundStyle(mine ? Theme.hers : Theme.ink2)
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
                Button("Privacy & support") { showAbout = true }
                    .accessibilityIdentifier("open-about")
                Button("Start over", role: .destructive) { showResetConfirm = true }
            } label: {
                Glyph(kind: .more, size: 18)
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.2), in: Circle())
            }
            .accessibilityLabel("More")
        }
    }
}

/// Set up a pass-and-play match: you vs your partner, or your couple vs another couple, all on this phone.
struct NewLocalMatchSheet: View {
    @Environment(ProfileStore.self) private var profiles
    @Environment(LocalMatchStore.self) private var localMatches
    @State private var mode: MatchMode = .couple
    @State private var partnerName = ""
    @State private var partnerWorld: World?
    @State private var ours = TeamDraft()
    @State private var theirs = TeamDraft()
    let onCreate: (String) -> Void

    private var canStart: Bool {
        switch mode {
        case .couple: return partnerWorld != nil && !partnerName.trimmingCharacters(in: .whitespaces).isEmpty
        case .teams: return ours.isComplete && theirs.isComplete
        }
    }

    var body: some View {
        Stage(GameBackground(top: Theme.violet, bottom: Theme.violetDeep)) {
            StageScroll {
                VStack(alignment: .leading, spacing: 14) {
                    Kicker("PASS & PLAY")
                    StickerText("WHO'S PLAYING?", size: TypeScale.title, alignment: .leading)
                    HStack(spacing: 8) {
                        ForEach([MatchMode.couple, .teams], id: \.self) { m in
                            Button { Haptics.tap(); mode = m } label: { Text(m.title) }
                                .buttonStyle(ChunkyButtonStyle(color: mode == m ? Theme.gold : .white, edge: mode == m ? nil : Theme.panelEdge, ink: Theme.ink, height: 46, fontSize: 17))
                                .accessibilityIdentifier("mode-\(m.rawValue)")
                        }
                    }
                    if mode == .couple {
                        TextField("Partner's first name", text: $partnerName)
                            .font(.bodyBold(20)).foregroundStyle(Theme.ink)
                            .textInputAutocapitalization(.words).autocorrectionDisabled()
                            .padding(.horizontal, 14).frame(height: 54)
                            .background(Theme.cream, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .accessibilityIdentifier("partner-name")
                        Kicker("THEY KNOW")
                        HStack(spacing: 10) {
                            ForEach(World.allCases) { w in
                                Button { Haptics.tap(); partnerWorld = w } label: { Text(w.title.uppercased()) }
                                    .buttonStyle(ChunkyButtonStyle(color: partnerWorld == w ? w.color : .white, edge: partnerWorld == w ? nil : Theme.panelEdge, ink: partnerWorld == w ? .white : Theme.ink, height: 50, fontSize: 20))
                                    .accessibilityIdentifier("partner-world-\(w.rawValue)")
                            }
                        }
                        OlaSays(text: "You get quizzed on their world. They get quizzed on yours.")
                    } else {
                        TeamSetupFields(title: "YOUR COUPLE", draft: $ours)
                        TeamSetupFields(title: "THE OTHER COUPLE", draft: $theirs, placeholder1: "Their first name", placeholder2: "Their partner's first name")
                        OlaSays(text: "Each couple picks decks for the other couple. Scores add up. First to three crowns.")
                    }
                    Button("Start the match") {
                        guard let me = profiles.profile, canStart else { return }
                        Haptics.heavy()
                        switch mode {
                        case .couple:
                            onCreate(localMatches.create(me: me, partnerName: partnerName.trimmingCharacters(in: .whitespaces), partnerWorld: partnerWorld ?? me.world.other))
                        case .teams:
                            var p = me
                            p.teamPartnerName = ours.name2.trimmingCharacters(in: .whitespaces)
                            p.teamMyLane = ours.lane1
                            p.teamPartnerLane = ours.lane2
                            profiles.profile = p
                            onCreate(localMatches.createTeams(ours: ours.members, theirs: theirs.members))
                        }
                    }
                    .buttonStyle(ChunkyButtonStyle(color: Theme.gold))
                    .disabled(!canStart)
                    .opacity(canStart ? 1 : 0.45)
                    .accessibilityIdentifier("create-local-match")
                    .padding(.top, 4)
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            partnerWorld = profiles.profile?.world.other
            ours = .mine(from: profiles.profile)
        }
        .preferredColorScheme(.dark)
    }
}
