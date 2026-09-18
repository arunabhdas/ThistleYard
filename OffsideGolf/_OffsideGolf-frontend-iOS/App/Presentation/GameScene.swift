import SpriteKit
import OffsideGolfCore

@MainActor
final class GameScene: SKScene {
    var onFrame: ((TimeInterval) -> Void)?
    var onAim: ((Vector2) -> Void)?
    var settings = GameSettings() { didSet { projection = nil } }
    var appearance = GolferAppearance()
    var prediction: ShotPrediction?
    private var hole: HoleDefinition
    private let terrain = TerrainRenderer()
    private let ball = BallRenderer()
    private let golfer = GolferRenderer()
    private var cameraController = GameCameraController()
    private let cameraNode = SKCameraNode()
    private let aimGuide = SKShapeNode()
    private let landing = SKShapeNode()
    private var latestState: GameState?
    private var projection: WorldProjection?
    #if DEBUG
    var debugGeometry = false { didSet { projection = nil } }
    var debugTrajectory = false
    #endif

    init(hole: HoleDefinition) {
        self.hole = hole
        super.init(size: CGSize(width: 360,height: 420))
        scaleMode = .resizeFill
        backgroundColor = .init(red: 0.40,green: 0.56,blue: 0.37,alpha: 1)
        addChild(terrain.node);addChild(aimGuide);addChild(landing);addChild(golfer.node);addChild(ball.node)
        addChild(cameraNode);camera = cameraNode
        aimGuide.zPosition = 10;landing.zPosition = 10;golfer.node.zPosition = 12
        landing.fillColor = .white.withAlphaComponent(0.10);landing.strokeColor = .white
    }
    required init?(coder: NSCoder) { fatalError("Use init(hole:)") }
    override func update(_ currentTime: TimeInterval) { onFrame?(currentTime) }
    override func didChangeSize(_ oldSize: CGSize) {
        projection = nil;cameraController.reset()
        if let latestState { render(latestState) }
    }
    func resetCamera() { cameraController.reset() }
    func toggleOverview() { cameraController.overviewEnabled.toggle() }
    func practiceSwing() { golfer.practiceSwing() }
    #if DEBUG
    func updateHole(_ hole: HoleDefinition) { self.hole = hole; prediction = nil; projection = nil }
    #endif
    func render(_ state: GameState, elapsed: Double = 0) {
        latestState = state
        if projection == nil {
            projection = WorldProjection(worldBounds: CGRect(x: 0,y: 0,width: hole.bounds.width,height: hole.bounds.height),viewport: size,hole: hole)
            if let projection {
                terrain.rebuild(hole: hole,projection: projection,slopeGuide: settings.slopeGuide)
                #if DEBUG
                if debugGeometry { terrain.showDebugGeometry(hole: hole,projection: projection) }
                #endif
            }
        }
        guard let projection else { return }
        let pose = cameraController.update(hole: hole,state: state,projection: projection,viewport: size,
                                           elapsed: elapsed,reducedMotion: settings.reducedMotion)
        cameraNode.position = pose.position;cameraNode.setScale(pose.scale)
        ball.render(state,projection: projection,visualScale: pose.scale)
        golfer.render(state: state,projection: projection,appearance: appearance,reducedMotion: settings.reducedMotion,elapsed: elapsed,visualScale: pose.scale)
        terrain.animate(elapsed: state.phase == .paused ? 0 : elapsed,ball: state.ball.position,reducedMotion: settings.reducedMotion,visualScale: pose.scale)
        let visible = state.phase == .aiming || state.phase == .charging
        aimGuide.isHidden = !visible;landing.isHidden = !visible
        if visible {
            let path = CGMutablePath();path.move(to: projection.point(for: state.ball.position))
            if let prediction {
                for sample in prediction.samples {
                    path.addLine(to: projection.point(for: sample.position,altitude: sample.altitude))
                    #if DEBUG
                    if !debugTrajectory && sample.altitude == 0 && sample.position != state.ball.position { break }
                    #else
                    if sample.altitude == 0 && sample.position != state.ball.position { break }
                    #endif
                }
                let point = prediction.firstLanding ?? prediction.finalPosition
                let radius = prediction.landingRadiusMeters * projection.scale
                landing.path = CGPath(ellipseIn: CGRect(x: -radius,y: -radius*0.9,width: radius*2,height: radius*1.8),transform: nil)
                landing.position = projection.point(for: point);landing.lineWidth = 1.5*pose.scale
            } else {
                path.addLine(to: projection.point(for: state.ball.position+state.aimDirection*30));landing.isHidden = true
            }
            aimGuide.path = path.copy(dashingWithPhase: 0,lengths: [4*pose.scale,4*pose.scale])
            aimGuide.strokeColor = settings.highContrast ? .black : .white
            aimGuide.lineWidth = (settings.highContrast ? 3 : 2)*pose.scale
        }
    }
    func show(_ event: SimulationEvent) {
        guard let projection, [.splash,.sand,.cupCapture,.bounce].contains(event.kind) else { return }
        let ring = SKShapeNode(circleOfRadius: event.kind == .cupCapture ? 10 : 5)
        ring.position = projection.point(for: event.position);ring.zPosition = 22
        ring.strokeColor = event.kind == .sand ? .init(red: 0.94,green: 0.81,blue: 0.56,alpha: 1) : .white
        ring.lineWidth = 2;ring.setScale(cameraNode.xScale);addChild(ring)
        ring.run(.sequence([.group([.scale(by: settings.reducedMotion ? 1 : 2.2,duration: 0.45),.fadeOut(withDuration: 0.45)]),.removeFromParent()]))
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { aim(touches) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { aim(touches) }
    private func aim(_ touches: Set<UITouch>) {
        guard let touch = touches.first,let projection,
              latestState?.phase == .aiming || latestState?.phase == .charging else { return }
        onAim?(projection.groundPoint(at: touch.location(in: self)))
    }
}
