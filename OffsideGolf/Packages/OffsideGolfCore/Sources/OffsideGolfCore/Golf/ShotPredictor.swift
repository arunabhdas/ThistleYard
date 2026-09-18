import Foundation

public struct ShotPrediction: Sendable {
    public let samples: [BallState]
    public let firstLanding: Vector2?
    public let finalPosition: Vector2
    public let outcome: ShotOutcome?
    public let captured: Bool
    public var landingRadiusMeters: Double {
        guard let first = samples.first?.position, let landing = firstLanding else { return 2 }
        return max(2, first.distance(to: landing) * 0.03)
    }
}
public enum ShotPredictor {
    /// The app caches this by shot inputs and throttles refresh to at most 15 Hz.
    public static func predict(hole: HoleDefinition, state: GameState, power: Double) -> ShotPrediction {
        var game = GameReducer(hole: hole, previewState: state)
        game.send(.beginCharge); game.send(.setPower(power)); game.send(.release)
        var samples = [game.state.ball]
        for tick in 0..<3800 {
            game.advance(by: SimulationConfig.fixedStep)
            if tick % 12 == 0 { samples.append(game.state.ball) }
            if game.state.phase == .aiming || game.state.phase == .complete { break }
        }
        samples.append(game.state.ball)
        return ShotPrediction(samples: samples, firstLanding: game.state.firstLanding, finalPosition: game.state.ball.position,
                              outcome: game.state.lastOutcome, captured: game.state.phase == .complete)
    }
}
public enum ClubRecommendation {
    public static func recommend(hole: HoleDefinition, position: Vector2, target: Vector2) -> GolfClubType {
        let lie = hole.terrain(at: position)
        if lie == .green { return .putter }
        if lie == .bunker { return .sandWedge }
        let distance = position.distance(to: target)
        let legal = GolfClubType.allCases.filter { $0 != .putter && !(lie == .deepRough && $0 == .driver) }
        let direction = (target - position).normalized
        for club in legal.reversed() {
            let ball = FlightSolver.launch(position: position, direction: direction, power: 0.9,
                                           club: club, drag: SimulationConfig.drag, launchFactor: lie.launchFactor)
            var simulation = ShotSimulation(ball: ball,phase: .inFlight)
            for _ in 0..<1500 {
                let step = simulation.advance(hole: hole,club: club,by: SimulationConfig.fixedStep)
                if let landing = step.firstLanding {
                    if (landing - position).dot(direction) >= distance { return club }
                    break
                }
                if step.hazard != nil || simulation.phase != .inFlight { break }
            }
        }
        return legal.first ?? .fiveIron
    }
}
