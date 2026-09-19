import SwiftUI

@main
struct OlaBallApp: App {
    @State private var store: ProgressStore = {
        let store = ProgressStore()
        if CommandLine.arguments.contains("-ui-testing-reset") { store.reset() }
        return store
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @Environment(ProgressStore.self) private var store

    var body: some View {
        if store.team == nil {
            TeamPickView()
        } else {
            HomeView()
        }
    }
}
