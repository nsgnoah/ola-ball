import SceneKit
import UIKit

/// Builds and updates the 3D field: turf, players, ball, goalposts, the drawn path, and a broadcast camera.
final class FieldScene {
    let scene = SCNScene()
    let cameraNode = SCNNode()
    private let fieldNode = SCNNode()
    private var playerNodes: [Int: SCNNode] = [:]
    private let ballNode = SCNNode()
    private let pathNode = SCNNode()
    private let losNode = SCNNode()
    private let firstDownNode = SCNNode()
    private let rootPlayers = SCNNode()
    private let cameraTarget = SCNNode()

    private(set) var userTeam: Team
    private(set) var opponentTeam: Team
    /// Which team is on offense right now (drives are always rendered moving toward +z).
    private(set) var offenseIsUser = true

    init(userTeam: Team, opponentTeam: Team) {
        self.userTeam = userTeam
        self.opponentTeam = opponentTeam
        buildField()
        buildGoalposts()
        buildLights()
        buildBall()
        scene.rootNode.addChildNode(rootPlayers)
        scene.rootNode.addChildNode(pathNode)
        scene.rootNode.addChildNode(losNode)
        scene.rootNode.addChildNode(firstDownNode)
        scene.rootNode.addChildNode(cameraTarget)

        let camera = SCNCamera()
        camera.fieldOfView = 65
        camera.projectionDirection = .vertical
        camera.zNear = 0.5
        camera.zFar = 400
        cameraNode.camera = camera
        scene.rootNode.addChildNode(cameraNode)
        scene.background.contents = UIColor(red: 0.04, green: 0.06, blue: 0.11, alpha: 1)
        scene.fogColor = UIColor(red: 0.04, green: 0.06, blue: 0.11, alpha: 1)
        scene.fogStartDistance = 90
        scene.fogEndDistance = 220
    }

    // MARK: Building

    private func buildField() {
        let totalLength = CGFloat(Field.length + Field.endZoneDepth * 2)
        let plane = SCNPlane(width: CGFloat(Field.width + 12), height: totalLength + 12)
        let material = SCNMaterial()
        material.diffuse.contents = FieldTexture.image(userColor: userTeam.color, opponentColor: opponentTeam.color, userAbbrev: userTeam.abbreviation, opponentAbbrev: opponentTeam.abbreviation)
        material.lightingModel = .physicallyBased
        material.roughness.contents = 0.95
        material.metalness.contents = 0.0
        material.isDoubleSided = false
        plane.materials = [material]
        fieldNode.geometry = plane
        fieldNode.eulerAngles.x = -.pi / 2
        // Texture covers -6..width+6 across, and -16 .. 116 along z
        fieldNode.position = SCNVector3(0, 0, Float(Field.length / 2))
        fieldNode.name = "field"
        fieldNode.castsShadow = false
        scene.rootNode.addChildNode(fieldNode)

        // A dark surround so the edges don't look like the void
        let ground = SCNPlane(width: 400, height: 400)
        let gm = SCNMaterial()
        gm.diffuse.contents = UIColor(red: 0.045, green: 0.06, blue: 0.06, alpha: 1)
        gm.lightingModel = .lambert
        ground.materials = [gm]
        let groundNode = SCNNode(geometry: ground)
        groundNode.eulerAngles.x = -.pi / 2
        groundNode.position = SCNVector3(0, -0.05, 50)
        groundNode.castsShadow = false
        scene.rootNode.addChildNode(groundNode)
    }

    private func buildGoalposts() {
        for goalZ in [Float(-Field.endZoneDepth), Float(Field.length + Field.endZoneDepth)] {
            let post = SCNNode()
            let yellow = SCNMaterial()
            yellow.diffuse.contents = UIColor(red: 0.98, green: 0.82, blue: 0.2, alpha: 1)
            yellow.lightingModel = .physicallyBased
            yellow.metalness.contents = 0.3
            yellow.roughness.contents = 0.4
            func bar(_ w: CGFloat, _ h: CGFloat, _ d: CGFloat) -> SCNNode {
                let g = SCNBox(width: w, height: h, length: d, chamferRadius: 0.05); g.materials = [yellow]
                return SCNNode(geometry: g)
            }
            let base = bar(0.3, CGFloat(Field.crossbarHeight), 0.3)
            base.position = SCNVector3(0, Field.crossbarHeight / 2, 0)
            let crossbar = bar(CGFloat(Field.uprightHalfWidth * 2), 0.25, 0.25)
            crossbar.position = SCNVector3(0, Field.crossbarHeight, 0)
            let left = bar(0.25, CGFloat(Field.uprightHeight), 0.25)
            left.position = SCNVector3(-Field.uprightHalfWidth, Field.crossbarHeight + Field.uprightHeight / 2, 0)
            let right = bar(0.25, CGFloat(Field.uprightHeight), 0.25)
            right.position = SCNVector3(Field.uprightHalfWidth, Field.crossbarHeight + Field.uprightHeight / 2, 0)
            [base, crossbar, left, right].forEach { post.addChildNode($0) }
            post.position = SCNVector3(0, 0, goalZ)
            scene.rootNode.addChildNode(post)
        }
    }

    private func buildLights() {
        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.intensity = 1100
        sun.light?.castsShadow = true
        sun.light?.shadowMode = .deferred
        sun.light?.shadowColor = UIColor.black.withAlphaComponent(0.4)
        sun.light?.shadowRadius = 3
        sun.light?.orthographicScale = 45
        sun.light?.color = UIColor(red: 1.0, green: 0.97, blue: 0.9, alpha: 1)
        sun.eulerAngles = SCNVector3(-1.05, 0.5, 0)
        scene.rootNode.addChildNode(sun)

        // A cooler fill light from the opposite side keeps shadows from going pure black.
        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .directional
        fill.light?.intensity = 280
        fill.light?.color = UIColor(red: 0.65, green: 0.75, blue: 1.0, alpha: 1)
        fill.eulerAngles = SCNVector3(-0.6, -2.4, 0)
        scene.rootNode.addChildNode(fill)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 380
        ambient.light?.color = UIColor(white: 0.9, alpha: 1)
        scene.rootNode.addChildNode(ambient)
    }

    private func buildBall() {
        let sphere = SCNSphere(radius: 0.32)
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(red: 0.5, green: 0.27, blue: 0.14, alpha: 1)
        m.lightingModel = .physicallyBased
        m.roughness.contents = 0.55
        m.metalness.contents = 0.0
        sphere.materials = [m]
        ballNode.geometry = sphere
        ballNode.scale = SCNVector3(0.75, 0.75, 1.25)
        ballNode.name = "ball"
        ballNode.castsShadow = true
        scene.rootNode.addChildNode(ballNode)
    }

    /// Builds a small, low-poly football player: shoulder-padded torso, two-tone helmet with facemask,
    /// jersey number panel, and a simple stance (legs + slight forward lean). Kept to primitive shapes
    /// so 22 of these can animate every frame without cost.
    private func makePlayerNode(_ p: SimPlayer, color: UIColor, trim: UIColor) -> SCNNode {
        let node = SCNNode()
        node.name = "player-\(p.id)"

        let jerseyMat = SCNMaterial(); jerseyMat.diffuse.contents = color
        jerseyMat.lightingModel = .physicallyBased; jerseyMat.roughness.contents = 0.75; jerseyMat.metalness.contents = 0.0
        let trimMat = SCNMaterial(); trimMat.diffuse.contents = trim
        trimMat.lightingModel = .physicallyBased; trimMat.roughness.contents = 0.6; trimMat.metalness.contents = 0.0
        let skinMat = SCNMaterial(); skinMat.diffuse.contents = UIColor(red: 0.62, green: 0.44, blue: 0.32, alpha: 1)
        skinMat.lightingModel = .physicallyBased; skinMat.roughness.contents = 0.8

        // Legs: two short, slightly splayed capsules for a stance instead of a lollipop pole.
        let legGeo = SCNCapsule(capRadius: 0.13, height: 0.85)
        let pantsMat = SCNMaterial(); pantsMat.diffuse.contents = trim.withAlphaComponent(1).blended(with: .white, amount: 0.15)
        pantsMat.lightingModel = .physicallyBased; pantsMat.roughness.contents = 0.85
        legGeo.materials = [pantsMat]
        let leftLeg = SCNNode(geometry: legGeo)
        leftLeg.position = SCNVector3(-0.17, 0.43, 0.03)
        leftLeg.eulerAngles.x = 0.08
        node.addChildNode(leftLeg)
        let rightLegNode = SCNNode(geometry: legGeo)
        rightLegNode.position = SCNVector3(0.17, 0.43, -0.03)
        rightLegNode.eulerAngles.x = -0.08
        node.addChildNode(rightLegNode)

        // Torso: a tapered box reads as a jersey with shoulder width better than a pure capsule.
        let torso = SCNBox(width: 0.62, height: 0.62, length: 0.4, chamferRadius: 0.12)
        torso.materials = [jerseyMat]
        let torsoNode = SCNNode(geometry: torso)
        torsoNode.position = SCNVector3(0, 1.05, 0)
        torsoNode.name = "body"
        node.addChildNode(torsoNode)

        // Shoulder pads: a wider, flatter box layered on top of the torso to broaden the silhouette.
        let pads = SCNBox(width: 0.86, height: 0.24, length: 0.46, chamferRadius: 0.1)
        pads.materials = [trimMat]
        let padsNode = SCNNode(geometry: pads)
        padsNode.position = SCNVector3(0, 0.27, 0)
        torsoNode.addChildNode(padsNode)

        // Jersey number panel on the chest (a flat plate with the number, not just a text billboard,
        // so it reads as part of the body from the broadcast angle).
        let numberText = SCNText(string: p.jerseyNumber, extrusionDepth: 0.015)
        numberText.font = UIFont.systemFont(ofSize: 0.5, weight: .heavy)
        numberText.flatness = 0.15
        let numMat = SCNMaterial(); numMat.diffuse.contents = trim; numMat.lightingModel = .constant
        numberText.materials = [numMat]
        // Numbers on the chest and the back: the broadcast camera sits behind the offense.
        for (z, yaw) in [(Float(0.205), Float(0)), (Float(-0.205), Float.pi)] {
            let numNode = SCNNode(geometry: numberText)
            let (nMin, nMax) = numNode.boundingBox
            numNode.pivot = SCNMatrix4MakeTranslation((nMax.x - nMin.x) / 2, (nMax.y - nMin.y) / 2, 0)
            numNode.position = SCNVector3(0, 0, z)
            numNode.eulerAngles.y = yaw
            numNode.scale = SCNVector3(0.7, 0.7, 1)
            torsoNode.addChildNode(numNode)
        }

        // Helmet: two-tone shell (team color) with a contrasting facemask cage suggestion.
        let helmet = SCNSphere(radius: 0.26)
        let hm = SCNMaterial(); hm.diffuse.contents = color.darker(0.12)
        hm.lightingModel = .physicallyBased; hm.roughness.contents = 0.25; hm.metalness.contents = 0.1
        hm.specular.contents = UIColor.white
        helmet.materials = [hm]
        let helmetNode = SCNNode(geometry: helmet)
        helmetNode.position = SCNVector3(0, 1.72, 0)
        helmetNode.scale = SCNVector3(1, 0.92, 1.05)
        node.addChildNode(helmetNode)

        // Helmet stripe (center, team-contrasting) for a two-tone look.
        let stripe = SCNBox(width: 0.06, height: 0.5, length: 0.07, chamferRadius: 0.02)
        let stripeMat = SCNMaterial(); stripeMat.diffuse.contents = trim; stripeMat.lightingModel = .physicallyBased; stripeMat.roughness.contents = 0.3
        stripe.materials = [stripeMat]
        let stripeNode = SCNNode(geometry: stripe)
        stripeNode.position = SCNVector3(0, 0.02, 0)
        stripeNode.eulerAngles.x = .pi / 2
        helmetNode.addChildNode(stripeNode)

        // Facemask: a small cage of thin bars in front of the helmet, in the trim color.
        let maskMat = SCNMaterial(); maskMat.diffuse.contents = trim.blended(with: .black, amount: 0.1)
        maskMat.lightingModel = .physicallyBased; maskMat.metalness.contents = 0.5; maskMat.roughness.contents = 0.35
        let maskFrame = SCNBox(width: 0.22, height: 0.2, length: 0.05, chamferRadius: 0.03)
        maskFrame.materials = [maskMat]
        let maskNode = SCNNode(geometry: maskFrame)
        maskNode.position = SCNVector3(0, -0.02, 0.24)
        helmetNode.addChildNode(maskNode)
        for barY: Float in [-0.05, 0.03, 0.11] {
            let bar = SCNBox(width: 0.22, height: 0.025, length: 0.06, chamferRadius: 0.01)
            bar.materials = [maskMat]
            let barNode = SCNNode(geometry: bar)
            barNode.position = SCNVector3(0, barY, 0.27)
            helmetNode.addChildNode(barNode)
        }

        // Ring under eligible ball handlers on offense (the ones you can draw from) — pulsing gold glow.
        if p.role.isEligibleBallHandler {
            let ring = SCNTorus(ringRadius: 0.78, pipeRadius: 0.075)
            let rm = SCNMaterial()
            rm.diffuse.contents = UIColor(red: 0.98, green: 0.82, blue: 0.28, alpha: 1)
            rm.emission.contents = UIColor(red: 0.98, green: 0.82, blue: 0.28, alpha: 1)
            rm.lightingModel = .constant
            ring.materials = [rm]
            let ringNode = SCNNode(geometry: ring)
            ringNode.position = SCNVector3(0, 0.06, 0)
            ringNode.name = "ring"
            let pulse = SCNAction.repeatForever(.sequence([
                .scale(to: 1.12, duration: 0.6), .scale(to: 1.0, duration: 0.6)
            ]))
            ringNode.runAction(pulse)
            node.addChildNode(ringNode)
        }

        // Position label: a rounded plate behind bold text so it stays legible over grass or jerseys.
        let labelNode = makeLabelNode(text: p.role.shortName)
        labelNode.position = SCNVector3(0, 2.35, 0)
        labelNode.name = "label"
        node.addChildNode(labelNode)

        node.position = SCNVector3(p.pos.x, 0, p.pos.y)
        return node
    }

    private func makeLabelNode(text: String) -> SCNNode {
        let container = SCNNode()
        container.constraints = [SCNBillboardConstraint()]

        let font = UIFont.systemFont(ofSize: 30, weight: .heavy)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white]
        let str = NSAttributedString(string: text, attributes: attrs)
        let textSize = str.size()
        let padding: CGFloat = 10
        let plateSize = CGSize(width: textSize.width + padding * 2, height: textSize.height + padding * 1.2)

        let renderer = UIGraphicsImageRenderer(size: plateSize)
        let image = renderer.image { ctx in
            let c = ctx.cgContext
            let rect = CGRect(origin: .zero, size: plateSize)
            let path = UIBezierPath(roundedRect: rect, cornerRadius: plateSize.height / 2)
            c.setFillColor(UIColor.black.withAlphaComponent(0.55).cgColor)
            path.fill()
            c.setStrokeColor(UIColor(red: 0.98, green: 0.82, blue: 0.28, alpha: 0.9).cgColor)
            c.setLineWidth(1.5)
            path.lineWidth = 1.5
            path.stroke()
            str.draw(at: CGPoint(x: padding, y: padding * 0.6))
        }

        let plane = SCNPlane(width: plateSize.width / 60, height: plateSize.height / 60)
        let m = SCNMaterial(); m.diffuse.contents = image; m.lightingModel = .constant; m.isDoubleSided = true
        plane.materials = [m]
        let planeNode = SCNNode(geometry: plane)
        container.addChildNode(planeNode)
        return container
    }

    // MARK: Updating

    func setTeams(offenseIsUser: Bool) {
        self.offenseIsUser = offenseIsUser
    }

    func layOut(players: [SimPlayer], los: Float, firstDownAt: Float?, offenseIsUser: Bool) {
        self.offenseIsUser = offenseIsUser
        rootPlayers.childNodes.forEach { $0.removeFromParentNode() }
        playerNodes.removeAll()
        let offenseColor = UIColor(offenseIsUser ? userTeam.color : opponentTeam.color)
        let defenseColor = UIColor(offenseIsUser ? opponentTeam.color : userTeam.color)
        let offenseTrim = offenseColor.contrastingTrim()
        let defenseTrim = defenseColor.contrastingTrim()
        for p in players {
            let isOffense = p.side == .offense
            let node = makePlayerNode(p, color: isOffense ? offenseColor : defenseColor, trim: isOffense ? offenseTrim : defenseTrim)
            // Face the offense downfield (+z) and the defense back toward the offense (-z) so the two
            // teams visibly line up facing each other before the snap.
            node.eulerAngles.y = isOffense ? 0 : .pi
            if p.side == .offense && !offenseIsUser { node.childNode(withName: "ring", recursively: false)?.isHidden = true }
            playerNodes[p.id] = node
            rootPlayers.addChildNode(node)
        }
        ballNode.removeAllActions()
        ballNode.position = SCNVector3(0, 0.4, los - 5.5)
        updateMarkers(los: los, firstDownAt: firstDownAt)
        clearPath()
    }

    func updateMarkers(los: Float, firstDownAt: Float?) {
        losNode.childNodes.forEach { $0.removeFromParentNode() }
        firstDownNode.childNodes.forEach { $0.removeFromParentNode() }
        let losLine = SCNBox(width: CGFloat(Field.width), height: 0.02, length: 0.25, chamferRadius: 0)
        let lm = SCNMaterial(); lm.diffuse.contents = UIColor(red: 0.2, green: 0.55, blue: 1, alpha: 0.9); lm.emission.contents = UIColor(red: 0.2, green: 0.55, blue: 1, alpha: 0.5)
        lm.lightingModel = .constant
        losLine.materials = [lm]
        let ln = SCNNode(geometry: losLine); ln.position = SCNVector3(0, 0.02, los)
        losNode.addChildNode(ln)
        if let fd = firstDownAt, fd < 100 {
            let fdLine = SCNBox(width: CGFloat(Field.width), height: 0.02, length: 0.3, chamferRadius: 0)
            let fm = SCNMaterial(); fm.diffuse.contents = UIColor(red: 1, green: 0.9, blue: 0.2, alpha: 0.95); fm.emission.contents = UIColor(red: 1, green: 0.9, blue: 0.2, alpha: 0.6)
            fm.lightingModel = .constant
            fdLine.materials = [fm]
            let fn = SCNNode(geometry: fdLine); fn.position = SCNVector3(0, 0.02, fd)
            firstDownNode.addChildNode(fn)
        }
    }

    func apply(_ sim: PlaySim) {
        for p in sim.players {
            guard let node = playerNodes[p.id] else { continue }
            node.position = SCNVector3(p.pos.x, 0, p.pos.y)
            if p.facing != .zero { node.eulerAngles.y = atan2(p.facing.x, p.facing.y) }
            if case .down = p.state {
                node.childNode(withName: "body", recursively: false)?.eulerAngles.x = -.pi / 2.3
            }
        }
        ballNode.position = SCNVector3(sim.ballPos.x, sim.ballHeight, sim.ballPos.y)
        ballNode.isHidden = false
    }

    func showPath(_ points: [FieldPoint], color: UIColor) {
        clearPath()
        guard points.count > 1 else { return }
        let m = SCNMaterial(); m.diffuse.contents = color; m.emission.contents = color.withAlphaComponent(0.7)
        m.lightingModel = .constant
        var last = points[0]
        for p in points.dropFirst() {
            let d = last.distance(to: p)
            guard d > 0.01 else { continue }
            let seg = SCNBox(width: 0.35, height: 0.03, length: CGFloat(d), chamferRadius: 0)
            seg.materials = [m]
            let node = SCNNode(geometry: seg)
            let mid = (last + p) * 0.5
            node.position = SCNVector3(mid.x, 0.04, mid.y)
            node.eulerAngles.y = atan2(p.x - last.x, p.y - last.y)
            pathNode.addChildNode(node)
            last = p
        }
        let tip = SCNSphere(radius: 0.4); tip.materials = [m]
        let tipNode = SCNNode(geometry: tip)
        tipNode.position = SCNVector3(last.x, 0.1, last.y)
        pathNode.addChildNode(tipNode)
    }

    func clearPath() {
        pathNode.childNodes.forEach { $0.removeFromParentNode() }
    }

    func highlight(playerID: Int?, on: Bool) {
        for (id, node) in playerNodes {
            guard let ring = node.childNode(withName: "ring", recursively: false) else { continue }
            ring.scale = (on && id == playerID) ? SCNVector3(1.4, 1.4, 1.4) : SCNVector3(1, 1, 1)
        }
    }

    // MARK: Camera

    /// Broadcast-style camera: behind and above the offense, looking downfield. Smoothly follows a focus point.
    ///
    /// Presnap framing (portrait phone, 65° vertical FOV): the receivers at x = ±14 sit just inside the
    /// frame edges, the backfield at `los - 5.5` lands around 58% down the screen (above the HUD panel),
    /// and the deep safeties at `los + 15` land around 40% down.
    func aimCamera(at focus: FieldPoint, presnap: Bool, animated: Bool) {
        let height: Float = presnap ? 36 : 30
        let back: Float = presnap ? 38 : 33
        let lookAtDepth: Float = presnap ? 3 : 5
        let position = SCNVector3(focus.x * 0.5, height, focus.y - back)
        let lookAt = SCNVector3(focus.x * 0.6, 0, focus.y + lookAtDepth)
        let apply = {
            self.cameraNode.position = position
            self.cameraNode.look(at: lookAt)
        }
        if animated {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = presnap ? 0.9 : 0.25
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            apply()
            SCNTransaction.commit()
        } else {
            apply()
        }
    }

    /// Ground-plane hit: the yard coordinates under a screen point.
    func fieldPoint(from view: SCNView, at point: CGPoint) -> FieldPoint? {
        let hits = view.hitTest(point, options: [.searchMode: SCNHitTestSearchMode.all.rawValue, .ignoreHiddenNodes: true])
        if let hit = hits.first(where: { $0.node.name == "field" }) {
            return FieldPoint(hit.worldCoordinates.x, hit.worldCoordinates.z)
        }
        // Fall back to an unprojected ray against y = 0
        let near = view.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 0))
        let far = view.unprojectPoint(SCNVector3(Float(point.x), Float(point.y), 1))
        let dir = SCNVector3(far.x - near.x, far.y - near.y, far.z - near.z)
        guard abs(dir.y) > 0.0001 else { return nil }
        let t = -near.y / dir.y
        guard t > 0 else { return nil }
        return FieldPoint(near.x + dir.x * t, near.z + dir.z * t)
    }

    /// The offensive player (if any) under a screen point, within a generous radius.
    func player(from view: SCNView, at point: CGPoint, among players: [SimPlayer]) -> SimPlayer? {
        guard let fp = fieldPoint(from: view, at: point) else { return nil }
        let candidates = players.filter { $0.side == .offense && $0.role.isEligibleBallHandler }
        return candidates.min { $0.pos.distance(to: fp) < $1.pos.distance(to: fp) }.flatMap { $0.pos.distance(to: fp) < 3.2 ? $0 : nil }
    }

    /// Fly the ball on a kick arc toward the uprights (or downfield for a punt).
    func animateKick(from los: Float, distanceYards: Float, made: Bool, punt: Bool, completion: @escaping () -> Void) {
        let start = SCNVector3(0, 0.4, los - 7)
        let endZ = punt ? los - 7 + distanceYards : Float(Field.length + Field.endZoneDepth) + (made ? 4 : 2)
        let endX: Float = made || punt ? 0 : (Bool.random() ? -5.5 : 5.5)
        let end = SCNVector3(endX, punt ? 0.4 : (made ? 6 : 2.2), endZ)
        let duration: TimeInterval = punt ? 3.0 : 2.2
        ballNode.position = start
        ballNode.isHidden = false
        let ctrl = SCNVector3((start.x + end.x) / 2, punt ? 22 : 16, (start.z + end.z) / 2)
        let action = SCNAction.customAction(duration: duration) { node, elapsed in
            let t = Float(elapsed / duration)
            let x = (1 - t) * (1 - t) * start.x + 2 * (1 - t) * t * ctrl.x + t * t * end.x
            let y = (1 - t) * (1 - t) * start.y + 2 * (1 - t) * t * ctrl.y + t * t * end.y
            let z = (1 - t) * (1 - t) * start.z + 2 * (1 - t) * t * ctrl.z + t * t * end.z
            node.position = SCNVector3(x, y, z)
        }
        ballNode.runAction(action) { DispatchQueue.main.async(execute: completion) }
    }
}

extension UIColor {
    func darker(_ amount: CGFloat) -> UIColor {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return UIColor(hue: h, saturation: s, brightness: max(0, b - amount), alpha: a)
    }

    func blended(with other: UIColor, amount: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = max(0, min(1, amount))
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, alpha: a1 + (a2 - a1) * t)
    }

    /// A trim color (helmet stripe, number, pads) that reads clearly against this jersey color:
    /// white for darker/saturated jerseys, near-black for pale ones.
    func contrastingTrim() -> UIColor {
        var w: CGFloat = 0
        getWhite(&w, alpha: nil)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: nil)
        let luma = 0.299 * r + 0.587 * g + 0.114 * b
        return luma > 0.6 ? UIColor(white: 0.08, alpha: 1) : UIColor.white
    }
}

private extension SimPlayer {
    /// A stable jersey number derived from the player's id so numbers stay consistent across frames
    /// without needing a new field on SimPlayer.
    var jerseyNumber: String {
        let base: Int
        switch role {
        case .quarterback: base = 10
        case .runningBack: base = 20
        case .wideReceiver: base = 80
        case .tightEnd: base = 88
        case .offensiveLine: base = 70
        case .defensiveLine: base = 90
        case .linebacker: base = 50
        case .cornerback: base = 24
        case .safety: base = 30
        }
        return "\(base + (id % 9))"
    }
}

import SwiftUI

/// Draws the turf texture with Core Graphics: mowed-stripe grass shading, yard lines, numbers, hashes,
/// colored end zones.
enum FieldTexture {
    static func image(userColor: Color, opponentColor: Color, userAbbrev: String, opponentAbbrev: String) -> UIImage {
        // Texture spans x in [-32.65, 32.65] (width 65.3 yd) and z in [-16, 116] (132 yd). 12 px per yard.
        let ppy: CGFloat = 12
        let widthYd: CGFloat = CGFloat(Field.width) + 12
        let lengthYd: CGFloat = 132
        let size = CGSize(width: widthYd * ppy, height: lengthYd * ppy)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let c = ctx.cgContext
            func px(_ x: CGFloat) -> CGFloat { (x + widthYd / 2) * ppy }
            // Image y grows downward; we want z = -16 at the bottom of the image and z = 116 at the top,
            // because the plane is rotated so its +height maps to +z. So y_img = (116 - z) * ppy.
            func pz(_ z: CGFloat) -> CGFloat { (116 - z) * ppy }

            // Base grass: a subtle vertical gradient (darker toward the far end, as if lit by one sun)
            // instead of a flat fill, so the turf has depth before any stripes go down.
            let grassLight = UIColor(red: 0.20, green: 0.50, blue: 0.30, alpha: 1)
            let grassDark = UIColor(red: 0.14, green: 0.40, blue: 0.24, alpha: 1)
            let grassGradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [grassLight.cgColor, grassDark.cgColor] as CFArray, locations: [0, 1])!
            c.saveGState()
            c.clip(to: CGRect(origin: .zero, size: size))
            c.drawLinearGradient(grassGradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size.height), options: [])
            c.restoreGState()

            // Mowed stripes: alternating 5-yard bands, slightly darker/lighter than the base gradient,
            // so the field reads as real mowed turf instead of flat color.
            for i in stride(from: 0, to: 100, by: 5) {
                let stripeIndex = i / 5
                let lighten = stripeIndex % 2 == 0
                c.setFillColor((lighten ? UIColor.white.withAlphaComponent(0.045) : UIColor.black.withAlphaComponent(0.06)).cgColor)
                c.fill(CGRect(x: px(-CGFloat(Field.halfWidth)), y: pz(CGFloat(i + 5)), width: CGFloat(Field.width) * ppy, height: 5 * ppy))
            }
            // Fine mow-line texture within each stripe for extra realism at close range.
            c.setStrokeColor(UIColor.black.withAlphaComponent(0.03).cgColor)
            c.setLineWidth(1)
            var mowX = px(-CGFloat(Field.halfWidth))
            let mowMaxX = px(CGFloat(Field.halfWidth))
            while mowX < mowMaxX {
                c.move(to: CGPoint(x: mowX, y: pz(0)))
                c.addLine(to: CGPoint(x: mowX, y: pz(110)))
                mowX += 3
            }
            c.strokePath()

            // End zones
            c.setFillColor(UIColor(userColor).withAlphaComponent(0.92).cgColor)
            c.fill(CGRect(x: px(-CGFloat(Field.halfWidth)), y: pz(0), width: CGFloat(Field.width) * ppy, height: 10 * ppy))
            c.setFillColor(UIColor(opponentColor).withAlphaComponent(0.92).cgColor)
            c.fill(CGRect(x: px(-CGFloat(Field.halfWidth)), y: pz(110), width: CGFloat(Field.width) * ppy, height: 10 * ppy))
            // Sidelines & end lines
            c.setStrokeColor(UIColor.white.cgColor)
            c.setLineWidth(0.5 * ppy)
            c.stroke(CGRect(x: px(-CGFloat(Field.halfWidth)), y: pz(110), width: CGFloat(Field.width) * ppy, height: 120 * ppy))
            // Yard lines — crisp white with a very faint drop shadow so they pop against the grass.
            c.setLineWidth(0.25 * ppy)
            c.setStrokeColor(UIColor.white.withAlphaComponent(0.95).cgColor)
            for yard in stride(from: 0, through: 100, by: 5) {
                c.move(to: CGPoint(x: px(-CGFloat(Field.halfWidth)), y: pz(CGFloat(yard))))
                c.addLine(to: CGPoint(x: px(CGFloat(Field.halfWidth)), y: pz(CGFloat(yard))))
            }
            c.strokePath()
            // Hash marks every yard
            c.setLineWidth(0.15 * ppy)
            for yard in 1..<100 where yard % 5 != 0 {
                for hx in [-CGFloat(Field.hashX), CGFloat(Field.hashX), -CGFloat(Field.halfWidth) + 0.5, CGFloat(Field.halfWidth) - 0.5] {
                    c.move(to: CGPoint(x: px(hx - 0.5), y: pz(CGFloat(yard))))
                    c.addLine(to: CGPoint(x: px(hx + 0.5), y: pz(CGFloat(yard))))
                }
            }
            c.strokePath()
            // Numbers — bold, high-contrast, with a soft dark outline so they stay legible on both
            // the light and dark mow stripes.
            let numberFont = UIFont.systemFont(ofSize: 4.5 * ppy, weight: .heavy)
            for yard in stride(from: 10, through: 90, by: 10) {
                let n = yard <= 50 ? yard : 100 - yard
                let str = "\(n)"
                for side: CGFloat in [-1, 1] {
                    let x = px(side * 18)
                    let y = pz(CGFloat(yard))
                    c.saveGState()
                    c.translateBy(x: x, y: y)
                    c.rotate(by: side < 0 ? .pi / 2 : -.pi / 2)
                    drawOutlinedNumber(str, font: numberFont, in: c)
                    c.restoreGState()
                }
            }
            // End zone words
            let ezFont = UIFont.systemFont(ofSize: 6 * ppy, weight: .black)
            for (abbrev, z, rot) in [(userAbbrev, CGFloat(-5), CGFloat.pi / 2), (opponentAbbrev, CGFloat(105), -CGFloat.pi / 2)] {
                c.saveGState()
                c.translateBy(x: px(0), y: pz(z))
                c.rotate(by: rot)
                drawOutlinedNumber(abbrev, font: ezFont, in: c)
                c.restoreGState()
            }
        }
    }

    /// Draws text centered at the current origin with a soft dark outline behind a white fill —
    /// keeps yard numbers and end-zone text legible over both grass stripes and colored end zones.
    private static func drawOutlinedNumber(_ text: String, font: UIFont, in c: CGContext) {
        let outlineAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.clear,
            .strokeColor: UIColor.black.withAlphaComponent(0.55),
            .strokeWidth: 9
        ]
        let fillAttrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: UIColor.white.withAlphaComponent(0.95)]
        let outlineStr = NSAttributedString(string: text, attributes: outlineAttrs)
        let fillStr = NSAttributedString(string: text, attributes: fillAttrs)
        let sz = fillStr.size()
        let origin = CGPoint(x: -sz.width / 2, y: -sz.height / 2)
        outlineStr.draw(at: origin)
        fillStr.draw(at: origin)
    }
}
