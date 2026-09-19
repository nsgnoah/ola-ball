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
        camera.fieldOfView = 52
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
        material.lightingModel = .lambert
        material.isDoubleSided = false
        plane.materials = [material]
        fieldNode.geometry = plane
        fieldNode.eulerAngles.x = -.pi / 2
        // Texture covers -6..width+6 across, and -16 .. 116 along z
        fieldNode.position = SCNVector3(0, 0, Float(Field.length / 2))
        fieldNode.name = "field"
        scene.rootNode.addChildNode(fieldNode)

        // A dark surround so the edges don't look like the void
        let ground = SCNPlane(width: 400, height: 400)
        let gm = SCNMaterial()
        gm.diffuse.contents = UIColor(red: 0.05, green: 0.09, blue: 0.08, alpha: 1)
        ground.materials = [gm]
        let groundNode = SCNNode(geometry: ground)
        groundNode.eulerAngles.x = -.pi / 2
        groundNode.position = SCNVector3(0, -0.05, 50)
        scene.rootNode.addChildNode(groundNode)
    }

    private func buildGoalposts() {
        for goalZ in [Float(-Field.endZoneDepth), Float(Field.length + Field.endZoneDepth)] {
            let post = SCNNode()
            let yellow = SCNMaterial(); yellow.diffuse.contents = UIColor(red: 0.98, green: 0.82, blue: 0.2, alpha: 1)
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
        sun.light?.shadowColor = UIColor.black.withAlphaComponent(0.35)
        sun.light?.shadowRadius = 4
        sun.light?.orthographicScale = 60
        sun.eulerAngles = SCNVector3(-1.05, 0.5, 0)
        scene.rootNode.addChildNode(sun)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 420
        ambient.light?.color = UIColor(white: 0.9, alpha: 1)
        scene.rootNode.addChildNode(ambient)
    }

    private func buildBall() {
        let sphere = SCNSphere(radius: 0.32)
        let m = SCNMaterial(); m.diffuse.contents = UIColor(red: 0.55, green: 0.3, blue: 0.16, alpha: 1)
        sphere.materials = [m]
        ballNode.geometry = sphere
        ballNode.scale = SCNVector3(0.75, 0.75, 1.25)
        ballNode.name = "ball"
        scene.rootNode.addChildNode(ballNode)
    }

    private func makePlayerNode(_ p: SimPlayer, color: UIColor) -> SCNNode {
        let node = SCNNode()
        node.name = "player-\(p.id)"

        let body = SCNCapsule(capRadius: 0.42, height: 1.5)
        let bm = SCNMaterial(); bm.diffuse.contents = color
        body.materials = [bm]
        let bodyNode = SCNNode(geometry: body)
        bodyNode.position = SCNVector3(0, 0.95, 0)
        bodyNode.name = "body"
        node.addChildNode(bodyNode)

        let helmet = SCNSphere(radius: 0.33)
        let hm = SCNMaterial(); hm.diffuse.contents = color.darker(0.25); hm.specular.contents = UIColor.white
        helmet.materials = [hm]
        let helmetNode = SCNNode(geometry: helmet)
        helmetNode.position = SCNVector3(0, 1.95, 0)
        node.addChildNode(helmetNode)

        // Facemask stripe to show facing direction
        let mask = SCNBox(width: 0.34, height: 0.12, length: 0.08, chamferRadius: 0.02)
        let mm = SCNMaterial(); mm.diffuse.contents = UIColor.white.withAlphaComponent(0.85)
        mask.materials = [mm]
        let maskNode = SCNNode(geometry: mask)
        maskNode.position = SCNVector3(0, 1.9, 0.3)
        node.addChildNode(maskNode)

        // Ring under eligible ball handlers on offense (the ones you can draw from)
        if p.role.isEligibleBallHandler {
            let ring = SCNTorus(ringRadius: 0.75, pipeRadius: 0.07)
            let rm = SCNMaterial(); rm.diffuse.contents = UIColor(red: 0.96, green: 0.77, blue: 0.26, alpha: 1); rm.emission.contents = UIColor(red: 0.96, green: 0.77, blue: 0.26, alpha: 0.6)
            ring.materials = [rm]
            let ringNode = SCNNode(geometry: ring)
            ringNode.position = SCNVector3(0, 0.06, 0)
            ringNode.name = "ring"
            node.addChildNode(ringNode)
        }

        // Position label (small billboard)
        let text = SCNText(string: p.role.shortName, extrusionDepth: 0.02)
        text.font = UIFont.systemFont(ofSize: 0.7, weight: .heavy)
        text.flatness = 0.2
        let tm = SCNMaterial(); tm.diffuse.contents = UIColor.white; tm.emission.contents = UIColor.white.withAlphaComponent(0.4)
        text.materials = [tm]
        let textNode = SCNNode(geometry: text)
        let (minB, maxB) = textNode.boundingBox
        textNode.pivot = SCNMatrix4MakeTranslation((maxB.x - minB.x) / 2, 0, 0)
        textNode.position = SCNVector3(0, 2.45, 0)
        textNode.constraints = [SCNBillboardConstraint()]
        textNode.name = "label"
        node.addChildNode(textNode)

        node.position = SCNVector3(p.pos.x, 0, p.pos.y)
        return node
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
        for p in players {
            let node = makePlayerNode(p, color: p.side == .offense ? offenseColor : defenseColor)
            if p.side == .offense && !offenseIsUser { node.childNode(withName: "ring", recursively: false)?.isHidden = true }
            playerNodes[p.id] = node
            rootPlayers.addChildNode(node)
        }
        ballNode.position = SCNVector3(0, 0.4, los - 5.5)
        updateMarkers(los: los, firstDownAt: firstDownAt)
        clearPath()
    }

    func updateMarkers(los: Float, firstDownAt: Float?) {
        losNode.childNodes.forEach { $0.removeFromParentNode() }
        firstDownNode.childNodes.forEach { $0.removeFromParentNode() }
        let losLine = SCNBox(width: CGFloat(Field.width), height: 0.02, length: 0.25, chamferRadius: 0)
        let lm = SCNMaterial(); lm.diffuse.contents = UIColor(red: 0.2, green: 0.55, blue: 1, alpha: 0.9); lm.emission.contents = UIColor(red: 0.2, green: 0.55, blue: 1, alpha: 0.5)
        losLine.materials = [lm]
        let ln = SCNNode(geometry: losLine); ln.position = SCNVector3(0, 0.02, los)
        losNode.addChildNode(ln)
        if let fd = firstDownAt, fd < 100 {
            let fdLine = SCNBox(width: CGFloat(Field.width), height: 0.02, length: 0.3, chamferRadius: 0)
            let fm = SCNMaterial(); fm.diffuse.contents = UIColor(red: 1, green: 0.9, blue: 0.2, alpha: 0.95); fm.emission.contents = UIColor(red: 1, green: 0.9, blue: 0.2, alpha: 0.6)
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
    func aimCamera(at focus: FieldPoint, presnap: Bool, animated: Bool) {
        let height: Float = presnap ? 16 : 13
        let back: Float = presnap ? 21 : 17
        let position = SCNVector3(focus.x * 0.6, height, focus.y - back)
        let lookAt = SCNVector3(focus.x * 0.7, 1.5, focus.y + (presnap ? 9 : 7))
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
}

import SwiftUI

/// Draws the turf texture with Core Graphics: stripes, yard lines, numbers, hashes, colored end zones.
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

            c.setFillColor(UIColor(red: 0.16, green: 0.45, blue: 0.27, alpha: 1).cgColor)
            c.fill(CGRect(origin: .zero, size: size))
            // Stripes every 5 yards
            for i in stride(from: 0, to: 100, by: 10) {
                c.setFillColor(UIColor(red: 0.19, green: 0.5, blue: 0.3, alpha: 1).cgColor)
                c.fill(CGRect(x: px(-CGFloat(Field.halfWidth)), y: pz(CGFloat(i + 5)), width: CGFloat(Field.width) * ppy, height: 5 * ppy))
            }
            // End zones
            c.setFillColor(UIColor(userColor).withAlphaComponent(0.9).cgColor)
            c.fill(CGRect(x: px(-CGFloat(Field.halfWidth)), y: pz(0), width: CGFloat(Field.width) * ppy, height: 10 * ppy))
            c.setFillColor(UIColor(opponentColor).withAlphaComponent(0.9).cgColor)
            c.fill(CGRect(x: px(-CGFloat(Field.halfWidth)), y: pz(110), width: CGFloat(Field.width) * ppy, height: 10 * ppy))
            // Sidelines & end lines
            c.setStrokeColor(UIColor.white.cgColor)
            c.setLineWidth(0.5 * ppy)
            c.stroke(CGRect(x: px(-CGFloat(Field.halfWidth)), y: pz(110), width: CGFloat(Field.width) * ppy, height: 120 * ppy))
            // Yard lines
            c.setLineWidth(0.25 * ppy)
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
            // Numbers
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 4.5 * ppy, weight: .bold), .foregroundColor: UIColor.white.withAlphaComponent(0.85)]
            for yard in stride(from: 10, through: 90, by: 10) {
                let n = yard <= 50 ? yard : 100 - yard
                let str = NSAttributedString(string: "\(n)", attributes: attrs)
                for side: CGFloat in [-1, 1] {
                    let x = px(side * 18)
                    let y = pz(CGFloat(yard))
                    c.saveGState()
                    c.translateBy(x: x, y: y)
                    c.rotate(by: side < 0 ? .pi / 2 : -.pi / 2)
                    str.draw(at: CGPoint(x: -str.size().width / 2, y: -str.size().height / 2))
                    c.restoreGState()
                }
            }
            // End zone words
            let ezAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 6 * ppy, weight: .black), .foregroundColor: UIColor.white.withAlphaComponent(0.9)]
            for (abbrev, z, rot) in [(userAbbrev, CGFloat(-5), CGFloat.pi / 2), (opponentAbbrev, CGFloat(105), -CGFloat.pi / 2)] {
                let str = NSAttributedString(string: abbrev, attributes: ezAttrs)
                c.saveGState()
                c.translateBy(x: px(0), y: pz(z))
                c.rotate(by: rot)
                str.draw(at: CGPoint(x: -str.size().width / 2, y: -str.size().height / 2))
                c.restoreGState()
            }
        }
    }
}
