import Foundation

/// Where the offense stands, from the offense's point of view.
/// `ballOn` is yards from the offense's own goal line: 0 = own goal line, 100 = the end zone they are attacking.
struct Situation: Codable, Equatable, Hashable {
    var down: Int
    var yardsToGo: Int
    var ballOn: Int

    static let kickoff = Situation.firstDown(at: 25)

    static func firstDown(at ballOn: Int) -> Situation {
        let spot = max(1, min(99, ballOn))
        return Situation(down: 1, yardsToGo: min(10, 100 - spot), ballOn: spot)
    }

    var yardsToEndZone: Int { 100 - ballOn }
    var isGoalToGo: Bool { yardsToGo >= yardsToEndZone }
    var fieldGoalDistance: Int { yardsToEndZone + 17 }
    var inFieldGoalRange: Bool { fieldGoalDistance <= 55 }
    var canAttemptFieldGoal: Bool { fieldGoalDistance <= 62 }
    var inRedZone: Bool { yardsToEndZone <= 20 }
    var isBackedUp: Bool { ballOn <= 10 }
    var firstDownMarker: Int { min(100, ballOn + yardsToGo) }

    var downText: String { ["1st", "2nd", "3rd", "4th"][max(0, min(3, down - 1))] }
    var distanceText: String { isGoalToGo ? "Goal" : "\(yardsToGo)" }
    var downAndDistance: String { "\(downText) & \(distanceText)" }

    /// "your 25", "midfield", "their 35"
    func spotText(own: String = "your", their: String = "their") -> String {
        if ballOn == 50 { return "midfield" }
        if ballOn < 50 { return "\(own) \(ballOn)" }
        return "\(their) \(100 - ballOn)"
    }
}
