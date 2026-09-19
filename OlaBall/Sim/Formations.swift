import Foundation

enum Side: Equatable, Hashable { case offense, defense }

enum Role: String, Codable, Hashable, CaseIterable {
    case quarterback, runningBack, wideReceiver, tightEnd, offensiveLine
    case defensiveLine, linebacker, cornerback, safety

    var side: Side {
        switch self {
        case .quarterback, .runningBack, .wideReceiver, .tightEnd, .offensiveLine: return .offense
        default: return .defense
        }
    }

    /// Can the user start a drawn play from this player?
    var isEligibleBallHandler: Bool {
        self == .quarterback || self == .runningBack || self == .wideReceiver || self == .tightEnd
    }

    var shortName: String {
        switch self {
        case .quarterback: return "QB"
        case .runningBack: return "RB"
        case .wideReceiver: return "WR"
        case .tightEnd: return "TE"
        case .offensiveLine: return "OL"
        case .defensiveLine: return "DL"
        case .linebacker: return "LB"
        case .cornerback: return "CB"
        case .safety: return "S"
        }
    }

    var plainName: String {
        switch self {
        case .quarterback: return "Quarterback"
        case .runningBack: return "Running back"
        case .wideReceiver: return "Wide receiver"
        case .tightEnd: return "Tight end"
        case .offensiveLine: return "Offensive lineman"
        case .defensiveLine: return "Defensive lineman"
        case .linebacker: return "Linebacker"
        case .cornerback: return "Cornerback"
        case .safety: return "Safety"
        }
    }

    var speed: Float {   // yards per second
        switch self {
        case .quarterback: return 6.2
        case .runningBack: return 7.6
        case .wideReceiver: return 8.0
        case .tightEnd: return 6.8
        case .offensiveLine: return 5.0
        case .defensiveLine: return 5.6
        case .linebacker: return 6.8
        case .cornerback: return 7.9
        case .safety: return 7.6
        }
    }
}

/// What the defense is showing before the snap. The user's defensive call when on defense;
/// the AI's choice when the user has the ball.
enum DefenseCall: String, CaseIterable, Codable, Identifiable {
    case stackTheBox, balanced, playThePass, blitz

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stackTheBox: return "Stack the Box"
        case .balanced: return "Balanced"
        case .playThePass: return "Play the Pass"
        case .blitz: return "Blitz"
        }
    }

    var subtitle: String {
        switch self {
        case .stackTheBox: return "Crowd the line. Stuffs runs, but leaves receivers alone deep."
        case .balanced: return "A little of everything. No big weakness, no big strength."
        case .playThePass: return "Two safeties deep. Great against throws, soft against runs."
        case .blitz: return "Send extra rushers at the quarterback. Sacks, or a big play if they miss."
        }
    }

    /// What the offense sees written on the screen before the snap.
    var callout: String {
        switch self {
        case .stackTheBox: return "Defense shows 8 in the box"
        case .balanced: return "Defense in a balanced look, 7 in the box"
        case .playThePass: return "Two safeties deep, only 6 in the box"
        case .blitz: return "Linebackers creeping up. Blitz coming?"
        }
    }

    var symbol: String {
        switch self {
        case .stackTheBox: return "rectangle.stack.fill"
        case .balanced: return "scale.3D"
        case .playThePass: return "umbrella.fill"
        case .blitz: return "bolt.fill"
        }
    }
}

struct Lineup {
    struct Slot { let role: Role; let x: Float; let depth: Float; let tag: String }
    let slots: [Slot]

    /// Shotgun spread: QB and RB in the backfield, three receivers plus a tight end.
    static let offense = Lineup(slots: [
        Slot(role: .offensiveLine, x: -4.0, depth: -1.0, tag: "LT"),
        Slot(role: .offensiveLine, x: -2.0, depth: -1.0, tag: "LG"),
        Slot(role: .offensiveLine, x: 0.0, depth: -1.0, tag: "C"),
        Slot(role: .offensiveLine, x: 2.0, depth: -1.0, tag: "RG"),
        Slot(role: .offensiveLine, x: 4.0, depth: -1.0, tag: "RT"),
        Slot(role: .tightEnd, x: 6.5, depth: -1.0, tag: "TE"),
        Slot(role: .quarterback, x: 0.0, depth: -5.5, tag: "QB"),
        Slot(role: .runningBack, x: -3.0, depth: -5.5, tag: "RB"),
        Slot(role: .wideReceiver, x: -10.5, depth: -1.0, tag: "X"),
        Slot(role: .wideReceiver, x: 10.5, depth: -1.0, tag: "Z"),
        Slot(role: .wideReceiver, x: -7.5, depth: -2.5, tag: "Y"),
    ])

    static func defense(for call: DefenseCall, goalLine: Bool) -> Lineup {
        if goalLine {
            return Lineup(slots: [
                Slot(role: .defensiveLine, x: -5, depth: 1, tag: "DE"), Slot(role: .defensiveLine, x: -2.5, depth: 1, tag: "DT"),
                Slot(role: .defensiveLine, x: 0, depth: 1, tag: "NT"), Slot(role: .defensiveLine, x: 2.5, depth: 1, tag: "DT"),
                Slot(role: .defensiveLine, x: 5, depth: 1, tag: "DE"),
                Slot(role: .linebacker, x: -4, depth: 3.5, tag: "LB"), Slot(role: .linebacker, x: 0, depth: 3.5, tag: "LB"),
                Slot(role: .linebacker, x: 4, depth: 3.5, tag: "LB"),
                Slot(role: .cornerback, x: -11.5, depth: 4, tag: "CB"), Slot(role: .cornerback, x: 11.5, depth: 4, tag: "CB"),
                Slot(role: .safety, x: -7, depth: 7, tag: "S"),
            ])
        }
        switch call {
        case .balanced:
            return Lineup(slots: [
                Slot(role: .defensiveLine, x: -5.5, depth: 1, tag: "DE"), Slot(role: .defensiveLine, x: -1.5, depth: 1, tag: "DT"),
                Slot(role: .defensiveLine, x: 1.5, depth: 1, tag: "DT"), Slot(role: .defensiveLine, x: 5.5, depth: 1, tag: "DE"),
                Slot(role: .linebacker, x: -5, depth: 5, tag: "LB"), Slot(role: .linebacker, x: 0, depth: 5.5, tag: "LB"),
                Slot(role: .linebacker, x: 5, depth: 5, tag: "LB"),
                Slot(role: .cornerback, x: -11.5, depth: 7, tag: "CB"), Slot(role: .cornerback, x: 11.5, depth: 7, tag: "CB"),
                Slot(role: .safety, x: -8.5, depth: 13, tag: "S"), Slot(role: .safety, x: 8.5, depth: 13, tag: "S"),
            ])
        case .stackTheBox:
            return Lineup(slots: [
                Slot(role: .defensiveLine, x: -5.5, depth: 1, tag: "DE"), Slot(role: .defensiveLine, x: -1.5, depth: 1, tag: "DT"),
                Slot(role: .defensiveLine, x: 1.5, depth: 1, tag: "DT"), Slot(role: .defensiveLine, x: 5.5, depth: 1, tag: "DE"),
                Slot(role: .linebacker, x: -6, depth: 4, tag: "LB"), Slot(role: .linebacker, x: -1, depth: 4.5, tag: "LB"),
                Slot(role: .linebacker, x: 4, depth: 4, tag: "LB"),
                Slot(role: .safety, x: 8, depth: 5, tag: "S"),       // safety walked into the box
                Slot(role: .cornerback, x: -11.5, depth: 6, tag: "CB"), Slot(role: .cornerback, x: 11.5, depth: 6, tag: "CB"),
                Slot(role: .safety, x: 0, depth: 15, tag: "S"),
            ])
        case .playThePass:
            return Lineup(slots: [
                Slot(role: .defensiveLine, x: -5.5, depth: 1, tag: "DE"), Slot(role: .defensiveLine, x: -1.5, depth: 1, tag: "DT"),
                Slot(role: .defensiveLine, x: 1.5, depth: 1, tag: "DT"), Slot(role: .defensiveLine, x: 5.5, depth: 1, tag: "DE"),
                Slot(role: .linebacker, x: -3, depth: 6, tag: "LB"), Slot(role: .linebacker, x: 3, depth: 6, tag: "LB"),
                Slot(role: .cornerback, x: -11.5, depth: 8, tag: "CB"), Slot(role: .cornerback, x: 11.5, depth: 8, tag: "CB"),
                Slot(role: .cornerback, x: -7.5, depth: 7, tag: "NB"),
                Slot(role: .safety, x: -8.5, depth: 15, tag: "S"), Slot(role: .safety, x: 8.5, depth: 15, tag: "S"),
            ])
        case .blitz:
            return Lineup(slots: [
                Slot(role: .defensiveLine, x: -5.5, depth: 1, tag: "DE"), Slot(role: .defensiveLine, x: -1.5, depth: 1, tag: "DT"),
                Slot(role: .defensiveLine, x: 1.5, depth: 1, tag: "DT"), Slot(role: .defensiveLine, x: 5.5, depth: 1, tag: "DE"),
                Slot(role: .linebacker, x: -3.5, depth: 2.5, tag: "LB"), Slot(role: .linebacker, x: 3.5, depth: 2.5, tag: "LB"),
                Slot(role: .linebacker, x: 8, depth: 3, tag: "LB"),
                Slot(role: .cornerback, x: -11.5, depth: 5, tag: "CB"), Slot(role: .cornerback, x: 11.5, depth: 5, tag: "CB"),
                Slot(role: .cornerback, x: -7.5, depth: 5, tag: "NB"),
                Slot(role: .safety, x: 0, depth: 14, tag: "S"),
            ])
        }
    }
}
