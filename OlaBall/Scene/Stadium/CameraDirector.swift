import SceneKit
import UIKit

/// Cinematic camera: framed pre-snap shot with a slow drift, damped follow during the play, bullet-time on contact.
final class CameraDirector {
    let node = SCNNode()
    private(set) var timeScale: Float = 1

    private var desiredPosition = SCNVector3(0, 22, -26)
    private var desiredLook = SCNVector3(0, 0, 9)
    private var currentPosition = SCNVector3(0, 22, -26)
    private var currentLook = SCNVector3(0, 0, 9)
    private var driftTime: Float = 0
    private var presnap = true
    private var slowUntil: Float = -1
    private var clock: Float = 0

    init() {
        node.camera = StadiumBuilder.makeCamera()
        node.position = currentPosition
        node.look(at: currentLook)
    }

    /// Pre-snap framing: high and behind the offense. Everything from the backfield to both safeties is on screen.
    func framePresnap(los: Float, animated: Bool) {
        presnap = true
        timeScale = 1
        desiredPosition = SCNVector3(0, 27, los - 32)
        desiredLook = SCNVector3(0, 0.5, los + 7)
        node.camera?.wantsDepthOfField = true
        node.camera?.motionBlurIntensity = 0
        node.camera?.focusDistance = CGFloat(hypot(desiredPosition.y, desiredLook.z - desiredPosition.z))
        if animated {
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.9
            SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            node.position = desiredPosition
            node.look(at: desiredLook)
            SCNTransaction.commit()
        } else {
            node.position = desiredPosition
            node.look(at: desiredLook)
        }
        currentPosition = desiredPosition
        currentLook = desiredLook
    }

    /// Horizontal half-extent visible at a given slant distance, for this lens on a portrait screen.
    static let halfWidthPerYard: Float = 0.2875   // tan(32°) * (402/874)

    /// Called every frame while the play is live. `subjects` are the points that must stay on screen
    /// (ball, intended receiver, nearest defender); the camera pulls back just enough to hold them all.
    func follow(ball: FieldPoint, ballHeight: Float, subjects: [FieldPoint], contactDistance: Float?, ballInAir: Bool, dt: Float) {
        presnap = false
        node.camera?.wantsDepthOfField = false
        node.camera?.motionBlurIntensity = 0.5
        clock += dt
        // Bullet time: slow down when contact is imminent or the ball is in flight.
        if let d = contactDistance, d < 2.6 { slowUntil = clock + 0.35 }
        let target: Float = clock < slowUntil ? 0.32 : (ballInAir ? 0.7 : 1.0)
        timeScale += (target - timeScale) * min(1, dt * 8)

        // Frame center: weighted toward the ball, pulled toward the other subjects.
        let all = [ball] + subjects
        let minX = all.map(\.x).min()!, maxX = all.map(\.x).max()!
        let minY = all.map(\.y).min()!, maxY = all.map(\.y).max()!
        let center = FieldPoint((minX + maxX) / 2 * 0.6 + ball.x * 0.4, (minY + maxY) / 2 * 0.4 + ball.y * 0.6)
        let halfExtent = max((maxX - minX) / 2 + 2.5, (maxY - minY) * 0.18 + 2.5)
        let baseSlant: Float = 21
        let neededSlant = halfExtent / CameraDirector.halfWidthPerYard
        let zoom = max(1, min(2.2, neededSlant / baseSlant))

        let back: Float = (16 + min(6, ballHeight * 0.4)) * zoom
        let height: Float = (12.5 + ballHeight * 0.5) * zoom
        desiredPosition = SCNVector3(center.x * 0.35, height, center.y - back)
        desiredLook = SCNVector3(center.x * 0.8, 0.8 + ballHeight * 0.5, center.y + 2.5)
        let k = min(1, dt * 4.5)
        currentPosition = lerp(currentPosition, desiredPosition, k)
        currentLook = lerp(currentLook, desiredLook, min(1, dt * 6))
        node.position = currentPosition
        node.look(at: currentLook)
    }

    /// Replay: a low cable-cam on the sideline, gliding with the ball in slow motion.
    func beginReplay(at focus: FieldPoint) {
        presnap = false
        timeScale = 1
        node.camera?.wantsDepthOfField = false
        node.camera?.motionBlurIntensity = 0.2
        currentPosition = SCNVector3(20, 4.5, focus.y - 8)
        currentLook = SCNVector3(0, 1.2, focus.y)
        node.position = currentPosition
        node.look(at: currentLook)
    }

    func replayFollow(ball: FieldPoint, ballHeight: Float, dt: Float) {
        desiredPosition = SCNVector3(19, 4.0 + ballHeight * 0.3, ball.y - 5)
        desiredLook = SCNVector3(ball.x, 1.0 + ballHeight * 0.4, ball.y + 0.5)
        currentPosition = lerp(currentPosition, desiredPosition, min(1, dt * 3))
        currentLook = lerp(currentLook, desiredLook, min(1, dt * 5))
        node.position = currentPosition
        node.look(at: currentLook)
    }

    /// Slow drift while waiting for the snap; keeps the frame alive.
    func idle(dt: Float) {
        guard presnap else { return }
        driftTime += dt
        let sway = sin(driftTime * 0.5) * 0.9
        let bob = sin(driftTime * 0.33) * 0.25
        node.position = SCNVector3(desiredPosition.x + sway, desiredPosition.y + bob, desiredPosition.z)
        node.look(at: desiredLook)
    }

    /// Hold on the end of the play. The HUD covers the bottom ~45% of the screen, so the subject is framed
    /// in the upper half: the camera looks at a point short of the ball, which lifts the ball above center.
    func holdOnResult(focus: FieldPoint, big: Bool) {
        timeScale = 1
        node.camera?.motionBlurIntensity = 0
        SCNTransaction.begin()
        SCNTransaction.animationDuration = big ? 1.6 : 0.9
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeOut)
        let side: Float = big ? 10 : 6
        let height: Float = big ? 10 : 14
        let back: Float = big ? 12 : 16
        node.position = SCNVector3(focus.x + side, height, focus.y - back)
        node.look(at: SCNVector3(focus.x + side * 0.15, 0.4, focus.y - 3.5))
        SCNTransaction.commit()
        currentPosition = node.position
    }

    private func lerp(_ a: SCNVector3, _ b: SCNVector3, _ t: Float) -> SCNVector3 {
        SCNVector3(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t)
    }
}
