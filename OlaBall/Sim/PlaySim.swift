import Foundation

/// Deterministic, tick-based simulation of one football play. Pure Swift, no SceneKit.
/// Feed it a `PlayPlan` and a `DefenseCall`, call `tick` until `isOver`, read `result` and `analysis`.
struct PlaySim {
    enum Event: Equatable {
        case snap, handoff, throwStart, caught(separation: Float), incomplete, interception, sack, tackle(by: Int, broken: Bool), touchdown, outOfBounds, fumble, timeExpired
    }

    struct Analysis: Equatable {
        var defendersAtPointOfAttack = 0    // defenders near where a run hit the line
        var separationAtCatch: Float?       // yards between receiver and nearest defender when the ball arrived
        var underPressure = false           // QB threw early because a rusher was closing
        var timeToThrow: Float?
        var yardsAfterCatch: Float = 0
        var breakaway = false
    }

    // MARK: Configuration
    let los: Float
    let plan: PlayPlan
    let defenseCall: DefenseCall
    let isGoalLine: Bool
    private(set) var rng: SeededRNG

    // MARK: State
    private(set) var players: [SimPlayer]
    private(set) var time: Float = 0
    private(set) var carrier: Int?            // index of player holding the ball
    private(set) var ballPos: FieldPoint
    private(set) var ballHeight: Float = 1.0
    private(set) var ballInAir = false
    private var ballFrom: FieldPoint = .zero
    private var ballTarget: FieldPoint = .zero
    private var ballFlightTime: Float = 0
    private var ballFlightElapsed: Float = 0
    private var intendedReceiver: Int?
    private var throwDistance: Float = 0
    private var catchZ: Float?
    private(set) var events: [Event] = []
    private(set) var result: PlayResultKind?
    private(set) var analysis = Analysis()
    private var handoffDone = false
    private var throwTime: Float = -1

    var isOver: Bool { result != nil }
    var offense: [SimPlayer] { players.filter { $0.side == .offense } }
    var defense: [SimPlayer] { players.filter { $0.side == .defense } }
    var endSpot: Float { ballPos.y }

    static let maxDuration: Float = 10

    // MARK: Init

    init(los: Float, plan: PlayPlan, defenseCall: DefenseCall, seed: UInt64) {
        self.los = los
        self.plan = plan
        self.defenseCall = defenseCall
        self.isGoalLine = los >= 92
        self.rng = SeededRNG(seed: seed)
        self.players = PlaySim.lineUp(los: los, defenseCall: defenseCall, goalLine: los >= 92)
        let handler = players.first { $0.tag == plan.ballHandlerTag && $0.side == .offense }
        self.ballPos = handler?.pos ?? FieldPoint(0, los - 5)
        self.carrier = players.firstIndex { $0.tag == "QB" }
    }

    static func lineUp(los: Float, defenseCall: DefenseCall, goalLine: Bool) -> [SimPlayer] {
        var players: [SimPlayer] = []
        for slot in Lineup.offense.slots {
            players.append(SimPlayer(id: players.count, role: slot.role, tag: slot.tag, pos: FieldPoint(slot.x, los + slot.depth)))
        }
        for slot in Lineup.defense(for: defenseCall, goalLine: goalLine).slots {
            let depth = min(slot.depth, max(1, 100 - los + 8)) // don't line up in the end zone stands
            players.append(SimPlayer(id: players.count, role: slot.role, tag: slot.tag, pos: FieldPoint(slot.x, los + depth), facing: FieldPoint(0, -1)))
        }
        return players
    }

    /// Positions before the snap, for the pre-snap view.
    static func presnapPlayers(los: Float, defenseCall: DefenseCall) -> [SimPlayer] {
        lineUp(los: los, defenseCall: defenseCall, goalLine: los >= 92)
    }

    // MARK: Snap

    private var snapped = false
    private var blitzers: Set<Int> = []
    private var rushers: Set<Int> = []
    private var assignedBlocks: [Int: Int] = [:]   // rusher -> blocker

    mutating func snap() {
        guard !snapped else { return }
        snapped = true
        events.append(.snap)
        analysis.defendersAtPointOfAttack = countDefendersAtPointOfAttack()

        let handlerIndex = players.firstIndex { $0.tag == plan.ballHandlerTag && $0.side == .offense } ?? 0
        let qb = players.firstIndex { $0.tag == "QB" }!

        // Offense roles
        for i in players.indices where players[i].side == .offense {
            switch players[i].role {
            case .offensiveLine:
                players[i].state = .idle
            case .quarterback:
                players[i].state = plan.kind == .keeper ? .running : .dropping
            case .runningBack:
                players[i].state = plan.kind == .run ? .running : .idle   // stays in to block on passes
            case .wideReceiver, .tightEnd:
                players[i].state = (i == handlerIndex) ? .running : .decoy
            default: break
            }
        }
        if plan.kind == .keeper { carrier = qb; handoffDone = true }
        if plan.kind == .run { carrier = handlerIndex; handoffDone = true; events.append(.handoff) }

        // Defense roles
        let receivers = players.indices.filter { players[$0].side == .offense && (players[$0].role == .wideReceiver || players[$0].role == .tightEnd) }
        var takenReceivers: Set<Int> = []
        for i in players.indices where players[i].side == .defense {
            switch players[i].role {
            case .defensiveLine:
                rushers.insert(i)
                players[i].state = .rushing
            case .linebacker:
                if defenseCall == .blitz && abs(players[i].pos.x) < 6 {
                    rushers.insert(i); blitzers.insert(i)
                    players[i].state = .rushing
                } else {
                    players[i].state = .zone(FieldPoint(players[i].pos.x, los + 7))
                }
            case .cornerback:
                // Man coverage: nearest uncovered receiver by x
                let nearest = receivers.filter { !takenReceivers.contains($0) }.min { abs(players[$0].pos.x - players[i].pos.x) < abs(players[$1].pos.x - players[i].pos.x) }
                if let r = nearest { takenReceivers.insert(r); players[i].state = .covering(receiver: r) } else { players[i].state = .zone(players[i].pos) }
            case .safety:
                players[i].state = (defenseCall == .stackTheBox && players[i].pos.y - los < 8) ? .zone(FieldPoint(players[i].pos.x, los + 5)) : .deep
            default: break
            }
        }
        // Any receiver left uncovered is picked up by the nearest zone linebacker later (naturally, via zone logic).

        // Blocking assignments: OL (+TE, +RB on passes) take the nearest rushers.
        var blockers = players.indices.filter { players[$0].side == .offense && players[$0].role == .offensiveLine }
        if plan.ballHandlerTag != "TE", let te = players.firstIndex(where: { $0.tag == "TE" }) { blockers.append(te); players[te].state = .idle }
        if plan.kind != .run, let rb = players.firstIndex(where: { $0.tag == "RB" }) { blockers.append(rb) }
        var freeRushers = Array(rushers)
        for b in blockers {
            guard !freeRushers.isEmpty else { break }
            let bx = players[b].pos.x
            let idx = freeRushers.indices.min { abs(players[freeRushers[$0]].pos.x - bx) < abs(players[freeRushers[$1]].pos.x - bx) }!
            let r = freeRushers.remove(at: idx)
            assignedBlocks[r] = b
            players[b].state = .blocking(rusher: r)
            var holdTime = Float.random(in: 1.4...3.0, using: &rng) * (players[b].role == .offensiveLine ? 1.0 : 0.65)
            if blitzers.contains(r) { holdTime *= 0.6 }
            players[r].state = .blocked(until: holdTime)
        }
    }

    private func countDefendersAtPointOfAttack() -> Int {
        // Where the path crosses the line of scrimmage (or its first point past it).
        guard plan.kind != .pass, let cross = plan.path.first(where: { $0.y >= los + 0.5 }) ?? plan.path.last else { return 0 }
        return players.filter { $0.side == .defense && $0.pos.distance(to: FieldPoint(cross.x, los + 2)) < 4.5 }.count
    }

    // MARK: Tick

    mutating func tick(_ dt: Float) {
        guard !isOver else { return }
        if !snapped { snap() }
        time += dt
        for i in players.indices { recordHistory(i) }
        updateOffense(dt)
        updateDefense(dt)
        updateBall(dt)
        checkEndConditions()
        if time >= PlaySim.maxDuration, result == nil {
            events.append(.timeExpired)
            finishRun()
        }
    }

    private mutating func recordHistory(_ i: Int) {
        players[i].history.append(players[i].pos)
        if players[i].history.count > 12 { players[i].history.removeFirst() }   // ~0.4 s at 30 Hz
    }

    // MARK: Offense

    private mutating func updateOffense(_ dt: Float) {
        for i in players.indices where players[i].side == .offense {
            switch players[i].state {
            case .running:
                moveAlongPath(i, dt: dt)
            case .decoy:
                // Run a lazy go route to occupy the defender.
                let target = FieldPoint(players[i].pos.x, min(99, los + 14))
                move(i, toward: target, dt: dt, speedScale: 0.85)
            case .dropping:
                let target = FieldPoint(players[i].pos.x, los - 7.5)
                if players[i].pos.distance(to: target) > 0.2 { move(i, toward: target, dt: dt, speedScale: 0.8) }
                maybeThrow()
            case .blocking(let r):
                // Shuffle to stay between rusher and QB
                let rp = players[r].pos
                let anchor = FieldPoint(rp.x, min(rp.y, los - 0.5))
                move(i, toward: anchor, dt: dt, speedScale: 0.6)
            default: break
            }
        }
    }

    private mutating func moveAlongPath(_ i: Int, dt: Float) {
        let speed = players[i].role.speed * min(1, 0.35 + time / 1.1)
        if ballInAir, intendedReceiver == i {
            // Go get the ball and settle under it.
            let d = players[i].pos.distance(to: ballTarget)
            if d > 0.25 { move(i, toward: ballTarget, dt: dt) } else { players[i].pos = ballTarget }
            return
        }
        var remaining = speed * dt
        while remaining > 0 {
            let idx = players[i].pathIndex
            if idx < plan.path.count {
                let target = plan.path[idx]
                let d = players[i].pos.distance(to: target)
                if d <= remaining {
                    players[i].pos = target
                    players[i].pathIndex += 1
                    remaining -= d
                } else {
                    let dir = (target - players[i].pos).normalized
                    players[i].pos += dir * remaining
                    players[i].facing = dir
                    remaining = 0
                }
            } else {
                // Path finished: keep going downfield, bending gently away from the nearest defender.
                var dir = FieldPoint(0, 1)
                if let nearest = nearestDefender(to: players[i].pos), nearest.dist < 4 {
                    let away = (players[i].pos - nearest.pos).normalized
                    dir = (dir + away * 0.35).normalized
                }
                players[i].pos += dir * remaining
                players[i].facing = dir
                remaining = 0
            }
        }
        if carrier == i { ballPos = players[i].pos }
    }

    private mutating func move(_ i: Int, toward target: FieldPoint, dt: Float, speedScale: Float = 1) {
        let dir = (target - players[i].pos).normalized
        let step = players[i].role.speed * speedScale * dt
        let d = players[i].pos.distance(to: target)
        if d <= step { players[i].pos = target } else { players[i].pos += dir * step }
        if dir != .zero { players[i].facing = dir }
    }

    private func nearestDefender(to p: FieldPoint, excludingBlocked: Bool = true) -> (index: Int, pos: FieldPoint, dist: Float)? {
        var best: (Int, FieldPoint, Float)?
        for i in players.indices where players[i].side == .defense {
            if excludingBlocked, case .blocked = players[i].state { continue }
            if case .stunned = players[i].state { continue }
            let d = players[i].pos.distance(to: p)
            if best == nil || d < best!.2 { best = (i, players[i].pos, d) }
        }
        return best
    }

    // MARK: Passing

    private mutating func maybeThrow() {
        guard plan.kind == .pass, !ballInAir, !handoffDone, let qb = carrier else { return }
        guard let receiver = players.firstIndex(where: { $0.tag == plan.ballHandlerTag && $0.side == .offense }) else { return }
        let remainingRoute = remainingPathLength(receiver)
        let routeProgress = plan.pathLength > 0 ? 1 - remainingRoute / plan.pathLength : 1
        let routeDone = remainingRoute <= 0.01
        let pressure = nearestDefender(to: players[qb].pos)?.dist ?? 99
        let mustThrow = pressure < 2.6 && routeProgress > 0.25
        let ready = routeProgress >= 0.6 || routeDone
        let tooLong = time > 3.4
        guard ready || mustThrow || tooLong else { return }

        analysis.underPressure = mustThrow && !ready
        analysis.timeToThrow = time
        // Lead the receiver: aim where they will be when the ball arrives.
        ballFrom = players[qb].pos
        var target = players[receiver].pos
        var flight: Float = 0.6
        for _ in 0..<3 {
            target = projectedPosition(of: receiver, after: flight)
            throwDistance = ballFrom.distance(to: target)
            flight = max(0.45, throwDistance / 24)
        }
        ballTarget = FieldPoint(max(-Field.halfWidth + 0.5, min(Field.halfWidth - 0.5, target.x)), min(108, target.y))
        throwDistance = ballFrom.distance(to: ballTarget)
        ballFlightTime = flight
        ballFlightElapsed = 0
        ballInAir = true
        intendedReceiver = receiver
        carrier = nil
        handoffDone = true
        events.append(.throwStart)
        throwTime = time
        // Zone and deep defenders break on the ball after a beat; man defenders stay glued to their receiver.
        for i in players.indices where players[i].side == .defense {
            switch players[i].state {
            case .zone, .deep: players[i].state = .zone(ballTarget)
            default: break
            }
        }
    }

    private func remainingPathLength(_ i: Int) -> Float {
        var total: Float = 0
        var last = players[i].pos
        var idx = players[i].pathIndex
        while idx < plan.path.count {
            total += last.distance(to: plan.path[idx])
            last = plan.path[idx]
            idx += 1
        }
        return total
    }

    /// Where a receiver will be after `seconds` if they keep running their route, then straight downfield.
    private func projectedPosition(of i: Int, after seconds: Float) -> FieldPoint {
        var budget = players[i].role.speed * seconds
        var pos = players[i].pos
        var idx = players[i].pathIndex
        while budget > 0 {
            if idx < plan.path.count {
                let d = pos.distance(to: plan.path[idx])
                if d <= budget { budget -= d; pos = plan.path[idx]; idx += 1 }
                else { pos += (plan.path[idx] - pos).normalized * budget; budget = 0 }
            } else {
                pos += FieldPoint(0, budget * 0.7)   // receivers slow down after the route
                budget = 0
            }
        }
        return pos
    }

    private mutating func updateBall(_ dt: Float) {
        guard ballInAir else {
            if let c = carrier { ballPos = players[c].pos; ballHeight = 1 }
            return
        }
        ballFlightElapsed += dt
        let t = min(1, ballFlightElapsed / ballFlightTime)
        ballPos = ballFrom + (ballTarget - ballFrom) * t
        let peak = min(9, 2 + throwDistance * 0.18)
        ballHeight = 1.5 + peak * 4 * t * (1 - t)
        if t >= 1 { resolveCatch() }
    }

    private mutating func resolveCatch() {
        ballInAir = false
        guard let r = intendedReceiver else { result = .incomplete; return }
        let receiverDist = players[r].pos.distance(to: ballTarget)
        let nearest = nearestDefender(to: players[r].pos, excludingBlocked: true)
        let separation = nearest?.dist ?? 10
        analysis.separationAtCatch = separation

        var pComplete: Float
        switch separation {
        case 3...: pComplete = 0.93
        case 2..<3: pComplete = 0.8
        case 1..<2: pComplete = 0.55
        default: pComplete = 0.28
        }
        if receiverDist > 2.5 { pComplete -= 0.35 }          // receiver wasn't where the ball went
        if throwDistance > 25 { pComplete -= (throwDistance - 25) * 0.01 }
        if analysis.underPressure { pComplete -= 0.15 }
        pComplete = max(0.05, min(0.97, pComplete))

        let roll = Float.random(in: 0..<1, using: &rng)
        if roll < pComplete {
            events.append(.caught(separation: separation))
            carrier = r
            players[r].pos = ballTarget
            ballPos = ballTarget
            catchZ = ballTarget.y
            if Field.isOutOfBounds(ballTarget) { result = .incomplete; events.append(.incomplete); return }
            if ballTarget.y >= 100 { events.append(.touchdown); result = .gain(Int((100 - los).rounded())); return }
            // Defenders converge
            for i in players.indices where players[i].side == .defense {
                if case .blocked = players[i].state { continue }
                players[i].state = .pursuing
            }
        } else {
            let pInt: Float = separation < 1 ? 0.3 : (separation < 2 ? 0.12 : 0.03)
            if Float.random(in: 0..<1, using: &rng) < pInt {
                events.append(.interception)
                result = .interception
            } else {
                events.append(.incomplete)
                result = .incomplete
            }
        }
    }

    // MARK: Defense

    private mutating func updateDefense(_ dt: Float) {
        let carrierPos = carrier.map { players[$0].pos }
        let carrierFacing = carrier.map { players[$0].facing } ?? .zero
        let runIsOn = handoffDone && !ballInAir && carrier != nil && plan.kind != .pass
        let ballCrossedLine = (carrierPos?.y ?? -100) > los + 0.5

        for i in players.indices where players[i].side == .defense {
            switch players[i].state {
            case .blocked(let until):
                // Pinned to the blocker; wriggle a little.
                if let b = assignedBlocks[i] {
                    let anchor = players[b].pos + FieldPoint(0, 1.0)
                    move(i, toward: anchor, dt: dt, speedScale: 0.5)
                }
                if time >= until { players[i].state = (carrier != nil && handoffDone && !ballInAir) ? .pursuing : .rushing }
            case .stunned(let until):
                if time >= until { players[i].state = .pursuing }
            case .rushing:
                if ballInAir { players[i].state = .pursuing; continue }
                if let c = carrier {
                    let target = players[c].pos + carrierFacing * 0.3
                    move(i, toward: target, dt: dt)
                }
            case .zone(let landmark):
                if ballInAir {
                    if time > throwTime + 0.3 { move(i, toward: ballTarget, dt: dt, speedScale: 0.95) }
                    continue
                }
                if runIsOn && (ballCrossedLine || time > 0.35) {
                    players[i].state = .pursuing; continue
                }
                if plan.kind == .keeper && time > 0.35 { players[i].state = .pursuing; continue }
                // Hold the landmark, drift toward a receiver entering the area.
                var target = landmark
                if let r = nearestReceiver(to: players[i].pos), r.dist < 7, plan.kind == .pass {
                    target = (r.pos + landmark) * 0.5
                }
                move(i, toward: target, dt: dt, speedScale: 0.8)
            case .covering(let r):
                if ballInAir {
                    // Read the throw: after a beat, break on the ball if it's coming toward my man.
                    if time > throwTime + 0.35 && intendedReceiver == r { move(i, toward: ballTarget, dt: dt, speedScale: 0.98); continue }
                }
                if runIsOn && ballCrossedLine && time > 0.8 { players[i].state = .pursuing; continue }
                // Follow the receiver with reaction lag, keeping a cushion on the deep side.
                let lagged = players[r].history.first ?? players[r].pos
                let cushion: Float = max(0.6, 2.2 - time * 0.5)
                let target = FieldPoint(lagged.x, lagged.y + cushion)
                move(i, toward: target, dt: dt, speedScale: 0.96)
            case .deep:
                if ballInAir { move(i, toward: ballTarget, dt: dt); continue }
                if runIsOn && (ballCrossedLine || time > 0.7) { players[i].state = .pursuing; continue }
                // Stay over the top of the deepest receiver on this half.
                let half: Float = players[i].pos.x < 0 ? -1 : 1
                let deepest = players.filter { $0.side == .offense && ($0.role == .wideReceiver || $0.role == .tightEnd) && ($0.pos.x * half >= -3) }.max { $0.pos.y < $1.pos.y }
                let want = FieldPoint(deepest?.pos.x ?? players[i].pos.x * 0.5, max((deepest?.pos.y ?? los) + 6, los + 10))
                move(i, toward: FieldPoint(want.x * 0.7 + players[i].pos.x * 0.3, min(want.y, 105)), dt: dt, speedScale: 0.85)
            case .pursuing:
                if ballInAir { move(i, toward: ballTarget, dt: dt, speedScale: 0.9); continue }
                guard let c = carrier else { continue }
                let dist = players[i].pos.distance(to: players[c].pos)
                let lead = dist < 3 ? .zero : players[c].facing * players[c].role.speed * 0.3
                move(i, toward: players[c].pos + lead, dt: dt, speedScale: 1.1)
            default: break
            }
        }
    }

    private func nearestReceiver(to p: FieldPoint) -> (index: Int, pos: FieldPoint, dist: Float)? {
        var best: (Int, FieldPoint, Float)?
        for i in players.indices where players[i].side == .offense && (players[i].role == .wideReceiver || players[i].role == .tightEnd || players[i].role == .runningBack) {
            let d = players[i].pos.distance(to: p)
            if best == nil || d < best!.2 { best = (i, players[i].pos, d) }
        }
        return best
    }

    // MARK: End conditions

    private mutating func checkEndConditions() {
        guard result == nil, let c = carrier, !ballInAir else { return }
        let p = players[c].pos

        // Sack: rusher reaches the QB before the throw.
        if plan.kind == .pass, !handoffDone, players[c].role == .quarterback {
            if let n = nearestDefender(to: p), n.dist < 1.0 {
                events.append(.sack)
                let loss = max(1, Int((los - p.y).rounded()))
                result = .sack(loss)
                players[c].state = .down
                return
            }
            return
        }

        guard handoffDone else { return }
        if p.y >= 100 { events.append(.touchdown); result = .gain(Int((100 - los).rounded())); return }
        if Field.isOutOfBounds(p) { events.append(.outOfBounds); finishRun(); return }

        // Tackle
        let closeDefenders = players.indices.filter { i in
            guard players[i].side == .defense else { return false }
            if case .blocked = players[i].state { return false }
            if case .stunned = players[i].state { return false }
            return players[i].pos.distance(to: p) < 1.5
        }
        guard let tackler = closeDefenders.first else { return }
        let gang = players.filter { $0.side == .defense && $0.pos.distance(to: p) < 2.2 }.count >= 2
        let breakChance: Float = gang ? 0.02 : (players[c].role == .runningBack ? 0.12 : 0.07)
        if Float.random(in: 0..<1, using: &rng) < breakChance {
            events.append(.tackle(by: tackler, broken: true))
            players[tackler].state = .stunned(until: time + 1.1)
            analysis.breakaway = true
            return
        }
        events.append(.tackle(by: tackler, broken: false))
        if Float.random(in: 0..<1, using: &rng) < 0.015 {
            events.append(.fumble)
            result = .fumble
            return
        }
        finishRun()
    }

    private mutating func finishRun() {
        guard let c = carrier else { result = .incomplete; return }
        players[c].state = .down
        let spot = max(0.5, min(99.5, players[c].pos.y))
        if let cz = catchZ { analysis.yardsAfterCatch = spot - cz }
        let gain = Int((spot - los).rounded())
        result = gain < 0 && plan.kind == .pass && catchZ == nil ? .incomplete : .gain(gain)
    }
}
