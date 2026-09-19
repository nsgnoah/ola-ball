import SceneKit
import UIKit

/// Drawn-path ribbon, glowing field markers, particles.
enum Effects {
    /// A flat glowing ribbon along the points, with dashes that flow in the direction of travel.
    static func pathRibbon(_ points: [FieldPoint], color: UIColor, width: Float = 0.55) -> SCNNode {
        let group = SCNNode()
        guard points.count > 1 else { return group }
        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var uvs: [CGPoint] = []
        var indices: [Int32] = []
        var distance: Float = 0
        for i in 0..<points.count {
            let p = points[i]
            let prev = i > 0 ? points[i - 1] : p
            let next = i < points.count - 1 ? points[i + 1] : p
            var dir = (next - prev).normalized
            if dir == .zero { dir = FieldPoint(0, 1) }
            let side = FieldPoint(dir.y, -dir.x) * (width / 2)
            if i > 0 { distance += p.distance(to: prev) }
            vertices.append(SCNVector3(p.x - side.x, 0.035, p.y - side.y))
            vertices.append(SCNVector3(p.x + side.x, 0.035, p.y + side.y))
            normals.append(SCNVector3(0, 1, 0)); normals.append(SCNVector3(0, 1, 0))
            uvs.append(CGPoint(x: CGFloat(distance / 1.5), y: 0))
            uvs.append(CGPoint(x: CGFloat(distance / 1.5), y: 1))
            if i > 0 {
                let b = Int32(i * 2)
                indices.append(contentsOf: [b - 2, b - 1, b, b - 1, b + 1, b])
            }
        }
        let src = SCNGeometrySource(vertices: vertices)
        let nrm = SCNGeometrySource(normals: normals)
        let tex = SCNGeometrySource(textureCoordinates: uvs)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geo = SCNGeometry(sources: [src, nrm, tex], elements: [element])
        let m = SCNMaterial()
        m.lightingModel = .constant
        m.diffuse.contents = Art.dashImage()
        m.diffuse.wrapS = .repeat
        m.multiply.contents = color
        m.emission.contents = color
        m.emission.intensity = 0.9
        m.isDoubleSided = true
        m.blendMode = .alpha
        m.writesToDepthBuffer = false
        m.readsFromDepthBuffer = true
        geo.materials = [m]
        let ribbon = SCNNode(geometry: geo)
        ribbon.castsShadow = false
        // Flowing dashes
        let flow = CABasicAnimation(keyPath: "contentsTransform")
        flow.fromValue = NSValue(scnMatrix4: SCNMatrix4MakeTranslation(0, 0, 0))
        flow.toValue = NSValue(scnMatrix4: SCNMatrix4MakeTranslation(-1, 0, 0))
        flow.duration = 0.9
        flow.repeatCount = .infinity
        m.diffuse.addAnimation(flow, forKey: "flow")
        group.addChildNode(ribbon)
        // Arrowhead at the end
        if let last = points.last, points.count >= 2 {
            let prev = points[points.count - 2]
            let dir = (last - prev).normalized
            let tip = SCNNode(geometry: {
                let cone = SCNCone(topRadius: 0, bottomRadius: 0.55, height: 1.0)
                cone.materials = [Art.glow(color, strength: 1.2)]
                return cone
            }())
            tip.position = SCNVector3(last.x + dir.x * 0.3, 0.05, last.y + dir.y * 0.3)
            tip.eulerAngles = SCNVector3(.pi / 2, atan2(dir.x, dir.y), 0)
            tip.castsShadow = false
            group.addChildNode(tip)
        }
        return group
    }

    /// Full-width painted marker line (scrimmage or first down) with a soft glow.
    static func markerLine(color: UIColor, z: Float, width: Float = 0.28) -> SCNNode {
        let box = SCNBox(width: CGFloat(Field.width), height: 0.02, length: CGFloat(width), chamferRadius: 0)
        box.materials = [Art.glow(color, strength: 0.8)]
        let node = SCNNode(geometry: box)
        node.position = SCNVector3(0, 0.02, z)
        node.castsShadow = false
        return node
    }

    static func confetti(colors: [UIColor]) -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.particleImage = Art.confettiSprite()
        ps.birthRate = 700
        ps.emissionDuration = 1.6
        ps.particleLifeSpan = 3.6
        ps.particleLifeSpanVariation = 0.8
        ps.particleSize = 0.22
        ps.particleSizeVariation = 0.1
        ps.particleVelocity = 9
        ps.particleVelocityVariation = 5
        ps.spreadingAngle = 60
        ps.emittingDirection = SCNVector3(0, 1, 0)
        ps.acceleration = SCNVector3(0, -6, 0)
        ps.particleAngularVelocity = 300
        ps.particleAngularVelocityVariation = 200
        ps.dampingFactor = 1.5
        ps.blendMode = .alpha
        ps.isLightingEnabled = false
        ps.particleColor = colors.first ?? .white
        ps.particleColorVariation = SCNVector4(0.3, 0.3, 0.3, 0)
        ps.emitterShape = SCNSphere(radius: 1.5)
        return ps
    }

    static func turfBurst() -> SCNParticleSystem {
        let ps = SCNParticleSystem()
        ps.particleImage = Art.confettiSprite()
        ps.birthRate = 400
        ps.emissionDuration = 0.12
        ps.particleLifeSpan = 0.8
        ps.particleSize = 0.12
        ps.particleSizeVariation = 0.06
        ps.particleVelocity = 5
        ps.particleVelocityVariation = 3
        ps.spreadingAngle = 70
        ps.emittingDirection = SCNVector3(0, 1, 0)
        ps.acceleration = SCNVector3(0, -14, 0)
        ps.particleColor = UIColor(red: 0.25, green: 0.45, blue: 0.2, alpha: 1)
        ps.particleColorVariation = SCNVector4(0.1, 0.1, 0.05, 0)
        ps.isLightingEnabled = false
        ps.emitterShape = SCNSphere(radius: 0.4)
        return ps
    }

    static func makeBall() -> SCNNode {
        let sphere = SCNSphere(radius: 0.29)
        sphere.segmentCount = 32
        let m = Art.textured(Art.ballImage(), roughness: 0.55)
        m.diffuse.wrapS = .repeat
        sphere.materials = [m]
        let ball = SCNNode(geometry: sphere)
        ball.scale = SCNVector3(0.72, 0.72, 1.25)
        ball.name = "ball"
        ball.castsShadow = true
        return ball
    }
}
