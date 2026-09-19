import SwiftUI

@main
struct OlaBallApp: App {
    @State private var profiles = ProfileStore()
    @State private var localMatches = LocalMatchStore()

    init() {
        if CommandLine.arguments.contains("-ui-testing-reset") {
            UserDefaults.standard.removeObject(forKey: "ola.profile.v1")
            UserDefaults.standard.removeObject(forKey: "ola.localMatches.v1")
        }
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
