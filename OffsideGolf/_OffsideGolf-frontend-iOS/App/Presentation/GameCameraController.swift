import CoreGraphics
import OffsideGolfCore

enum CameraMode: Equatable { case holeOverview, playerSetup, aiming, ballFlight, ballLanding, putting, celebration }

struct CameraPose: Equatable { var position: CGPoint; var scale: CGFloat }

struct GameCameraController {
    private(set) var mode: CameraMode = .holeOverview
    private var pose: CameraPose?
    private var introElapsed = 0.0
    var overviewEnabled = false

    // Kept as a useful flat-world fitting primitive for tooling and projection tests.
    func worldBounds(hole: HoleDefinition, club: PracticeClub) -> CGRect {
        if club == .putter { return CGRect(x: hole.green.center.x - 19,y: hole.green.center.y - 19,width: 38,height: 38) }
        return CGRect(x: 0,y: 0,width: hole.bounds.width,height: hole.bounds.height)
    }
    func projection(hole: HoleDefinition, club: PracticeClub, viewport: CGSize) -> WorldProjection {
        WorldProjection(worldBounds: worldBounds(hole: hole, club: club), viewport: viewport)
    }
    mutating func reset() { overviewEnabled = false; pose = nil }
    mutating func update(hole: HoleDefinition, state: GameState, projection: WorldProjection,
                         viewport: CGSize, elapsed: Double, reducedMotion: Bool) -> CameraPose {
        introElapsed += elapsed
        let ball = state.ball.position
        let moving = state.phase == .inFlight || state.phase == .rolling
        mode = overviewEnabled || (introElapsed < 1.2 && !reducedMotion) ? .holeOverview
            : state.phase == .complete ? .celebration
            : state.club == .putter ? .putting
            : moving ? (state.ball.altitude > 8 ? .ballFlight : .ballLanding)
            : state.phase == .charging ? .aiming : .playerSetup
        let bounds: CGRect
        switch mode {
        case .holeOverview: bounds = CGRect(x: 0,y: 0,width: hole.bounds.width,height: hole.bounds.height)
        case .putting, .celebration:
            bounds = fit(a: ball,b: hole.pin,minimum: 30,margin: 9)
        case .ballFlight, .ballLanding:
            let ahead = ball + state.ball.velocity.normalized * (mode == .ballFlight ? 20 : 6)
            bounds = fit(a: ball,b: ahead,minimum: mode == .ballFlight ? 78 : 48,margin: 10)
        case .aiming, .playerSetup:
            let distance = min(state.club.maximumDistanceMeters,ball.distance(to: hole.pin))
            let target = ball + state.aimDirection * max(30,distance * 0.75)
            bounds = fit(a: ball,b: target,minimum: 65,margin: 16)
        }
        let center = Vector2(x: bounds.midX,y: bounds.midY)
        let target = CameraPose(position: projection.point(for: center),
            scale: max(bounds.width * projection.scale / max(1,viewport.width-20),
                       bounds.height * sin(65 * .pi / 180) * projection.scale / max(1,viewport.height-20)))
        guard let old = pose, !reducedMotion else { pose = target; return target }
        let blend = 1 - exp(-min(0.1,max(0,elapsed)) * 6)
        let updated = CameraPose(position: CGPoint(x: old.position.x+(target.position.x-old.position.x)*blend,
                                                   y: old.position.y+(target.position.y-old.position.y)*blend),
                                 scale: old.scale+(target.scale-old.scale)*blend)
        pose = updated; return updated
    }
    private func fit(a: Vector2,b: Vector2,minimum: Double,margin: Double) -> CGRect {
        let width = max(minimum,abs(a.x-b.x)+margin*2),height = max(minimum,abs(a.y-b.y)+margin*2)
        return CGRect(x: (a.x+b.x-width)/2,y: (a.y+b.y-height)/2,width: width,height: height)
    }
}
