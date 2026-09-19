import Foundation

enum PlayCall: String, CaseIterable, Codable, Identifiable {
    case run, shortPass, deepPass, punt, fieldGoal

    var id: String { rawValue }

    var title: String {
        switch self {
        case .run: return "Run"
        case .shortPass: return "Short Pass"
        case .deepPass: return "Deep Pass"
        case .punt: return "Punt"
        case .fieldGoal: return "Field Goal"
        }
    }

    var subtitle: String {
        switch self {
        case .run: return "Hand it off. Safe, steady yards."
        case .shortPass: return "Quick throw. Reliable, medium gains."
        case .deepPass: return "Throw it far. Big reward, big risk."
        case .punt: return "Kick it away. Give up the ball, but far from your end zone."
        case .fieldGoal: return "Kick it through the posts for 3 points."
        }
    }

    var symbol: String {
        switch self {
        case .run: return "figure.run"
        case .shortPass: return "arrow.right"
        case .deepPass: return "arrow.up.right"
        case .punt: return "arrow.up.to.line"
        case .fieldGoal: return "target"
        }
    }

    var isKick: Bool { self == .punt || self == .fieldGoal }
}
