import SceneKit
import UIKit

/// Builds the static world: turf, painted markers, pylons, goalposts, stands, wall, light towers, sky and lighting.
enum StadiumBuilder {
    static func buildField(into root: SCNNode, user: Team, opponent: Team) -> SCNNode {
        let plane = SCNPlane(width: Art.grassWidthYards, height: Art.grassLengthYards)
        let material = Art.textured(Art.grassImage(), roughness: 0.92)
        material.diffuse.wrapS = .clamp
        material.diffuse.wrapT = .clamp
        material.diffuse.contentsTransform = SCNMatrix4Identity
        plane.materials = [material]
        let field = SCNNode(geometry: plane)
        field.name = "field"
        // Plane top edge (local +y) maps to world -z after this rotation, matching image row 0 = z -16.
        field.eulerAngles.x = -.pi / 2
        field.position = SCNVector3(0, 0, 50)
        field.castsShadow = false
        root.addChildNode(field)

        // Painted end zones and the midfield crest sit just above the turf as small overlays,
        // so the big turf texture is generated once and shared by every game.
        func overlay(_ image: UIImage, width: CGFloat, height: CGFloat, z: Float) -> SCNNode {
            let p = SCNPlane(width: width, height: height)
            let m = Art.textured(image, roughness: 0.92)
            m.diffuse.wrapS = .clamp
            m.diffuse.wrapT = .clamp
            m.diffuse.contentsTransform = SCNMatrix4Identity
            m.transparency = 1
            p.materials = [m]
            let n = SCNNode(geometry: p)
            n.eulerAngles.x = -.pi / 2
            n.position = SCNVector3(0, 0.012, z)
            n.castsShadow = false
            n.renderingOrder = 1
            return n
        }
        root.addChildNode(overlay(Art.endZoneImage(team: user, goalLineAtTop: false), width: CGFloat(Field.width), height: 10, z: -5))
        root.addChildNode(overlay(Art.endZoneImage(team: opponent, goalLineAtTop: true), width: CGFloat(Field.width), height: 10, z: 105))
        let crest = overlay(Art.crestImage(team: user), width: 12, height: 12, z: 50)
        crest.geometry?.firstMaterial?.blendMode = .alpha
        crest.geometry?.firstMaterial?.transparencyMode = .aOne
        root.addChildNode(crest)

        // Dark apron far beyond the field so nothing reads as a void
        let apron = SCNPlane(width: 600, height: 600)
        apron.materials = [Art.pbr(UIColor(red: 0.05, green: 0.10, blue: 0.08, alpha: 1), roughness: 1)]
        let apronNode = SCNNode(geometry: apron)
        apronNode.eulerAngles.x = -.pi / 2
        apronNode.position = SCNVector3(0, -0.03, 50)
        apronNode.castsShadow = false
        root.addChildNode(apronNode)

        // Pylons at the goal-line and end-line corners
        let pylonGeo = SCNBox(width: 0.18, height: 0.5, length: 0.18, chamferRadius: 0.03)
        pylonGeo.materials = [Art.glow(UIColor(red: 1, green: 0.45, blue: 0.1, alpha: 1), strength: 0.6)]
        for z: Float in [-10, 0, 100, 110] {
            for x: Float in [-Field.halfWidth - 0.1, Field.halfWidth + 0.1] {
                let p = SCNNode(geometry: pylonGeo)
                p.position = SCNVector3(x, 0.25, z)
                root.addChildNode(p)
            }
        }
        return field
    }

    static func buildGoalposts(into root: SCNNode) {
        let yellow = Art.pbr(UIColor(red: 0.98, green: 0.80, blue: 0.20, alpha: 1), roughness: 0.35, metalness: 0.4)
        for (goalZ, dir) in [(Float(-Field.endZoneDepth), Float(1)), (Float(Field.length + Field.endZoneDepth), Float(-1))] {
            let post = SCNNode()
            func bar(_ w: CGFloat, _ h: CGFloat, _ d: CGFloat) -> SCNNode {
                let g = SCNCylinder(radius: max(w, d) / 2, height: h); g.materials = [yellow]
                return SCNNode(geometry: g)
            }
            let base = bar(0.35, CGFloat(Field.crossbarHeight), 0.35)
            base.position = SCNVector3(0, Field.crossbarHeight / 2, -dir * 1.2)
            // Gooseneck curve suggested by a tilted segment
            let neck = bar(0.3, 1.8, 0.3)
            neck.position = SCNVector3(0, Field.crossbarHeight - 0.2, -dir * 0.5)
            neck.eulerAngles.x = dir * 0.9
            let crossbar = bar(0.25, CGFloat(Field.uprightHalfWidth * 2), 0.25)
            crossbar.eulerAngles.z = .pi / 2
            crossbar.position = SCNVector3(0, Field.crossbarHeight, 0)
            let left = bar(0.22, CGFloat(Field.uprightHeight), 0.22)
            left.position = SCNVector3(-Field.uprightHalfWidth, Field.crossbarHeight + Field.uprightHeight / 2, 0)
            let right = bar(0.22, CGFloat(Field.uprightHeight), 0.22)
            right.position = SCNVector3(Field.uprightHalfWidth, Field.crossbarHeight + Field.uprightHeight / 2, 0)
            [base, neck, crossbar, left, right].forEach { post.addChildNode($0) }
            // Pad on the base
            let pad = SCNCylinder(radius: 0.5, height: 1.8)
            pad.materials = [Art.pbr(UIColor(red: 0.15, green: 0.2, blue: 0.5, alpha: 1), roughness: 0.9)]
            let padNode = SCNNode(geometry: pad)
            padNode.position = SCNVector3(0, 0.9, -dir * 1.2)
            post.addChildNode(padNode)
            post.position = SCNVector3(0, 0, goalZ)
            root.addChildNode(post)
        }
    }

    static func buildStands(into root: SCNNode) {
        let crowd = Art.textured(Art.crowdImage(), roughness: 1)
        crowd.diffuse.contentsTransform = SCNMatrix4MakeScale(12, 2, 1)
        let crowdEnd = Art.textured(Art.crowdImage(), roughness: 1)
        crowdEnd.diffuse.contentsTransform = SCNMatrix4MakeScale(9, 2, 1)
        let concrete = Art.pbr(UIColor(red: 0.16, green: 0.17, blue: 0.20, alpha: 1), roughness: 0.95)
        let wall = Art.textured(Art.wallImage(), roughness: 0.6)
        wall.diffuse.contentsTransform = SCNMatrix4MakeScale(8, 1, 1)
        let wallEnd = Art.textured(Art.wallImage(), roughness: 0.6)
        wallEnd.diffuse.contentsTransform = SCNMatrix4MakeScale(4, 1, 1)

        // Sideline stands: long raked slabs on both sides
        let sideLength: CGFloat = 150
        let riseHeight: CGFloat = 26
        for side: Float in [-1, 1] {
            let slab = SCNBox(width: riseHeight, height: 1.2, length: sideLength, chamferRadius: 0)
            slab.materials = [crowd]
            let slabNode = SCNNode(geometry: slab)
            slabNode.eulerAngles.z = side * 0.62
            slabNode.position = SCNVector3(side * (Field.halfWidth + 22), 9.5, 50)
            slabNode.castsShadow = false
            root.addChildNode(slabNode)
            // Concrete under the seating
            let underside = SCNBox(width: 22, height: 8, length: sideLength, chamferRadius: 0)
            underside.materials = [concrete]
            let underNode = SCNNode(geometry: underside)
            underNode.position = SCNVector3(side * (Field.halfWidth + 24), 3.5, 50)
            underNode.castsShadow = false
            root.addChildNode(underNode)
            // Sponsor wall at field edge
            let w = SCNBox(width: 0.6, height: 1.5, length: 122, chamferRadius: 0.05)
            w.materials = [wall]
            let wNode = SCNNode(geometry: w)
            wNode.position = SCNVector3(side * (Field.halfWidth + 6.5), 0.75, 50)
            root.addChildNode(wNode)
        }
        // End stands
        for (z, sign) in [(Float(-30), Float(-1)), (Float(130), Float(1))] {
            let slab = SCNBox(width: 110, height: 1.2, length: riseHeight, chamferRadius: 0)
            slab.materials = [crowdEnd]
            let slabNode = SCNNode(geometry: slab)
            slabNode.eulerAngles.x = -sign * 0.62
            slabNode.position = SCNVector3(0, 9.5, z + sign * 8)
            slabNode.castsShadow = false
            root.addChildNode(slabNode)
            let underside = SCNBox(width: 110, height: 8, length: 22, chamferRadius: 0)
            underside.materials = [concrete]
            let underNode = SCNNode(geometry: underside)
            underNode.position = SCNVector3(0, 3.5, z + sign * 10)
            underNode.castsShadow = false
            root.addChildNode(underNode)
            let w = SCNBox(width: 80, height: 1.5, length: 0.6, chamferRadius: 0.05)
            w.materials = [wallEnd]
            let wNode = SCNNode(geometry: w)
            wNode.position = SCNVector3(0, 0.75, z + sign * -8)
            root.addChildNode(wNode)
        }
    }

    static func buildLightTowers(into root: SCNNode) {
        let mast = Art.pbr(UIColor(white: 0.25, alpha: 1), roughness: 0.6, metalness: 0.5)
        let headMat = Art.glow(UIColor(red: 1, green: 0.97, blue: 0.88, alpha: 1), strength: 3.0)
        let glowSprite = Art.sprite(Art.glowSprite(), additive: true)
        for (x, z) in [(Float(-52), Float(-22)), (Float(52), Float(-22)), (Float(-52), Float(122)), (Float(52), Float(122))] {
            let pole = SCNCylinder(radius: 0.5, height: 48)
            pole.materials = [mast]
            let poleNode = SCNNode(geometry: pole)
            poleNode.position = SCNVector3(x, 24, z)
            root.addChildNode(poleNode)
            let head = SCNBox(width: 9, height: 4, length: 1.2, chamferRadius: 0.2)
            head.materials = [headMat]
            let headNode = SCNNode(geometry: head)
            headNode.position = SCNVector3(x, 47, z)
            headNode.look(at: SCNVector3(0, 0, 50))
            root.addChildNode(headNode)
            let glowPlane = SCNPlane(width: 26, height: 26)
            glowPlane.materials = [glowSprite]
            let glowNode = SCNNode(geometry: glowPlane)
            glowNode.position = SCNVector3(x, 47, z)
            glowNode.constraints = [SCNBillboardConstraint()]
            glowNode.castsShadow = false
            root.addChildNode(glowNode)
        }
    }

    static func buildLighting(scene: SCNScene, root: SCNNode) {
        let sky = Art.skyImage()
        scene.background.contents = sky
        scene.lightingEnvironment.contents = sky
        scene.lightingEnvironment.intensity = 1.2
        scene.fogColor = UIColor(red: 0.06, green: 0.09, blue: 0.16, alpha: 1)
        scene.fogStartDistance = 120
        scene.fogEndDistance = 320
        scene.fogDensityExponent = 1.5

        // Key light: high stadium light from the near-left, with a soft shadow map
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = 1400
        key.light?.color = UIColor(red: 1.0, green: 0.96, blue: 0.88, alpha: 1)
        key.light?.castsShadow = true
        key.light?.shadowMode = .deferred
        key.light?.shadowMapSize = CGSize(width: 2048, height: 2048)
        key.light?.shadowSampleCount = 8
        key.light?.shadowRadius = 4
        key.light?.shadowColor = UIColor(red: 0.02, green: 0.05, blue: 0.1, alpha: 0.55)
        key.light?.orthographicScale = 40
        key.light?.zFar = 200
        key.light?.automaticallyAdjustsShadowProjection = true
        key.eulerAngles = SCNVector3(-1.15, 0.7, 0)
        root.addChildNode(key)

        // Rim/fill from the far side, cool
        let rim = SCNNode()
        rim.light = SCNLight()
        rim.light?.type = .directional
        rim.light?.intensity = 500
        rim.light?.color = UIColor(red: 0.6, green: 0.72, blue: 1.0, alpha: 1)
        rim.eulerAngles = SCNVector3(-0.7, 2.6, 0)
        root.addChildNode(rim)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 260
        ambient.light?.color = UIColor(red: 0.75, green: 0.82, blue: 1.0, alpha: 1)
        root.addChildNode(ambient)
    }

    static func makeCamera() -> SCNCamera {
        let camera = SCNCamera()
        camera.fieldOfView = 64
        camera.projectionDirection = .vertical
        camera.zNear = 0.3
        camera.zFar = 600
        camera.wantsHDR = true
        camera.wantsExposureAdaptation = false
        camera.exposureOffset = 0.15
        camera.bloomIntensity = 0.55
        camera.bloomThreshold = 0.72
        camera.bloomBlurRadius = 10
        camera.vignettingPower = 0.9
        camera.vignettingIntensity = 0.55
        camera.saturation = 1.02
        camera.contrast = 0.08
        camera.screenSpaceAmbientOcclusionIntensity = 0.7
        camera.screenSpaceAmbientOcclusionRadius = 1.5
        camera.wantsDepthOfField = false
        camera.fStop = 5.6
        camera.focalBlurSampleCount = 12
        return camera
    }
}
