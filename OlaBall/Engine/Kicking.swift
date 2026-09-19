import Foundation

enum Kicking {
    static func fieldGoalProbability(distance: Int) -> Double {
        switch distance {
        case ..<31: return 0.96
        case 31...40: return 0.87
        case 41...50: return 0.72
        case 51...55: return 0.55
        case 56...62: return 0.30
        default: return 0.10
        }
    }

    /// Width of the kick meter's green zone (0...1). Skill replaces luck for the user's kicks.
    static func meterTargetWidth(distance: Int) -> Double {
        max(0.08, fieldGoalProbability(distance: distance) * 0.55)
    }

    static func oddsText(distance: Int) -> String {
        switch fieldGoalProbability(distance: distance) {
        case 0.9...: return "almost automatic"
        case 0.8...: return "likely"
        case 0.65...: return "decent odds"
        case 0.45...: return "coin flip"
        default: return "long shot"
        }
    }

    /// Net punt yards from meter accuracy (0 = perfect).
    static func puntDistance(accuracy: Double) -> Int {
        Int((30 + 25 * (1 - accuracy)).rounded())
    }
}
