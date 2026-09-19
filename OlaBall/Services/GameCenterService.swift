import Foundation
import GameKit
import Observation
import SwiftUI

/// Game Center turn-based matches: sign-in, the list of matches, turn events, and submitting turns.
/// No server of our own; Apple stores the match data and pushes turn notifications.
@Observable
final class GameCenterService: NSObject, GKLocalPlayerListener {
    static let shared = GameCenterService()

    private(set) var isAuthenticated = false
    private(set) var authError: String?
    /// Game Center wants to show its own sign-in screen; present this from the root.
    var pendingAuthController: UIViewController?
    private(set) var matches: [GKTurnBasedMatch] = []
    /// Set when Game Center says a match needs attention (turn received, invite accepted).
    var activeMatchID: String?
    private(set) var isLoading = false

    var localPlayerID: String { GKLocalPlayer.local.gamePlayerID }
    var localDisplayName: String { GKLocalPlayer.local.displayName }

    private override init() { super.init() }

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, error in
            guard let self else { return }
            Task { @MainActor in
                if let controller {
                    self.pendingAuthController = controller
                    return
                }
                self.pendingAuthController = nil
                if GKLocalPlayer.local.isAuthenticated {
                    self.isAuthenticated = true
                    self.authError = nil
                    GKLocalPlayer.local.register(self)
                    await self.reload()
                } else {
                    self.isAuthenticated = false
                    // GameKit's own error text is developer-speak; say what to do instead.
                    self.authError = "Game Center isn't signed in on this phone. Open Settings, tap Game Center, sign in with your Apple ID, then come back."
                }
            }
        }
    }

    @MainActor
    func reload() async {
        guard isAuthenticated else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await GKTurnBasedMatch.loadMatches()
            matches = loaded.sorted { ($0.creationDate) > ($1.creationDate) }
        } catch {
            authError = error.localizedDescription
        }
    }

    // MARK: Match data

    func state(for match: GKTurnBasedMatch) -> MatchState? {
        guard let data = match.matchData, !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(MatchState.self, from: data)
    }

    func isMyTurn(_ match: GKTurnBasedMatch) -> Bool {
        match.status == .open && match.currentParticipant?.player?.gamePlayerID == localPlayerID
    }

    func opponentName(_ match: GKTurnBasedMatch) -> String {
        let other = match.participants.first { $0.player?.gamePlayerID != localPlayerID }
        return other?.player?.displayName ?? "Waiting for a partner"
    }

    /// Persist without ending the turn.
    func save(_ state: MatchState, to match: GKTurnBasedMatch) async throws {
        let data = try JSONEncoder().encode(state)
        try await match.saveCurrentTurn(withMatch: data)
    }

    /// End my turn (or the whole match) with the new state.
    func submit(_ state: MatchState, to match: GKTurnBasedMatch) async throws {
        let data = try JSONEncoder().encode(state)
        if state.status == .finished {
            for p in match.participants {
                guard let pid = p.player?.gamePlayerID else { p.matchOutcome = .tied; continue }
                if let w = state.winnerID { p.matchOutcome = (pid == w) ? .won : .lost } else { p.matchOutcome = .tied }
            }
            try await match.endMatchInTurn(withMatch: data)
        } else {
            let next = match.participants.filter { $0.player?.gamePlayerID != localPlayerID }
            try await match.endTurn(withNextParticipants: next, turnTimeout: GKTurnTimeoutDefault, match: data)
        }
        await reload()
    }

    func rematch(_ match: GKTurnBasedMatch) async throws -> GKTurnBasedMatch {
        let m = try await match.rematch()
        await reload()
        return m
    }

    func remove(_ match: GKTurnBasedMatch) async {
        try? await match.remove()
        await reload()
    }

    // MARK: GKLocalPlayerListener

    func player(_ player: GKPlayer, receivedTurnEventFor match: GKTurnBasedMatch, didBecomeActive: Bool) {
        Task { @MainActor in
            await reload()
            if didBecomeActive { activeMatchID = match.matchID }
        }
    }

    func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch) {
        Task { @MainActor in await reload() }
    }

    func player(_ player: GKPlayer, wantsToQuitMatch match: GKTurnBasedMatch) {
        Task { @MainActor in
            try? await match.participantQuitOutOfTurn(with: .quit)
            await reload()
        }
    }
}

/// Transport for a Game Center match.
final class GameCenterTransport: MatchTransport {
    let match: GKTurnBasedMatch
    private let service = GameCenterService.shared
    private let profile: Profile

    init(match: GKTurnBasedMatch, profile: Profile) {
        self.match = match
        self.profile = profile
    }

    var activePlayerID: String { service.localPlayerID }
    var activePlayerName: String { profile.name.isEmpty ? service.localDisplayName : profile.name }
    var activePlayerWorld: World { profile.world }
    var isMyTurn: Bool { service.isMyTurn(match) }
    var isPassAndPlay: Bool { false }

    func submitTurn(_ state: MatchState) async throws { try await service.submit(state, to: match) }
    func save(_ state: MatchState) async throws { try await service.save(state, to: match) }
}

// MARK: - Game Center UI wrappers

/// Presents any UIKit controller Game Center hands us (sign-in, matchmaker).
struct GameCenterControllerPresenter: UIViewControllerRepresentable {
    let controller: UIViewController
    func makeUIViewController(context: Context) -> UIViewController { controller }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

/// The system "pick a friend" screen for a new turn-based match.
struct MatchmakerView: UIViewControllerRepresentable {
    var mode: MatchMode = .couple
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onDismiss: onDismiss) }

    func makeUIViewController(context: Context) -> GKTurnBasedMatchmakerViewController {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        request.inviteMessage = mode == .teams ? "Think your couple knows more than ours? Prove it." : "Think you know my world? Prove it."
        let vc = GKTurnBasedMatchmakerViewController(matchRequest: request)
        vc.turnBasedMatchmakerDelegate = context.coordinator
        vc.showExistingMatches = false
        return vc
    }

    func updateUIViewController(_ uiViewController: GKTurnBasedMatchmakerViewController, context: Context) {}

    final class Coordinator: NSObject, GKTurnBasedMatchmakerViewControllerDelegate {
        let onDismiss: () -> Void
        init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }
        func turnBasedMatchmakerViewControllerWasCancelled(_ viewController: GKTurnBasedMatchmakerViewController) { onDismiss() }
        func turnBasedMatchmakerViewController(_ viewController: GKTurnBasedMatchmakerViewController, didFailWithError error: Error) { onDismiss() }
    }
}

extension GKTurnBasedMatch: @retroactive Identifiable {
    public var id: String { matchID }
}
