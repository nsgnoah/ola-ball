import Foundation
import Observation

/// Pass-and-play matches live on this phone only.
@Observable
final class LocalMatchStore {
    private static let key = "ola.localMatches.v1"
    private(set) var matches: [String: MatchState] = [:]   // keyed by a local id

    init() { load() }

    func create(me: Profile, partnerName: String, partnerWorld: World) -> String {
        let id = UUID().uuidString
        var state = MatchState(seed: UInt64.random(in: 0...UInt64.max), creator: .solo(id: "local-a", name: me.name, world: me.world))
        state.join(.solo(id: "local-b", name: partnerName, world: partnerWorld))
        matches[id] = state
        save()
        return id
    }

    /// Couple vs couple on one phone.
    func createTeams(ours: [(name: String, lane: World)], theirs: [(name: String, lane: World)]) -> String {
        let id = UUID().uuidString
        var state = MatchState(seed: UInt64.random(in: 0...UInt64.max), creator: .team(id: "local-a", members: ours), mode: .teams)
        state.join(.team(id: "local-b", members: theirs))
        matches[id] = state
        save()
        return id
    }

    func update(_ id: String, _ state: MatchState) {
        matches[id] = state
        save()
    }

    func delete(_ id: String) {
        matches.removeValue(forKey: id)
        save()
    }

    func reset() {
        matches = [:]
        save()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: Self.key), let m = try? JSONDecoder().decode([String: MatchState].self, from: data) {
            matches = m
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(matches) { UserDefaults.standard.set(data, forKey: Self.key) }
    }
}

/// Transport for a match played on one phone. The active player is whoever the state says holds the turn.
final class PassAndPlayTransport: MatchTransport {
    let id: String
    private let store: LocalMatchStore
    private var state: MatchState

    init(id: String, state: MatchState, store: LocalMatchStore) {
        self.id = id
        self.state = state
        self.store = store
    }

    var activePlayerID: String { state.turnPlayerID ?? state.players[0].id }
    var activePlayerName: String { state.player(activePlayerID)?.name ?? "" }
    var activePlayerWorld: World { state.player(activePlayerID)?.world ?? .his }
    var isMyTurn: Bool { true }
    var isPassAndPlay: Bool { true }

    func submitTurn(_ state: MatchState) async throws {
        self.state = state
        await MainActor.run { store.update(id, state) }
    }

    func save(_ state: MatchState) async throws {
        self.state = state
        await MainActor.run { store.update(id, state) }
    }
}
