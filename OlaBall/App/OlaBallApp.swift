import SwiftUI

@main
struct OlaBallApp: App {
    @State private var profiles: ProfileStore = { _ = OlaBallApp.testFlagsApplied; return ProfileStore() }()
    @State private var localMatches: LocalMatchStore = { _ = OlaBallApp.testFlagsApplied; return LocalMatchStore() }()

    /// Test flags are handled once, before any store loads.
    static let testFlagsApplied: Bool = {
        let args = CommandLine.arguments
        if args.contains("-ui-testing-reset") {
            UserDefaults.standard.removeObject(forKey: "ola.profile.v1")
            UserDefaults.standard.removeObject(forKey: "ola.localMatches.v1")
        }
        if args.contains("-ui-testing-seed") {
            // A ready-made profile and pass-and-play match, so UI tests can skip the keyboard.
            let profile = Profile(name: "Noah", world: .his)
            if let data = try? JSONEncoder().encode(profile) { UserDefaults.standard.set(data, forKey: "ola.profile.v1") }
            var state = MatchState(seed: 4242, creator: MatchPlayer(id: "local-a", name: "Noah", world: .his))
            state.join(MatchPlayer(id: "local-b", name: "Sam", world: .hers))
            if let data = try? JSONEncoder().encode(["seed-match": state]) { UserDefaults.standard.set(data, forKey: "ola.localMatches.v1") }
        }
        return true
    }()

    init() {
        _ = OlaBallApp.testFlagsApplied
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(profiles)
                .environment(localMatches)
                .onAppear {
                    SoundKit.shared.start()
                    if !CommandLine.arguments.contains("-ui-testing-reset") { GameCenterService.shared.authenticate() }
                }
        }
    }
}

struct RootView: View {
    @Environment(ProfileStore.self) private var profiles

    var body: some View {
        if profiles.profile == nil {
            ProfileSetupView()
        } else {
            HomeView()
        }
    }
}
