import SpriteKit
import OffsideGolfCore

@MainActor
final class BallRenderer {
    let node = SKNode()
    private let shadow = SKShapeNode(ellipseOf: CGSize(width: 10,height: 4))
    private let ball = SKShapeNode(circleOfRadius: 4)
    init() {
        shadow.fillColor = .black.withAlphaComponent(0.22); shadow.strokeColor = .clear
        ball.fillColor = .white;ball.strokeColor = .init(white: 0.3,alpha: 1);ball.lineWidth = 0.6
        node.addChild(shadow);node.addChild(ball);node.zPosition = 20
    }
    func render(_ state: GameState, projection: WorldProjection, visualScale: CGFloat = 1) {
        ball.position = projection.point(for: state.ball.position,altitude: state.ball.altitude)
        shadow.position = projection.point(for: state.ball.position)
        ball.setScale(visualScale * (1 + min(0.4,state.ball.altitude/60)))
        shadow.setScale(visualScale)
        ball.isHidden = state.phase == .complete;shadow.isHidden = ball.isHidden
    }
}
