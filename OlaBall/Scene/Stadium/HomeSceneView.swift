import SwiftUI
import SceneKit

/// The stadium as a living backdrop: warm-ups on the field, a slow flyover camera. Pauses while a game is up.
struct HomeSceneView: UIViewRepresentable {
    let userTeam: Team
    let opponentTeam: Team
    var paused: Bool

    func makeCoordinator() -> Coordinator { Coordinator(userTeam: userTeam, opponentTeam: opponentTeam) }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = context.coordinator.scene.scene
        view.pointOfView = context.coordinator.scene.cameraNode
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        view.rendersContinuously = true
        view.preferredFramesPerSecond = 60
        view.delegate = context.coordinator
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        uiView.isPlaying = !paused
        uiView.rendersContinuously = !paused
    }

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        let scene: StadiumScene
        private var lastTime: TimeInterval?

        init(userTeam: Team, opponentTeam: Team) {
            scene = StadiumScene(userTeam: userTeam, opponentTeam: opponentTeam)
            scene.beginWarmup()
        }

        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            let dt: Float = lastTime.map { Float(min(1.0 / 20.0, time - $0)) } ?? 1.0 / 60.0
            lastTime = time
            scene.tickWarmup(dt: dt)
        }
    }
}
