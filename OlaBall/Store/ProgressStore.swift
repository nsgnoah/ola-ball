import Foundation
import Observation

struct CoachRank: Equatable {
    let title: String
    let minXP: Int

    static let all: [CoachRank] = [
        CoachRank(title: "Rookie Coach", minXP: 0),
        CoachRank(title: "Assistant Coach", minXP: 250),
        CoachRank(title: "Coordinator", minXP: 700),
        CoachRank(title: "Head Coach", minXP: 1500),
        CoachRank(title: "Hall of Famer", minXP: 3000),
    ]

    static func current(for xp: Int) -> CoachRank {
        all.last { xp >= $0.minXP } ?? all[0]
    }

    static func next(after rank: CoachRank) -> CoachRank? {
        guard let i = all.firstIndex(of: rank), i + 1 < all.count else { return nil }
        return all[i + 1]
    }
}

struct Progress: Codable, Equatable {
    var teamID: String?
    var xp = 0
    var games = 0
    var wins = 0
    var losses = 0
    var ties = 0
    var touchdowns = 0
    var bestDriveYards = 0
    var seen: Set<String> = []
    var lastPlayedDay: String?
    var streak = 0
}

@Observable
final class ProgressStore {
    private static let key = "olaball.progress.v1"

    var progress: Progress {
        didSet { save() }
    }

    init(progress: Progress? = nil) {
        if let progress {
            self.progress = progress
        } else if let data = UserDefaults.standard.data(forKey: Self.key),
                  let decoded = try? JSONDecoder().decode(Progress.self, from: data) {
            self.progress = decoded
        } else {
            self.progress = Progress()
        }
    }

    var team: Team? { progress.teamID.flatMap(Team.byID) }
    var rank: CoachRank { CoachRank.current(for: progress.xp) }
    var nextRank: CoachRank? { CoachRank.next(after: rank) }
    var rankProgress: Double {
        guard let next = nextRank else { return 1 }
        let span = Double(next.minXP - rank.minXP)
        return min(1, max(0, Double(progress.xp - rank.minXP) / span))
    }
    var learnedCount: Int { progress.seen.count }
    var totalConcepts: Int { Concept.all.count }

    func setTeam(_ team: Team) { progress.teamID = team.id }

    /// Returns true if this concept was newly learned.
    @discardableResult
    func markSeen(_ id: String) -> Bool {
        progress.seen.insert(id).inserted
    }

    func addXP(_ amount: Int) { progress.xp += amount }

    enum GameResult { case win, loss, tie }

    func recordGame(result: GameResult, touchdowns: Int, bestDriveYards: Int, today: Date = Date()) {
        progress.games += 1
        switch result {
        case .win: progress.wins += 1
        case .loss: progress.losses += 1
        case .tie: progress.ties += 1
        }
        progress.touchdowns += touchdowns
        progress.bestDriveYards = max(progress.bestDriveYards, bestDriveYards)

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let todayKey = formatter.string(from: today)
        let yesterdayKey = formatter.string(from: today.addingTimeInterval(-86_400))
        if progress.lastPlayedDay == todayKey {
            // already counted today
        } else if progress.lastPlayedDay == yesterdayKey {
            progress.streak += 1
        } else {
            progress.streak = 1
        }
        progress.lastPlayedDay = todayKey
    }

    func reset() { progress = Progress() }

    private func save() {
        if let data = try? JSONEncoder().encode(progress) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}
