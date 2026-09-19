import Foundation
import Observation

/// Who you are on this phone. Stored locally; Game Center supplies the real identity for online matches.
struct Profile: Codable, Equatable {
    var name: String
    var world: World
}

@Observable
final class ProfileStore {
    private static let key = "ola.profile.v1"
    var profile: Profile? {
        didSet { save() }
    }

    init(profile: Profile? = nil) {
        if let profile { self.profile = profile; return }
        if let data = UserDefaults.standard.data(forKey: Self.key), let p = try? JSONDecoder().decode(Profile.self, from: data) {
            self.profile = p
        } else {
            self.profile = nil
        }
    }

    func reset() { profile = nil }

    private func save() {
        if let profile, let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: Self.key)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.key)
        }
    }
}
