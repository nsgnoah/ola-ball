import SceneKit
import UIKit

/// A stylized, articulated football player built from primitives: helmet with facemask, shoulder pads,
/// numbered jersey, two-segment arms, legs with cleats. Animates a run cycle, role-specific stances, and a tackle pose.
final class PlayerRig {
    let node = SCNNode()          // root at the feet; local +z is the facing direction
    let id: Int
    let role: Role
    let number: Int

    private let body = SCNNode()  // everything above the feet, for lean and bob
    private let torso = SCNNode()
    private let head = SCNNode()
    private let helmet = SCNNode()
    private let leftShoulder = SCNNode(), rightShoulder = SCNNode()
    private let leftElbow = SCNNode(), rightElbow = SCNNode()
    private let leftHip = SCNNode(), rightHip = SCNNode()
    private let leftKnee = SCNNode(), rightKnee = SCNNode()
    private let ring = SCNNode()
    private let tag = SCNNode()
    private let shadow = SCNNode()

    private var phase: Float = 0
    private var lastPos: FieldPoint
    private var smoothedSpeed: Float = 0
    private var isDown = false
    private var currentStance: Stance = .idle

    enum Stance { case idle, threePoint, twoPoint, ready, crouch, run, down }

    // Shared geometry across all rigs (SceneKit shares GPU buffers for identical geometry objects).
    private static var shared: [String: SCNGeometry] = [:]
    private static func geometry(_ key: String, _ make: () -> SCNGeometry) -> SCNGeometry {
        if let g = shared[key] { return g }
        let g = make(); shared[key] = g; return g
    }

    init(player: SimPlayer, jersey: UIColor, number: Int, skin: UIColor, showRing: Bool, tagText: String) {
        id = player.id
        role = player.role
        self.number = number
        lastPos = player.pos
        node.name = "player-\(player.id)"

        // Role-based proportions (yards). A stylized 2.0-yard-tall athlete.
        let bulk: Float
        switch role {
        case .offensiveLine, .defensiveLine: bulk = 1.18
        case .linebacker, .tightEnd, .runningBack: bulk = 1.05
        case .quarterback, .safety: bulk = 1.0
        case .wideReceiver, .cornerback: bulk = 0.94
        }
        let ink = Art.trim(for: jersey)
        let pants = Art.color(jersey, brightness: -0.15, saturation: -0.1)
        let jerseyMat = Art.pbr(jersey, roughness: 0.82)
        let skinMat = Art.pbr(skin, roughness: 0.6)
        let pantsMat = Art.pbr(pants, roughness: 0.7)
        let darkMat = Art.pbr(UIColor(white: 0.12, alpha: 1), roughness: 0.5)
        let helmetMat = Art.pbr(Art.color(jersey, brightness: -0.04), roughness: 0.22, metalness: 0.2)
        helmetMat.specular.contents = UIColor.white

        // Torso: rounded box with the number on the front and back faces.
        let torsoGeo = SCNBox(width: CGFloat(0.78 * bulk), height: 0.82, length: CGFloat(0.42 * bulk), chamferRadius: 0.14)
        let numberFront = Art.textured(Art.numberImage(number, jersey: jersey, ink: ink), roughness: 0.75)
        let numberBack = Art.textured(Art.numberImage(number, jersey: jersey, ink: ink), roughness: 0.75)
        torsoGeo.materials = [numberFront, jerseyMat, numberBack, jerseyMat, jerseyMat, pantsMat]
        let torsoNode = SCNNode(geometry: torsoGeo)
        torsoNode.position = SCNVector3(0, 0.42, 0)
        torso.addChildNode(torsoNode)
        // Shoulder pads
        let pads = SCNBox(width: CGFloat(1.02 * bulk), height: 0.18, length: CGFloat(0.50 * bulk), chamferRadius: 0.08)
        pads.materials = [jerseyMat]
        let padsNode = SCNNode(geometry: pads)
        padsNode.position = SCNVector3(0, 0.78, 0)
        torso.addChildNode(padsNode)
        // Hips
        let hips = SCNBox(width: CGFloat(0.64 * bulk), height: 0.32, length: CGFloat(0.38 * bulk), chamferRadius: 0.1)
        hips.materials = [pantsMat]
        let hipsNode = SCNNode(geometry: hips)
        hipsNode.position = SCNVector3(0, -0.02, 0)
        torso.addChildNode(hipsNode)
        // Belt
        let belt = SCNBox(width: CGFloat(0.66 * bulk), height: 0.05, length: CGFloat(0.40 * bulk), chamferRadius: 0.02)
        belt.materials = [darkMat]
        let beltNode = SCNNode(geometry: belt)
        beltNode.position = SCNVector3(0, 0.12, 0)
        torso.addChildNode(beltNode)
        torso.position = SCNVector3(0, 1.16, 0)
        body.addChildNode(torso)

        // Neck + helmet
        let neck = SCNCylinder(radius: 0.11, height: 0.16)
        neck.materials = [skinMat]
        let neckNode = SCNNode(geometry: neck)
        neckNode.position = SCNVector3(0, 0.90, 0)
        torso.addChildNode(neckNode)
        head.position = SCNVector3(0, 1.10, 0.02)
        torso.addChildNode(head)
        let shell = SCNSphere(radius: 0.29)
        shell.segmentCount = 28
        shell.materials = [helmetMat]
        helmet.geometry = shell
        helmet.scale = SCNVector3(1.0, 1.08, 1.14)
        head.addChildNode(helmet)
        // Face cavity
        let face = SCNSphere(radius: 0.18)
        face.materials = [darkMat]
        let faceNode = SCNNode(geometry: face)
        faceNode.position = SCNVector3(0, -0.04, 0.19)
        head.addChildNode(faceNode)
        // Facemask bars
        let barMat = Art.pbr(UIColor(white: 0.22, alpha: 1), roughness: 0.4, metalness: 0.5)
        for (y, w) in [(Float(-0.06), Float(0.38)), (Float(-0.16), Float(0.34))] {
            let bar = SCNCylinder(radius: 0.022, height: CGFloat(w))
            bar.materials = [barMat]
            let barNode = SCNNode(geometry: bar)
            barNode.eulerAngles.z = .pi / 2
            barNode.position = SCNVector3(0, y, 0.33)
            head.addChildNode(barNode)
        }
        // Tinted visor
        let visor = SCNBox(width: 0.40, height: 0.13, length: 0.06, chamferRadius: 0.03)
        let visorMat = Art.pbr(UIColor(white: 0.05, alpha: 1), roughness: 0.15, metalness: 0.4)
        visorMat.specular.contents = UIColor.white
        visor.materials = [visorMat]
        let visorNode = SCNNode(geometry: visor)
        visorNode.position = SCNVector3(0, 0.02, 0.29)
        head.addChildNode(visorNode)
        let vbar = SCNCylinder(radius: 0.018, height: 0.16)
        vbar.materials = [barMat]
        let vbarNode = SCNNode(geometry: vbar)
        vbarNode.position = SCNVector3(0, -0.11, 0.34)
        head.addChildNode(vbarNode)
        // Helmet stripe
        let stripe = SCNBox(width: 0.07, height: 0.04, length: 0.52, chamferRadius: 0.02)
        stripe.materials = [Art.pbr(ink, roughness: 0.4)]
        let stripeNode = SCNNode(geometry: stripe)
        stripeNode.position = SCNVector3(0, 0.30, 0)
        head.addChildNode(stripeNode)

        // Arms: shoulder pivot -> upper arm -> elbow pivot -> forearm -> hand
        func buildArm(_ shoulder: SCNNode, _ elbow: SCNNode, side: Float) {
            shoulder.position = SCNVector3(side * 0.52 * bulk, 0.74, 0)
            let upper = SCNCapsule(capRadius: CGFloat(0.11 * bulk), height: 0.48)
            upper.materials = [jerseyMat]
            let upperNode = SCNNode(geometry: upper)
            upperNode.position = SCNVector3(0, -0.20, 0)
            shoulder.addChildNode(upperNode)
            elbow.position = SCNVector3(0, -0.40, 0)
            shoulder.addChildNode(elbow)
            let fore = SCNCapsule(capRadius: CGFloat(0.095 * bulk), height: 0.44)
            fore.materials = [skinMat]
            let foreNode = SCNNode(geometry: fore)
            foreNode.position = SCNVector3(0, -0.18, 0)
            elbow.addChildNode(foreNode)
            let hand = SCNSphere(radius: 0.10)
            hand.materials = [darkMat]   // gloves
            let handNode = SCNNode(geometry: hand)
            handNode.position = SCNVector3(0, -0.40, 0)
            elbow.addChildNode(handNode)
            torso.addChildNode(shoulder)
        }
        buildArm(leftShoulder, leftElbow, side: -1)
        buildArm(rightShoulder, rightElbow, side: 1)

        // Legs: hip pivot -> thigh -> knee pivot -> shin -> cleat
        func buildLeg(_ hip: SCNNode, _ knee: SCNNode, side: Float) {
            hip.position = SCNVector3(side * 0.18 * bulk, 1.12, 0)
            let thigh = SCNCapsule(capRadius: CGFloat(0.145 * bulk), height: 0.62)
            thigh.materials = [pantsMat]
            let thighNode = SCNNode(geometry: thigh)
            thighNode.position = SCNVector3(0, -0.27, 0)
            hip.addChildNode(thighNode)
            knee.position = SCNVector3(0, -0.55, 0)
            hip.addChildNode(knee)
            let shin = SCNCapsule(capRadius: CGFloat(0.11 * bulk), height: 0.55)
            shin.materials = [Art.pbr(UIColor(white: 0.92, alpha: 1), roughness: 0.8)]  // socks
            let shinNode = SCNNode(geometry: shin)
            shinNode.position = SCNVector3(0, -0.25, 0)
            knee.addChildNode(shinNode)
            let cleat = SCNBox(width: 0.2, height: 0.12, length: 0.36, chamferRadius: 0.05)
            cleat.materials = [darkMat]
            let cleatNode = SCNNode(geometry: cleat)
            cleatNode.position = SCNVector3(0, -0.55, 0.06)
            knee.addChildNode(cleatNode)
            body.addChildNode(hip)
        }
        buildLeg(leftHip, leftKnee, side: -1)
        buildLeg(rightHip, rightKnee, side: 1)

        node.addChildNode(body)

        // Blob shadow (in addition to the real shadow map: it anchors the figure to the turf)
        let shadowPlane = SCNPlane(width: 1.6, height: 1.6)
        shadowPlane.materials = [Art.sprite(Art.shadowSprite(), additive: false)]
        shadow.geometry = shadowPlane
        shadow.eulerAngles.x = -.pi / 2
        shadow.position = SCNVector3(0, 0.015, 0)
        shadow.castsShadow = false
        node.addChildNode(shadow)

        // Eligible-receiver ring
        let torus = SCNTorus(ringRadius: 0.85, pipeRadius: 0.06)
        torus.materials = [Art.glow(Art.gold, strength: 1.4)]
        ring.geometry = torus
        ring.position = SCNVector3(0, 0.04, 0)
        ring.castsShadow = false
        ring.isHidden = !showRing
        if showRing {
            ring.runAction(.repeatForever(.sequence([.scale(to: 1.12, duration: 0.8), .scale(to: 1.0, duration: 0.8)])))
        }
        node.addChildNode(ring)

        // Floating role tag
        let tagImage = Art.tagImage(tagText, tint: jersey)
        let tagHeight: CGFloat = tagText.contains("·") ? 0.42 : 0.34
        let tagPlane = SCNPlane(width: tagHeight * tagImage.size.width / tagImage.size.height, height: tagHeight)
        tagPlane.materials = [Art.sprite(tagImage, additive: false)]
        tag.geometry = tagPlane
        tag.position = SCNVector3(0, 2.85, 0)
        tag.constraints = [SCNBillboardConstraint()]
        tag.castsShadow = false
        node.addChildNode(tag)

        for child in [body, torso, head, helmet] { child.castsShadow = true }
        node.position = SCNVector3(player.pos.x, 0, player.pos.y)
        setFacing(player.facing)
        setStance(Self.presnapStance(for: role), animated: false)
    }

    // MARK: Per-frame update

    /// Move to the simulation position, advance the run cycle, and pick a pose from the state.
    func update(pos: FieldPoint, facing: FieldPoint, state: SimPlayer.State, dt: Float) {
        let moved = pos.distance(to: lastPos)
        let speed = dt > 0 ? moved / dt : 0
        smoothedSpeed += (speed - smoothedSpeed) * min(1, dt * 10)
        lastPos = pos
        node.position = SCNVector3(pos.x, 0, pos.y)
        if facing != .zero { setFacing(facing) }

        if case .down = state {
            if !isDown { isDown = true; setStance(.down, animated: true) }
            return
        }
        if smoothedSpeed > 0.6 {
            if currentStance != .run { setStance(.run, animated: true) }
            let stride: Float = 1.7 * max(0.7, min(1.2, smoothedSpeed / 7))
            phase += moved / stride * 2 * .pi
            let s = sin(phase), c = cos(phase)
            let amp: Float = 0.75 * min(1, smoothedSpeed / 6)
            leftHip.eulerAngles.x = amp * s
            rightHip.eulerAngles.x = -amp * s
            leftKnee.eulerAngles.x = -max(0, -amp * c) * 1.4 - 0.15
            rightKnee.eulerAngles.x = -max(0, amp * c) * 1.4 - 0.15
            leftShoulder.eulerAngles.x = -amp * s * 0.9
            rightShoulder.eulerAngles.x = amp * s * 0.9
            leftElbow.eulerAngles.x = -0.9
            rightElbow.eulerAngles.x = -0.9
            body.eulerAngles.x = min(0.42, smoothedSpeed / 8 * 0.42)   // lean into the run
            body.position.y = 0.06 * abs(s) * min(1, smoothedSpeed / 6)
            body.eulerAngles.z = 0.05 * c
        } else if currentStance == .run {
            setStance(.ready, animated: true)
        }
    }

    private func setFacing(_ f: FieldPoint) {
        node.eulerAngles.y = atan2(f.x, f.y)
    }

    // MARK: Stances

    static func presnapStance(for role: Role) -> Stance {
        switch role {
        case .offensiveLine, .defensiveLine: return .threePoint
        case .linebacker, .runningBack, .safety: return .crouch
        case .quarterback: return .ready
        case .wideReceiver, .tightEnd, .cornerback: return .twoPoint
        }
    }

    func resetToPresnap() {
        isDown = false
        phase = 0
        smoothedSpeed = 0
        node.eulerAngles.x = 0
        setStance(Self.presnapStance(for: role), animated: false)
    }

    func setStance(_ stance: Stance, animated: Bool) {
        currentStance = stance
        let apply = {
            self.body.position = SCNVector3(0, 0, 0)
            self.body.eulerAngles = SCNVector3(0, 0, 0)
            self.node.eulerAngles.x = 0
            switch stance {
            case .idle, .ready:
                self.body.eulerAngles.x = 0.08
                self.leftHip.eulerAngles.x = 0.05; self.rightHip.eulerAngles.x = -0.05
                self.leftKnee.eulerAngles.x = -0.12; self.rightKnee.eulerAngles.x = -0.12
                self.leftShoulder.eulerAngles.x = 0.35; self.rightShoulder.eulerAngles.x = 0.35
                self.leftElbow.eulerAngles.x = -1.3; self.rightElbow.eulerAngles.x = -1.3
            case .twoPoint:
                self.body.eulerAngles.x = 0.35
                self.leftHip.eulerAngles.x = -0.35; self.rightHip.eulerAngles.x = 0.45
                self.leftKnee.eulerAngles.x = -0.3; self.rightKnee.eulerAngles.x = -0.9
                self.leftShoulder.eulerAngles.x = 0.6; self.rightShoulder.eulerAngles.x = -0.3
                self.leftElbow.eulerAngles.x = -1.1; self.rightElbow.eulerAngles.x = -0.9
            case .crouch:
                self.body.eulerAngles.x = 0.45
                self.body.position.y = -0.18
                self.leftHip.eulerAngles.x = -0.55; self.rightHip.eulerAngles.x = -0.55
                self.leftKnee.eulerAngles.x = -1.0; self.rightKnee.eulerAngles.x = -1.0
                self.leftShoulder.eulerAngles.x = 0.5; self.rightShoulder.eulerAngles.x = 0.5
                self.leftElbow.eulerAngles.x = -1.4; self.rightElbow.eulerAngles.x = -1.4
            case .threePoint:
                self.body.eulerAngles.x = 0.95
                self.body.position.y = -0.36
                self.leftHip.eulerAngles.x = -0.9; self.rightHip.eulerAngles.x = -0.4
                self.leftKnee.eulerAngles.x = -1.6; self.rightKnee.eulerAngles.x = -1.2
                self.leftShoulder.eulerAngles.x = 0.2; self.rightShoulder.eulerAngles.x = 1.15
                self.leftElbow.eulerAngles.x = -1.5; self.rightElbow.eulerAngles.x = -0.1
            case .run:
                self.leftElbow.eulerAngles.x = -0.9; self.rightElbow.eulerAngles.x = -0.9
            case .down:
                self.node.eulerAngles.x = -.pi / 2 + 0.15
                self.body.position = SCNVector3(0, 0.35, 0.3)
                self.leftHip.eulerAngles.x = -0.5; self.rightHip.eulerAngles.x = 0.2
                self.leftKnee.eulerAngles.x = -0.8; self.rightKnee.eulerAngles.x = -0.3
                self.leftShoulder.eulerAngles.x = 2.4; self.rightShoulder.eulerAngles.x = 1.2
                self.leftElbow.eulerAngles.x = -0.5; self.rightElbow.eulerAngles.x = -1.0
            }
        }
        if animated {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = stance == .down ? 0.28 : 0.18
            apply()
            SCNTransaction.commit()
        } else {
            apply()
        }
    }

    func setRingVisible(_ visible: Bool) { ring.isHidden = !visible }
    func setRingEmphasis(_ on: Bool) {
        ring.removeAllActions()
        if on {
            ring.scale = SCNVector3(1.35, 1.35, 1.35)
            ring.runAction(.repeatForever(.sequence([.scale(to: 1.6, duration: 0.55), .scale(to: 1.3, duration: 0.55)])))
        } else {
            ring.scale = SCNVector3(1, 1, 1)
            if !ring.isHidden {
                ring.runAction(.repeatForever(.sequence([.scale(to: 1.12, duration: 0.8), .scale(to: 1.0, duration: 0.8)])))
            }
        }
    }
    func setTagVisible(_ visible: Bool) { tag.isHidden = !visible }
}
