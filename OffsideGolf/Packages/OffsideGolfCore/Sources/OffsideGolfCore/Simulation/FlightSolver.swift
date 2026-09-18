import Foundation

/// Analytical linear drag and constant wind, with gravity integrated without frame-rate error.
enum FlightSolver {
    struct Step { let ball: BallState; let landed: Bool; let remainingTime: Double }
    static func launch(position: Vector2, direction: Vector2, power: Double, club: GolfClubType = .fiveIron, drag: Double = 0, launchFactor: Double = 1) -> BallState {
        let angle = club.launchAngleRadians
        let speed = calibratedSpeed(club: club, drag: drag) * sqrt(power) * launchFactor
        return BallState(position: position, velocity: direction.normalized * (speed * cos(angle)), verticalVelocity: speed * sin(angle))
    }
    static func calibratedSpeed(club: GolfClubType, drag: Double) -> Double {
        guard club != .putter else { return 0 }
        let angle = club.launchAngleRadians, distance = club.maximumDistanceMeters
        if drag == 0 { return sqrt(distance * SimulationConfig.gravity / sin(2 * angle)) }
        var low = 0.0, high = 150.0
        for _ in 0..<64 {
            let speed = (low + high) / 2, time = 2 * speed * sin(angle) / SimulationConfig.gravity
            let carry = speed * cos(angle) * (-expm1(-drag * time)) / drag
            if carry < distance { low = speed } else { high = speed }
        }
        return (low + high) / 2
    }
    static func airborne(_ ball: BallState, by time: Double, wind: WindCondition, drag: Double) -> BallState {
        let acceleration = wind.velocity * SimulationConfig.windCoupling
        let velocity: Vector2, displacement: Vector2
        if drag > 0 {
            let terminal = acceleration * (1 / drag), factor = exp(-drag * time)
            velocity = terminal + (ball.velocity - terminal) * factor
            displacement = terminal * time + (ball.velocity - terminal) * (-expm1(-drag * time) / drag)
        } else {
            velocity = ball.velocity + acceleration * time
            displacement = ball.velocity * time + acceleration * (time * time / 2)
        }
        return BallState(position: ball.position + displacement,
                         altitude: ball.altitude + ball.verticalVelocity * time - SimulationConfig.gravity * time * time / 2,
                         velocity: velocity, verticalVelocity: ball.verticalVelocity - SimulationConfig.gravity * time)
    }
    static func advance(_ ball: BallState, by elapsed: Double, wind: WindCondition = .calm, drag: Double = 0) -> Step {
        let g = SimulationConfig.gravity, vz = ball.verticalVelocity
        let landingTime = max(0, (vz + sqrt(vz * vz + 2 * g * max(0, ball.altitude))) / g)
        let duration = min(elapsed, landingTime), landed = landingTime <= elapsed
        let step = airborne(ball, by: duration, wind: wind, drag: drag)
        return Step(ball: BallState(position: step.position, altitude: landed ? 0 : step.altitude,
                                    velocity: step.velocity, verticalVelocity: landed ? 0 : step.verticalVelocity),
                    landed: landed, remainingTime: elapsed - duration)
    }
}
