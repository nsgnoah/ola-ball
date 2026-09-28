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
        if args.contains("-ui-testing-reset") || args.contains("-ui-testing-seed") {
            // A fresh history keeps the seeded matches drawing the same questions every run.
            UserDefaults.standard.removeObject(forKey: QuestionHistory.key)
        }
        if args.contains("-ui-testing-seed") {
            // A ready-made profile and pass-and-play match, so UI tests can skip the keyboard.
            let profile = Profile(name: "Noah", world: .his)
            if let data = try? JSONEncoder().encode(profile) { UserDefaults.standard.set(data, forKey: "ola.profile.v1") }
            var state = MatchState(seed: 4242, creator: .solo(id: "local-a", name: "Noah", world: .his))
            state.join(.solo(id: "local-b", name: "Sam", world: .hers))
            var teams = MatchState(seed: 777, creator: .team(id: "local-a", members: [("Noah", .his), ("Sam", .hers)]), mode: .teams)
            teams.join(.team(id: "local-b", members: [("Alex", .his), ("Jo", .hers)]))
            if let data = try? JSONEncoder().encode(["seed-match": state, "seed-teams": teams]) { UserDefaults.standard.set(data, forKey: "ola.localMatches.v1") }
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
        Group {
            if profiles.profile == nil {
                ProfileSetupView()
            } else {
                HomeView()
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
        .background(
            // The canvas scale is measured HERE and nowhere else. RootView is always the whole
            // window; a Stage inside a half-height sheet is not, and letting one of those report
            // its geometry would shrink the entire app behind the sheet and never restore it.
            GeometryReader { geo in
                Color.clear
                    .onAppear { Viewport.shared.fit(geo.size) }
                    .onChange(of: geo.size) { _, size in Viewport.shared.fit(size) }
            }
        )
    }
}
