import Foundation

/// Chooses plays for the other team, and the defense's look when the user has the ball.
enum AIPlaycaller {
    // MARK: Defense (user on offense)

    static func defenseCall<R: RandomNumberGenerator>(for s: Situation, using rng: inout R) -> DefenseCall {
        let roll = Int.random(in: 0..<100, using: &rng)
        if s.down >= 3 && s.yardsToGo >= 7 { return roll < 60 ? .playThePass : (roll < 85 ? .blitz : .balanced) }
        if s.yardsToGo <= 2 { return roll < 55 ? .stackTheBox : (roll < 80 ? .balanced : .blitz) }
        if s.inRedZone { return roll < 45 ? .stackTheBox : (roll < 80 ? .balanced : .blitz) }
        if roll < 40 { return .balanced }
        if roll < 62 { return .stackTheBox }
        if roll < 86 { return .playThePass }
        return .blitz
    }

    // MARK: Offense (user on defense)

    /// Route templates as offsets from the receiver's start. +y is downfield.
    enum Route: CaseIterable {
        case slant, out, go, curl, drag
        func points(from start: FieldPoint, towardMiddle: Float) -> [FieldPoint] {
            let m = towardMiddle // -1 or +1: direction toward the middle of the field
            switch self {
            case .slant: return [start, start + FieldPoint(0, 3), start + FieldPoint(m * 8, 11), start + FieldPoint(m * 12, 16)]
            case .out: return [start, start + FieldPoint(0, 6), start + FieldPoint(-m * 7, 7)]
            case .go: return [start, start + FieldPoint(m * 1.5, 10), start + FieldPoint(m * 2, 24)]
            case .curl: return [start, start + FieldPoint(0, 10), start + FieldPoint(m * 1.5, 8.5)]
            case .drag: return [start, start + FieldPoint(0, 4), start + FieldPoint(m * 14, 5)]
            }
        }
    }

    static func offensePlan<R: RandomNumberGenerator>(for s: Situation, against call: DefenseCall, using rng: inout R) -> PlayPlan {
        let los = Float(s.ballOn)
        let players = PlaySim.presnapPlayers(los: los, defenseCall: call)
        let roll = Int.random(in: 0..<100, using: &rng)

        // Does the AI read the defense this snap?
        let reads = Int.random(in: 0..<100, using: &rng) < 40
        var wantsPass: Bool
        if s.yardsToGo <= 2 { wantsPass = roll < 25 }
        else if s.down >= 3 && s.yardsToGo >= 7 { wantsPass = roll < 82 }
        else if s.inRedZone { wantsPass = roll < 45 }
        else { wantsPass = roll < 52 }
        if reads {
            switch call {
            case .stackTheBox: wantsPass = true
            case .playThePass: wantsPass = false
            case .blitz: wantsPass = Bool.random(using: &rng)
            case .balanced: break
            }
        }

        if !wantsPass {
            return runPlan(los: los, players: players, using: &rng)
        }
        return passPlan(los: los, players: players, against: call, reads: reads, using: &rng)
    }

    private static func runPlan<R: RandomNumberGenerator>(los: Float, players: [SimPlayer], using rng: inout R) -> PlayPlan {
        guard let rb = players.first(where: { $0.tag == "RB" }) else { return PlayPlan(ballHandlerTag: "RB", path: []) }
        let gaps: [Float] = [-8, -4.5, -1.5, 1.5, 4.5, 8]
        // Fewest defenders near the gap wins, with a little noise.
        let scored = gaps.map { g -> (Float, Float) in
            let crowd = players.filter { $0.side == .defense && $0.pos.distance(to: FieldPoint(g, los + 2)) < 4.5 }.count
            return (g, Float(crowd) + Float.random(in: 0..<0.9, using: &rng))
        }
        let gap = scored.min { $0.1 < $1.1 }!.0
        let bend: Float = gap < 0 ? -1 : 1
        let path = [rb.pos, FieldPoint(gap * 0.5, los - 2), FieldPoint(gap, los + 2), FieldPoint(gap + bend * 4, los + 9), FieldPoint(gap + bend * 7, los + 18)]
        return PlayPlan(ballHandlerTag: "RB", path: path.map { FieldPoint(max(-Field.halfWidth + 1, min(Field.halfWidth - 1, $0.x)), $0.y) })
    }

    private static func passPlan<R: RandomNumberGenerator>(los: Float, players: [SimPlayer], against call: DefenseCall, reads: Bool, using rng: inout R) -> PlayPlan {
        let tags = ["X", "Z", "Y", "TE"]
        let tag = tags[Int.random(in: 0..<tags.count, using: &rng)]
        guard let receiver = players.first(where: { $0.tag == tag }) else { return PlayPlan(ballHandlerTag: "Z", path: []) }
        var route: Route
        switch (call, reads) {
        case (.blitz, true): route = [Route.slant, .drag][Int.random(in: 0..<2, using: &rng)]
        case (.stackTheBox, true): route = [Route.go, .out, .slant][Int.random(in: 0..<3, using: &rng)]
        case (.playThePass, true): route = [Route.curl, .out, .drag][Int.random(in: 0..<3, using: &rng)]
        default: route = Route.allCases[Int.random(in: 0..<Route.allCases.count, using: &rng)]
        }
        if tag == "TE" && route == .go { route = .drag }
        let towardMiddle: Float = receiver.pos.x < 0 ? 1 : -1
        var path = route.points(from: receiver.pos, towardMiddle: towardMiddle)
        // Shorten routes near the goal line
        path = path.map { FieldPoint(max(-Field.halfWidth + 1, min(Field.halfWidth - 1, $0.x)), min(104, $0.y)) }
        return PlayPlan(ballHandlerTag: tag, path: path)
    }
}
