import Foundation

enum RollSolver {
    static func advance(_ ball: BallState, by elapsed: Double, deceleration: Double, slope: Vector2 = .zero) -> BallState {
        guard elapsed > 0, deceleration > 0 else { return ball }
        let speed = ball.velocity.length
        if slope.length < 1e-10 {
            guard speed > 0 else { return ball }
            let stopTime = speed / deceleration, duration = min(elapsed, stopTime)
            let distance = speed * duration - deceleration * duration * duration / 2
            let direction = ball.velocity.normalized
            return BallState(position: ball.position + direction * distance,
                             velocity: duration >= stopTime ? .zero : direction * max(0, speed - deceleration * duration))
        }
        let gravity = slope * (-SimulationConfig.gravity / (1 + slope.dot(slope)))
        if speed <= SimulationConfig.stopSpeed && gravity.length <= deceleration * SimulationConfig.staticFrictionMultiplier {
            return BallState(position: ball.position)
        }
        let accelerated = ball.velocity + gravity * elapsed
        let velocity = accelerated.normalized * max(0, accelerated.length - deceleration * elapsed)
        return BallState(position: ball.position + velocity * elapsed, velocity: velocity)
    }
}
