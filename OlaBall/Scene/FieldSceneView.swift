import SwiftUI
import SceneKit

/// Hosts the SceneKit field, drives the simulation clock, and turns finger drags into play paths.
struct FieldSceneView: UIViewRepresentable {
    let session: GameSession

    func makeCoordinator() -> Coordinator { Coordinator(session: session) }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = session.fieldScene.scene
        view.pointOfView = session.fieldScene.cameraNode
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        view.rendersContinuously = true
        view.preferredFramesPerSecond = 60
        view.allowsCameraControl = false
        view.delegate = context.coordinator
        view.isUserInteractionEnabled = true
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)
        context.coordinator.view = view
        session.fieldScene.aimCamera(at: FieldPoint(0, Float(session.situation.ballOn)), presnap: true, animated: false)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}

    final class Coordinator: NSObject, SCNSceneRendererDelegate {
        let session: GameSession
        weak var view: SCNView?
        private var lastTime: TimeInterval?
        private var drawing: [FieldPoint] = []
        private var drawingTag: String?

        init(session: GameSession) { self.session = session }

        // Called on the SceneKit render thread; hop to main for state.
        func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            let dt: Float
            if let last = lastTime { dt = Float(min(1.0 / 30.0, time - last)) } else { dt = 1.0 / 60.0 }
            lastTime = time
            DispatchQueue.main.async { [session] in
                session.advance(dt: dt)
            }
        }

        @objc func handlePan(_ g: UIPanGestureRecognizer) {
            guard let view, session.canDraw else { return }
            let point = g.location(in: view)
            switch g.state {
            case .began:
                drawing = []
                drawingTag = nil
                if let player = session.fieldScene.player(from: view, at: point, among: session.presnapPlayers) {
                    drawingTag = player.tag
                    drawing = [player.pos]
                    session.fieldScene.highlight(playerID: player.id, on: true)
                    Haptics.tap()
                }
            case .changed:
                guard drawingTag != nil, let fp = session.fieldScene.fieldPoint(from: view, at: point) else { return }
                let clamped = FieldPoint(max(-Field.halfWidth - 1, min(Field.halfWidth + 1, fp.x)), max(-8, min(108, fp.y)))
                if let last = drawing.last, last.distance(to: clamped) < 0.9 { return }
                drawing.append(clamped)
                session.fieldScene.showPath(drawing, color: UIColor(red: 0.96, green: 0.77, blue: 0.26, alpha: 1))
                session.previewPath(drawing)
            case .ended:
                defer { drawingTag = nil; drawing = []; session.fieldScene.highlight(playerID: nil, on: false) }
                guard let tag = drawingTag else { return }
                let plan = PlayPlan(ballHandlerTag: tag, path: drawing)
                if plan.pathLength >= 3 {
                    session.startUserPlay(plan)
                } else {
                    session.fieldScene.clearPath()
                    session.previewPath([])
                }
            default:
                drawingTag = nil; drawing = []
                session.fieldScene.clearPath()
                session.fieldScene.highlight(playerID: nil, on: false)
                session.previewPath([])
            }
        }
    }
}
