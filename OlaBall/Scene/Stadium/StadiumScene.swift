import SceneKit
import UIKit

/// The renderer the game talks to. Same API the session and gesture view rely on:
/// lay out 22 players pre-snap, apply simulation frames, draw paths, aim the camera, fly kicks.
final class StadiumScene {
    let scene = SCNScene()
    var cameraNode: SCNNode { director.node }
    let director = CameraDirector()

    private let fieldNode: SCNNode
    private let playersRoot = SCNNode()
    private let markersRoot = SCNNode()
    private let pathRoot = SCNNode()
    private let ballNode = Effects.makeBall()
    private var rigs: [Int: PlayerRig] = [:]
    private var lastBallPos: FieldPoint = .zero
    private var celebrated = false
    private var ringsHidden = false
    private var burstAt: FieldPoint?
    private var numberPool: [Int] = []
    private var rng = SeededRNG(seed: 42)

    private(set) var userTeam: Team
    private(set) var opponentTeam: Team
    private(set) var offenseIsUser = true

    /// Multiply the simulation dt by this for bullet time.
    var timeScale: Float { director.timeScale }

    init(userTeam: Team, opponentTeam: Team) {
        self.userTeam = userTeam
        self.opponentTeam = opponentTeam
        let root = scene.rootNode
        fieldNode = StadiumBuilder.buildField(into: root, user: userTeam, opponent: opponentTeam)
        StadiumBuilder.buildGoalposts(into: root)
        StadiumBuilder.buildStands(into: root)
        StadiumBuilder.buildLightTowers(into: root)
        StadiumBuilder.buildLighting(scene: scene, root: root)
        root.addChildNode(playersRoot)
        root.addChildNode(markersRoot)
        root.addChildNode(pathRoot)
        root.addChildNode(ballNode)
        root.addChildNode(director.node)
        ballNode.position = SCNVector3(0, 0.3, 20)
    }

    // MARK: Layout

    func layOut(players: [SimPlayer], los: Float, firstDownAt: Float?, offenseIsUser: Bool) {
        self.offenseIsUser = offenseIsUser
        playersRoot.childNodes.forEach { $0.removeFromParentNode() }
        rigs.removeAll()
        celebrated = false
        ringsHidden = false
        burstAt = nil
        let offenseColor = UIColor(offenseIsUser ? userTeam.color : opponentTeam.color)
        let defenseColor = UIColor(offenseIsUser ? opponentTeam.color : userTeam.color)
        var ordinals: [Side: [Role: Int]] = [.offense: [:], .defense: [:]]
        for p in players {
            let jersey = p.side == .offense ? offenseColor : defenseColor
            let team = (p.side == .offense) == offenseIsUser ? userTeam : opponentTeam
            let ordinal = ordinals[p.side]![p.role, default: 0]
            ordinals[p.side]![p.role] = ordinal + 1
            let entry = Roster.entry(team: team, role: p.role, ordinal: ordinal)
            let skin = Art.skinTones[Int(Float.random(in: 0..<Float(Art.skinTones.count), using: &rng))]
            let showName = p.role != .offensiveLine && p.role != .defensiveLine
            let rig = PlayerRig(player: p, jersey: jersey, number: entry.number, skin: skin,
                                showRing: p.side == .offense && p.role.isEligibleBallHandler && offenseIsUser,
                                tagText: showName ? "\(p.role.shortName) · \(entry.name.uppercased())" : p.role.shortName)
            rigs[p.id] = rig
            playersRoot.addChildNode(rig.node)
        }
        let qb = players.first { $0.tag == "QB" }
        ballNode.removeAllActions()
        ballNode.isHidden = false
        ballNode.position = SCNVector3(qb?.pos.x ?? 0, 0.9, (qb?.pos.y ?? los - 5) + 0.3)
        ballNode.eulerAngles = SCNVector3(0, 0, 0)
        updateMarkers(los: los, firstDownAt: firstDownAt)
        clearPath()
    }

    func updateMarkers(los: Float, firstDownAt: Float?) {
        markersRoot.childNodes.forEach { $0.removeFromParentNode() }
        markersRoot.addChildNode(Effects.markerLine(color: Art.scrimmageBlue, z: los))
        if let fd = firstDownAt, fd < 100 {
            markersRoot.addChildNode(Effects.markerLine(color: Art.firstDownYellow, z: fd, width: 0.34))
        }
    }

    // MARK: Live frames

    func apply(_ sim: PlaySim, replay: Bool = false) {
        let dt: Float = 1.0 / 60.0
        if !ringsHidden {
            ringsHidden = true
            for rig in rigs.values {
                rig.setRingVisible(false)
                // Linemen tags are useful pre-snap; once the ball is live they're clutter.
                if rig.role == .offensiveLine || rig.role == .defensiveLine { rig.setTagVisible(false) }
            }
        }
        for p in sim.players {
            rigs[p.id]?.update(pos: p.pos, facing: p.facing, state: p.state, dt: dt)
        }
        // Ball
        let bp = sim.ballPos
        ballNode.position = SCNVector3(bp.x, max(0.3, sim.ballHeight), bp.y)
        if sim.ballInAir {
            let dir = bp - lastBallPos
            if dir != .zero {
                ballNode.eulerAngles.y = atan2(dir.x, dir.y)
                ballNode.eulerAngles.x = -0.35
            }
            ballNode.eulerAngles.z += 0.45   // spiral
        } else {
            ballNode.eulerAngles = SCNVector3(0.2, ballNode.eulerAngles.y, 0)
        }
        lastBallPos = bp

        // What the camera must keep in frame: the ball, the intended receiver until the catch, and the nearest threat.
        var subjects: [FieldPoint] = []
        var contact: Float?
        if let c = sim.carrier {
            let cp = sim.players[c].pos
            let threats = sim.players.filter { d in
                guard d.side == .defense else { return false }
                if case .blocked = d.state { return false }
                if case .stunned = d.state { return false }
                return true
            }
            if let nearest = threats.min(by: { $0.pos.distance(to: cp) < $1.pos.distance(to: cp) }) {
                contact = nearest.pos.distance(to: cp)
                if contact! < 6 { subjects.append(nearest.pos) }
            }
            if sim.plan.kind == .pass, sim.players[c].role == .quarterback,
               let receiver = sim.players.first(where: { $0.tag == sim.plan.ballHandlerTag && $0.side == .offense }) {
                subjects.append(receiver.pos)
            }
        } else if sim.ballInAir, let receiver = sim.players.first(where: { $0.tag == sim.plan.ballHandlerTag && $0.side == .offense }) {
            subjects.append(receiver.pos)
        }
        if replay {
            director.replayFollow(ball: bp, ballHeight: sim.ballHeight, dt: dt)
        } else {
            director.follow(ball: bp, ballHeight: sim.ballHeight, subjects: subjects, contactDistance: sim.isOver ? nil : contact, ballInAir: sim.ballInAir, dt: dt)
        }

        if sim.isOver {
            let touchdown = sim.events.contains(.touchdown)
            if replay { return }
            if touchdown && !celebrated {
                celebrated = true
                celebrate(at: bp)
            }
            if burstAt == nil, sim.events.contains(where: { if case .tackle = $0 { return true } else { return false } }) {
                burstAt = bp
                let burst = SCNNode()
                burst.position = SCNVector3(bp.x, 0.2, bp.y)
                burst.addParticleSystem(Effects.turfBurst())
                scene.rootNode.addChildNode(burst)
                burst.runAction(.sequence([.wait(duration: 1.5), .removeFromParentNode()]))
            }
            director.holdOnResult(focus: bp, big: touchdown)
            pathRoot.opacity = 0.4
        }
    }

    private func celebrate(at p: FieldPoint) {
        let emitter = SCNNode()
        emitter.position = SCNVector3(p.x, 3, p.y)
        let colors = [UIColor(userTeam.color), Art.gold, .white, UIColor(opponentTeam.color)]
        emitter.addParticleSystem(Effects.confetti(colors: colors))
        scene.rootNode.addChildNode(emitter)
        emitter.runAction(.sequence([.wait(duration: 5), .removeFromParentNode()]))
    }

    func beginReplayCamera(at focus: FieldPoint) {
        director.beginReplay(at: focus)
    }

    /// Pre-snap tick: keep the camera drifting so the frame feels alive.
    func idle(dt: Float) {
        director.idle(dt: dt)
    }

    // MARK: Paths and highlights

    func showPath(_ points: [FieldPoint], color: UIColor) {
        clearPath()
        pathRoot.opacity = 1
        pathRoot.addChildNode(Effects.pathRibbon(points, color: color))
    }

    func clearPath() {
        pathRoot.childNodes.forEach { $0.removeFromParentNode() }
    }

    func highlight(playerID: Int?, on: Bool) {
        for (id, rig) in rigs { rig.setRingEmphasis(on && id == playerID) }
    }

    /// Make one player's ring the obvious one (the first snap points at the running back).
    func emphasize(tag: String, among players: [SimPlayer]) {
        guard let p = players.first(where: { $0.tag == tag && $0.side == .offense }) else { return }
        rigs[p.id]?.setRingEmphasis(true)
    }

    // MARK: Camera

    func aimCamera(at focus: FieldPoint, presnap: Bool, animated: Bool) {
        if presnap {
            director.framePresnap(los: focus.y, animated: animated)
        }
        // Live framing happens inside apply(_:) with full ball information.
    }

    // MARK: Picking

    func fieldPoint(from view: SCNView, at point: CGPoint) -> FieldPoint? {
        let near = view.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 0))
        let far = view.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 1))
        let dir = SCNVector3(far.x - near.x, far.y - near.y, far.z - near.z)
        guard abs(dir.y) > 0.0001 else { return nil }
        let t = -near.y / dir.y
        guard t > 0 else { return nil }
        return FieldPoint(near.x + dir.x * t, near.z + dir.z * t)
    }

    /// The eligible offensive player under a touch: first a real hit test against the player models,
    /// then the nearest eligible player to the touched spot on the turf.
    func player(from view: SCNView, at point: CGPoint, among players: [SimPlayer]) -> SimPlayer? {
        let candidates = players.filter { $0.side == .offense && $0.role.isEligibleBallHandler }
        let hits = view.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.all.rawValue, .ignoreHiddenNodes: true, .boundingBoxOnly: true])
        for hit in hits {
            var node: SCNNode? = hit.node
            while let n = node {
                if let name = n.name, name.hasPrefix("player-"), let id = Int(name.dropFirst(7)),
                   let p = candidates.first(where: { $0.id == id }) {
                    return p
                }
                node = n.parent
            }
        }
        guard let fp = fieldPoint(from: view, at: point) else { return nil }
        return candidates.min { $0.pos.distance(to: fp) < $1.pos.distance(to: fp) }.flatMap { $0.pos.distance(to: fp) < 4.0 ? $0 : nil }
    }

    // MARK: Home screen: pre-game warm-up and a slow flyover

    private struct Warmup { let rig: PlayerRig; var angle: Float; let speed: Float; let radiusX: Float; let radiusZ: Float }
    private var warmup: [Warmup] = []
    private var homeClock: Float = 0

    /// Ten players in the home team's colors jog laps around midfield. No markers, no ball.
    func beginWarmup() {
        playersRoot.childNodes.forEach { $0.removeFromParentNode() }
        rigs.removeAll()
        warmup.removeAll()
        markersRoot.childNodes.forEach { $0.removeFromParentNode() }
        ballNode.isHidden = true
        let jersey = UIColor(userTeam.color)
        let roles: [Role] = [.quarterback, .runningBack, .wideReceiver, .wideReceiver, .tightEnd, .offensiveLine, .linebacker, .cornerback, .safety, .defensiveLine]
        var ordinals: [Role: Int] = [:]
        for (i, role) in roles.enumerated() {
            let player = SimPlayer(id: 100 + i, role: role, tag: role.shortName, pos: FieldPoint(0, 50))
            let ordinal = ordinals[role, default: 0]
            ordinals[role] = ordinal + 1
            let entry = Roster.entry(team: userTeam, role: role, ordinal: ordinal)
            let skin = Art.skinTones[Int(Float.random(in: 0..<Float(Art.skinTones.count), using: &rng))]
            let rig = PlayerRig(player: player, jersey: jersey, number: entry.number, skin: skin, showRing: false, tagText: role.shortName)
            rig.setTagVisible(false)
            playersRoot.addChildNode(rig.node)
            let angle = Float(i) / Float(roles.count) * 2 * .pi + Float.random(in: -0.2...0.2, using: &rng)
            warmup.append(Warmup(rig: rig, angle: angle, speed: Float.random(in: 4.0...5.2, using: &rng), radiusX: Float.random(in: 8...13, using: &rng), radiusZ: Float.random(in: 13...19, using: &rng)))
        }
        homeClock = 0
        tickWarmup(dt: 0)
    }

    func tickWarmup(dt: Float) {
        homeClock += dt
        for i in warmup.indices {
            let w = warmup[i]
            let r = (w.radiusX + w.radiusZ) / 2
            warmup[i].angle += w.speed / r * dt
            let a = warmup[i].angle
            let pos = FieldPoint(w.radiusX * cos(a), 34 + w.radiusZ * sin(a))
            let tangent = FieldPoint(-w.radiusX * sin(a), w.radiusZ * cos(a)).normalized
            w.rig.update(pos: pos, facing: tangent, state: .running, dt: dt)
        }
        // A slow crane pendulum behind the home end zone: sweeps about 30° each way, always looking downfield.
        let sweep = 0.55 * sin(homeClock * 0.07)
        let look = SCNVector3(0, 1, 40)
        let radius: Float = 54
        let height: Float = 24 + 4 * sin(homeClock * 0.05 + 1)
        director.node.position = SCNVector3(look.x + radius * sin(sweep), height, look.z - radius * cos(sweep))
        director.node.look(at: look)
    }

    // MARK: Kicks

    func animateKick(from los: Float, distanceYards: Float, made: Bool, punt: Bool, completion: @escaping () -> Void) {
        let start = SCNVector3(0, 0.35, los - 7)
        let endZ = punt ? los - 7 + distanceYards : Float(Field.length + Field.endZoneDepth) + (made ? 5 : 3)
        let endX: Float = made || punt ? Float.random(in: -1.5...1.5) : (Bool.random() ? -5.5 : 5.5)
        let end = SCNVector3(endX, punt ? 0.35 : (made ? 6.5 : 2.2), endZ)
        let duration: TimeInterval = punt ? 3.2 : 2.4
        ballNode.position = start
        ballNode.isHidden = false
        let ctrl = SCNVector3((start.x + end.x) / 2, punt ? 24 : 18, (start.z + end.z) / 2)
        director.framePresnap(los: los, animated: true)
        let action = SCNAction.customAction(duration: duration) { [weak self] node, elapsed in
            let t = Float(elapsed / duration)
            let x = (1 - t) * (1 - t) * start.x + 2 * (1 - t) * t * ctrl.x + t * t * end.x
            let y = (1 - t) * (1 - t) * start.y + 2 * (1 - t) * t * ctrl.y + t * t * end.y
            let z = (1 - t) * (1 - t) * start.z + 2 * (1 - t) * t * ctrl.z + t * t * end.z
            node.position = SCNVector3(x, y, z)
            node.eulerAngles.x += 0.25
            self?.director.follow(ball: FieldPoint(x, z), ballHeight: y, subjects: [], contactDistance: nil, ballInAir: true, dt: 1.0 / 60.0)
        }
        ballNode.runAction(action) { DispatchQueue.main.async(execute: completion) }
    }
}
