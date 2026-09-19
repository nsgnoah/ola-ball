import Foundation
import simd

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
    private var throwDecisionTime: Float?
    static let throwWindup: Float = 0.35
    /// How close a free rusher gets before this QB decides to get rid of the ball. Drawn once per play:
    /// some snaps the QB feels the rush early, some snaps he holds it a beat too long and eats the sack.
    private var pressureTrigger: Float = 3.4
    private var separationAtThrow: Float = 0

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
        pressureTrigger = Float.random(in: 2.8...4.4, using: &rng)

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

        // Blocking assignments. Linemen take the defensive line; blitzers are left to the tight end and running back,
        // who block for less time. Anyone still free is coming untouched.
        let linemenBlockers = players.indices.filter { players[$0].side == .offense && players[$0].role == .offensiveLine }
        var backBlockers: [Int] = []
        if plan.ballHandlerTag != "TE", let te = players.firstIndex(where: { $0.tag == "TE" }) { backBlockers.append(te); players[te].state = .idle }
        if plan.kind != .run, let rb = players.firstIndex(where: { $0.tag == "RB" }) { backBlockers.append(rb) }
        var freeRushers = Array(rushers).sorted { players[$0].pos.x < players[$1].pos.x }
        func assign(blockers: [Int], to pool: inout [Int], holdScale: Float) {
            for b in blockers {
                guard !pool.isEmpty else { break }
                let bx = players[b].pos.x
                let idx = pool.indices.min { abs(players[pool[$0]].pos.x - bx) < abs(players[pool[$1]].pos.x - bx) }!
                let r = pool.remove(at: idx)
                assignedBlocks[r] = b
                players[b].state = .blocking(rusher: r)
                players[r].state = .blocked(until: Float.random(in: 1.4...3.0, using: &rng) * holdScale)
            }
        }
        var line = freeRushers.filter { !blitzers.contains($0) }
        assign(blockers: linemenBlockers, to: &line, holdScale: 1.0)
        var leftovers = line + freeRushers.filter { blitzers.contains($0) }
        assign(blockers: backBlockers, to: &leftovers, holdScale: 0.35)
        freeRushers = leftovers

        // Run plays: the tight end and the play-side lineman climb to block the second level near the point of attack.
        // The lineman's defender gets handed to a neighbor (a combo block), which holds a little less well.
        if plan.kind == .run, let poa = plan.path.first(where: { $0.y >= los + 0.5 }) ?? plan.path.last {
            let secondLevel = players.indices.filter { i in
                // Unblocked blitzers count too: the play-side blockers pick up the one nearest the hole.
                players[i].side == .defense && (!rushers.contains(i) || leftovers.contains(i)) && (players[i].role == .linebacker || players[i].role == .safety) && players[i].pos.y - los < 9
            }.sorted { players[$0].pos.distance(to: poa) < players[$1].pos.distance(to: poa) }
            // Two blockers get up to the second level: the two nearest the point of attack out of the tight end,
            // the uncovered lineman, and the play-side linemen. A lineman who has a down lineman combos off him
            // (the neighbor takes over the block, which holds a little less well) and climbs to the linebacker
            // flowing to the hole. That's the play-side double-team-and-climb every zone run is built on, and
            // only two of them ever get up - the backside is left alone. It's what separates a run into a light
            // side from a run into a crowd.
            let linemen = players.indices.filter { players[$0].side == .offense && players[$0].role == .offensiveLine }
            var candidates: [Int] = []
            if plan.ballHandlerTag != "TE", let te = players.firstIndex(where: { $0.tag == "TE" }), !assignedBlocks.values.contains(te) { candidates.append(te) }
            candidates += linemen
            let climbers = Array(candidates.sorted { players[$0].pos.distance(to: poa) < players[$1].pos.distance(to: poa) }.prefix(2))
            for climber in climbers {
                if let (rusher, _) = assignedBlocks.first(where: { $0.value == climber }) {
                    if let neighbor = linemen.filter({ !climbers.contains($0) })
                        .min(by: { abs(players[$0].pos.x - players[climber].pos.x) < abs(players[$1].pos.x - players[climber].pos.x) }) {
                        assignedBlocks[rusher] = neighbor
                        if case .blocked(let until) = players[rusher].state { players[rusher].state = .blocked(until: until * 0.7) }
                    }
                }
            }
            // Each second-level defender (nearest to the point of attack first) gets the closest free blocker.
            var free = climbers
            for lb in secondLevel where !free.isEmpty {
                let idx = free.indices.min { players[free[$0]].pos.distance(to: players[lb].pos) < players[free[$1]].pos.distance(to: players[lb].pos) }!
                let climber = free.remove(at: idx)
                // Don't send a blocker on a hopeless 10-yard chase.
                if players[climber].pos.distance(to: players[lb].pos) < 9 { players[climber].state = .climbing(target: lb) }
            }
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
            case .climbing(let lb):
                // Run at the linebacker; on contact, tie them up for a moment.
                let d = players[i].pos.distance(to: players[lb].pos)
                if d < 2.0 {
                    switch players[lb].state {
                    case .blocked, .stunned, .down: break
                    default:
                        let hold = Float.random(in: 0.7...1.5, using: &rng)
                        players[lb].state = .blocked(until: time + hold)
                        assignedBlocks[lb] = i
                    }
                    players[i].state = .blocking(rusher: lb)
                } else {
                    // Climb to where the linebacker is going, not where he is: a lineman who chases a
                    // faster defender's current spot never gets a hand on him once he starts to flow.
                    let h = players[lb].history
                    var aim = players[lb].pos
                    if let first = h.first, h.count >= 6 {
                        let velocity = (players[lb].pos - first) / (Float(h.count) / 30)
                        aim += velocity * 0.6
                    }
                    move(i, toward: aim, dt: dt, speedScale: 1.15)
                }
            default: break
            }
        }
    }

    private mutating func moveAlongPath(_ i: Int, dt: Float) {
        let speed = players[i].role.speed * min(1, 0.35 + time / 1.1)
        if ballInAir, intendedReceiver == i {
            // Run to the catch point, pacing so the ball is caught in stride rather than waited on.
            let d = players[i].pos.distance(to: ballTarget)
            let remainingFlight = max(0.05, ballFlightTime - ballFlightElapsed)
            let pace = min(1, (d / remainingFlight) / players[i].role.speed)
            if d > 0.25 { move(i, toward: ballTarget, dt: dt, speedScale: max(0.35, pace)) } else { players[i].pos = ballTarget }
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
                if let nearest = nearestDefender(to: players[i].pos), nearest.dist < 4, nearest.pos.y > players[i].pos.y {
                    // Juke only around defenders in front; you can't sidestep someone chasing you down.
                    let away = (players[i].pos - nearest.pos).normalized
                    dir = (dir + away * 0.25).normalized
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
        // A blitzer closing fast forces an early decision even if the route hasn't developed yet.
        let mustThrow = pressure < pressureTrigger && routeProgress > 0.12
        // Real panic: someone is about to sack the QB right now. Get rid of it no matter what.
        let panic = pressure < 1.7
        // Throw on the break: once the receiver has made their last cut and taken a couple of steps into it,
        // the ball goes - that's what makes a quick slant quick. Long single-leg routes wait for 60%.
        let onFinalLeg = players[receiver].pathIndex >= plan.path.count - 1
        let ready = routeProgress >= 0.6 || routeDone || (onFinalLeg && finalLegIsACut && routeProgress >= 0.35)
        let tooLong = time > 3.4
        // Deciding to throw and getting the ball out are different moments: the throwing motion takes a beat,
        // and a rusher who arrives during the windup still gets the sack. This is where blitz sacks come from.
        if throwDecisionTime == nil {
            guard ready || mustThrow || panic || tooLong else { return }
            throwDecisionTime = time
        }
        guard time >= throwDecisionTime! + PlaySim.throwWindup - 0.001 else { return }

        analysis.underPressure = (mustThrow || panic) && !ready
        analysis.timeToThrow = time

        // Throwaway: under real panic with the route nowhere close to developed and nobody closer to open,
        // a QB eats an incompletion instead of a sack. This is the "escape valve" - sacks shouldn't dominate.
        // The throwaway needs the drop to be finished and the rusher not already on the QB; an unblocked
        // blitzer arriving in the first second and a half is a sack.
        if panic && pressure > 1.1 && time > 1.6 && routeProgress < 0.6 {
            let sep = nearestDefender(to: players[receiver].pos)?.dist ?? 10
            if sep > 2.5 {
                // Receiver's actually open enough to still throw it - fall through to a real throw below.
            } else {
                events.append(.throwStart)
                ballFrom = players[qb].pos
                ballTarget = FieldPoint(max(-Field.halfWidth + 3, min(Field.halfWidth - 3, players[qb].pos.x)), min(108, players[qb].pos.y + 14))
                throwDistance = ballFrom.distance(to: ballTarget)
                ballFlightTime = 0.5
                ballFlightElapsed = 0
                ballInAir = true
                intendedReceiver = nil
                carrier = nil
                handoffDone = true
                throwTime = time
                separationAtThrow = 10
                return
            }
        }

        separationAtThrow = nearestDefender(to: players[receiver].pos)?.dist ?? 10
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

    /// Does the route's last leg break at least ~30 degrees off the one before it? A slant or an out does;
    /// a go route that just drifts a little doesn't - the QB waits on those instead of throwing on the "break".
    private var finalLegIsACut: Bool {
        let n = plan.path.count
        guard n >= 3 else { return false }
        let a = (plan.path[n - 2] - plan.path[n - 3]).normalized
        let b = (plan.path[n - 1] - plan.path[n - 2]).normalized
        guard a != .zero, b != .zero else { return false }
        return simd_dot(a, b) < 0.87
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
        guard let r = intendedReceiver else { events.append(.incomplete); result = .incomplete; return }   // throwaway
        let receiverDist = players[r].pos.distance(to: ballTarget)
        let nearest = nearestDefender(to: players[r].pos, excludingBlocked: true)
        let actualSeparation = nearest?.dist ?? 10
        // A defender can only close so much ground during the ball's flight - roughly a couple yards
        // of net closing speed over a typical throw. This stops a defender from "teleporting" in to
        // manufacture an unfair pick on a ball that was legitimately open at release, while still letting
        // a real close-in-coverage throw (defender already tight when the ball left the hand) show up tight.
        let maxClose: Float = min(2.0, ballFlightTime * 2.2)
        let separation = max(actualSeparation, separationAtThrow - maxClose)
        analysis.separationAtCatch = separation

        var pComplete: Float
        switch separation {
        case 3...: pComplete = 0.96
        case 2..<3: pComplete = 0.84
        case 1..<2: pComplete = 0.62
        default: pComplete = 0.3
        }
        if receiverDist > 2.5 { pComplete -= 0.15 }          // receiver wasn't quite where the ball went
        if throwDistance > 32 { pComplete -= (throwDistance - 32) * 0.01 }   // only truly long throws lose accuracy
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
            // Interceptions should be rare, and essentially never happen on a ball thrown to real separation.
            // Only a genuinely smothered throw (defender right on top of the catch point) has real pick risk.
            let pInt: Float = separation < 1 ? 0.1 : (separation < 2 ? 0.035 : 0.006)
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
                    let anchor = players[b].pos + FieldPoint(0, 0.9)
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
                    // Zone defenders read the QB's eyes, so they break better than a man defender turning
                    // to find the ball - but still shouldn't erase a throw that was genuinely open.
                    if time > throwTime + 0.3 { move(i, toward: ballTarget, dt: dt, speedScale: 0.85) }
                    continue
                }
                if runIsOn && (ballCrossedLine || time > 0.7) {
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
                    // The defender was already at some separation when the ball was thrown - breaking on
                    // the exact landing spot at near-receiver speed would erase that gap for free, no
                    // matter how open the catch was at release. Keep the break realistically slower.
                    if time > throwTime + 0.35 && intendedReceiver == r { move(i, toward: ballTarget, dt: dt, speedScale: 0.87); continue }
                }
                // Corners are eyeing their receiver; they're late to a run and have to shed a block first.
                if runIsOn && ballCrossedLine && time > 1.3 { players[i].state = .pursuing; continue }
                // Follow the receiver with reaction lag, keeping a cushion on the deep side.
                // A real cornerback plays with a cushion pre-snap and it only closes gradually - it
                // shouldn't be shadow-tight within a second of the snap on every route.
                let lagged = players[r].history.first ?? players[r].pos
                let cushion: Float = max(1.2, 3.0 - time * 0.6)
                let target = FieldPoint(lagged.x, lagged.y + cushion)
                // A sharp cut by the receiver makes the defender flip their hips: half speed for a moment.
                let cutPenalty: Float = receiverJustCut(r) ? 0.5 : 0.9
                move(i, toward: target, dt: dt, speedScale: cutPenalty)
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
                // Take a real intercept angle: aim ahead of the carrier along their current heading,
                // scaled by how far away we are (close in, just tackle; far off, cut the angle hard).
                // A pure "chase the current position" pursuer never catches an equal-speed runner in a
                // straight line - it has to aim where the runner will BE, like a real defender reading the play.
                let leadTime = min(1.1, dist / max(1, players[i].role.speed))
                let lead = dist < 2.5 ? .zero : players[c].facing * players[c].role.speed * leadTime * 0.6
                // Leverage: a defender on the far side of the play has to run the alley down and across,
                // not just forward - they shouldn't beat a well-aimed cut to the opposite gap for free.
                // This is a run-fit effect at the line of scrimmage; once the carrier is in the open field
                // everybody just runs to the ball.
                let lateralGap = abs(players[i].pos.x - players[c].pos.x)
                var leverageScale: Float = 1.0
                if lateralGap > 3 && players[c].pos.y < los + 6 {
                    leverageScale -= min(0.4, (lateralGap - 3) * 0.06)
                }
                leverageScale = max(0.6, leverageScale)
                move(i, toward: players[c].pos + lead, dt: dt, speedScale: 1.1 * leverageScale)
            default: break
            }
        }
    }

    /// Did this player change direction by more than ~40 degrees within the last ~0.4 s?
    private func receiverJustCut(_ r: Int) -> Bool {
        let h = players[r].history
        guard h.count >= 12 else { return false }
        let old = (h[h.count / 2] - h[0]).normalized
        let new = (players[r].pos - h[h.count / 2]).normalized
        guard old != .zero, new != .zero else { return false }
        return simd_dot(old, new) < 0.77
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
            return players[i].pos.distance(to: p) < 1.4
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
        if Float.random(in: 0..<1, using: &rng) < 0.006 {
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
