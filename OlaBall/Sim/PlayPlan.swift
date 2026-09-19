import Foundation

/// What the offense intends: who gets the ball and the path they run. Drawn by the user or chosen by the AI.
struct PlayPlan: Equatable {
    enum Kind: String { case run, pass, keeper }

    let ballHandlerTag: String     // "RB", "X", "Z", "Y", "TE", "QB"
    let path: [FieldPoint]         // world coordinates, first point is the player's start

    var kind: Kind {
        switch ballHandlerTag {
        case "RB": return .run
        case "QB": return .keeper
        default: return .pass
        }
    }

    var pathLength: Float {
        guard path.count > 1 else { return 0 }
        var total: Float = 0
        for i in 1..<path.count { total += path[i].distance(to: path[i - 1]) }
        return total
    }

    static func == (a: PlayPlan, b: PlayPlan) -> Bool {
        a.ballHandlerTag == b.ballHandlerTag && a.path == b.path
    }
}

struct SimPlayer: Identifiable {
    enum State: Equatable {
        case idle
        case blocking(rusher: Int)           // offense: engaged with a defender
        case running                          // following the plan path
        case decoy                            // receivers not in the plan
        case dropping                         // QB dropping back to throw
        case blocked(until: Float)           // defense: held up by a blocker
        case rushing                          // defense: going after the QB / ball
        case covering(receiver: Int)          // defense: man coverage
        case zone(FieldPoint)                 // defense: hold a landmark
        case deep                             // safety: stay over the top
        case pursuing                         // defense: chase the carrier
        case stunned(until: Float)            // defense: broke a tackle attempt on them
        case down                             // play over for this player
    }

    let id: Int
    let role: Role
    let tag: String
    var pos: FieldPoint
    var facing: FieldPoint = FieldPoint(0, 1)
    var state: State = .idle
    var pathIndex = 0
    var history: [FieldPoint] = []   // recent positions, for coverage lag

    var side: Side { role.side }
}
