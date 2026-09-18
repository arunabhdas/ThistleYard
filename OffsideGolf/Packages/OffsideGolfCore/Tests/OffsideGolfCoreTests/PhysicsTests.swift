import XCTest
@testable import OffsideGolfCore

final class PhysicsTests: XCTestCase {
    func testShotTimerReportsExplicitTimeoutOnlyAfterThirtySimulationSeconds() {
        var timer = ShotTimer()
        for _ in 0..<3599 { XCTAssertNil(timer.advance(by: 1.0 / 120)) }
        XCTAssertEqual(timer.advance(by: 1.0 / 120), .timedOut)
        timer = ShotTimer()
        XCTAssertNil(timer.advance(by: 1.0 / 120))
    }
    func testFullAndHalfPowerCalmCarryHitIndependentTargets() {
        for (power, target) in [(1.0, 164.592), (0.5, 82.296)] {
            var ball = FlightSolver.launch(position: .zero, direction: Vector2(x: 0, y: 1), power: power)
            for _ in 0..<2000 {
                let step = FlightSolver.advance(ball, by: 1.0 / 120)
                ball = step.ball
                if step.landed { break }
            }
            XCTAssertEqual(ball.position.y, target, accuracy: 0.000001)
            XCTAssertEqual(ball.altitude, 0)
        }
    }
    func testConstantDecelerationStopsAtIndependentDistanceWithoutReversing() {
        var ball = BallState(position: .zero, velocity: Vector2(x: 3, y: 0))
        for _ in 0..<100 { ball = RollSolver.advance(ball, by: 0.1, deceleration: 0.45) }
        XCTAssertEqual(ball.position.x, 10, accuracy: 1e-9)
        XCTAssertEqual(ball.velocity, .zero)
        XCTAssertEqual(RollSolver.advance(ball, by: 1, deceleration: 0.45), ball)
    }
    func testSweptCaptureCatchesSlowCrossingAndMissesFastCrossing() {
        XCTAssertTrue(CupCapture.captures(from: Vector2(x: -1, y: 0), to: Vector2(x: 1, y: 0), initialSpeed: 1, deceleration: 0, pin: .zero))
        XCTAssertFalse(CupCapture.captures(from: Vector2(x: -1, y: 0), to: Vector2(x: 1, y: 0), initialSpeed: 2, deceleration: 0, pin: .zero))
        XCTAssertFalse(CupCapture.captures(from: Vector2(x: -1, y: 0.12), to: Vector2(x: 1, y: 0.12), initialSpeed: 1, deceleration: 0, pin: .zero))
        // Speed crosses the threshold along the swept segment, before reaching the cup.
        XCTAssertTrue(CupCapture.captures(from: Vector2(x: -1, y: 0), to: Vector2(x: 1, y: 0), initialSpeed: 1.6, deceleration: 0.45, pin: .zero))
    }
}
