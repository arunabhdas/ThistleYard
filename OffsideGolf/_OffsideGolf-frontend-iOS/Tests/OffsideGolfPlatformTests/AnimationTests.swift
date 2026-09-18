import XCTest
import OffsideGolfCore
@testable import OffsideGolf

final class AnimationTests: XCTestCase {
    func testSwingPosesUseSimulationClockAndCannotLaunchBall() throws {
        var game = try makeGame()
        var controller = GolferAnimationController()
        game.send(.beginCharge); game.send(.setPower(0.78)); game.send(.release)
        XCTAssertEqual(controller.sample(state: game.state, reducedMotion: false, elapsed: 0).pose, .aim)
        advance(&game, frames: 12)
        XCTAssertEqual(controller.sample(state: game.state, reducedMotion: false, elapsed: 10).pose, .backswing)
        XCTAssertEqual(game.state.strokeCount, 0)
        advance(&game, frames: 15)
        XCTAssertEqual(controller.sample(state: game.state, reducedMotion: false, elapsed: 0).pose, .downswing)
        advance(&game, frames: 6)
        XCTAssertEqual(controller.sample(state: game.state, reducedMotion: false, elapsed: 0).pose, .impact)
        XCTAssertEqual(game.state.strokeCount, 1)
        advance(&game, frames: 9)
        XCTAssertEqual(controller.sample(state: game.state, reducedMotion: false, elapsed: 0).pose, .followThrough)
        advance(&game, frames: 15)
        XCTAssertEqual(controller.sample(state: game.state, reducedMotion: false, elapsed: 0).pose, .watchBall)
    }

    func testSkippedRenderFramesDoNotReplayImpactOrMoveGolferWithBall() throws {
        var game = try makeGame()
        var controller = GolferAnimationController()
        let origin = game.state.ball.position
        _ = controller.sample(state: game.state, reducedMotion: false, elapsed: 0)
        game.send(.beginCharge); game.send(.setPower(0.78)); game.send(.release)
        // Two seconds of simulation with no intermediate animation/render samples.
        advance(&game, frames: 120)
        let frame = controller.sample(state: game.state, reducedMotion: false, elapsed: 2)
        XCTAssertEqual(frame.pose, .watchBall)
        XCTAssertEqual(frame.groundPosition, origin)
        XCTAssertNotEqual(game.state.ball.position, origin)
        XCTAssertEqual(game.state.strokeCount, 1)
    }

    func testPracticeFinishesWithoutChangingGameAndPauseFreezesItsPose() throws {
        var game = try makeGame()
        var controller = GolferAnimationController()
        _ = controller.sample(state: game.state, reducedMotion: false, elapsed: 0)
        controller.startPractice()
        let before = game.state
        let practice = controller.sample(state: game.state, reducedMotion: false, elapsed: 0.2)
        XCTAssertEqual(practice.pose, .practice)
        game.send(.pause)
        XCTAssertEqual(controller.sample(state: game.state, reducedMotion: false, elapsed: 60), practice)
        game.send(.resume)
        for _ in 0..<5 { _ = controller.sample(state: game.state, reducedMotion: false, elapsed: 0.2) }
        XCTAssertEqual(controller.sample(state: game.state, reducedMotion: false, elapsed: 0).pose, .idle)
        XCTAssertEqual(game.state, before)
    }

    func testReducedMotionKeepsKeyPoseWithNoTransformAnimation() throws {
        var game = try makeGame()
        var controller = GolferAnimationController()
        game.send(.beginCharge); game.send(.setPower(0.8)); game.send(.release)
        advance(&game, frames: 12)
        let frame = controller.sample(state: game.state, reducedMotion: true, elapsed: 0.2)
        XCTAssertEqual(frame.pose, .backswing)
        XCTAssertEqual(frame.rotation, 0)
        XCTAssertEqual(frame.verticalOffset, 0)
        XCTAssertEqual(frame.scaleY, 1)
        XCTAssertEqual(frame.opacity, 1)
    }

    func testPutterUsesCompactPuttPoseAndSettlingReanchorsFeet() throws {
        var game = try makeGame()
        var controller = GolferAnimationController()
        _ = controller.sample(state: game.state, reducedMotion: true, elapsed: 0)
        game.send(.beginCharge); game.send(.setPower(0.78)); game.send(.release)
        advance(&game, frames: 1_200)
        XCTAssertEqual(game.state.phase, .aiming)
        let settled = controller.sample(state: game.state, reducedMotion: true, elapsed: 0)
        XCTAssertEqual(settled.groundPosition, game.state.ball.position)
        XCTAssertEqual(game.state.club, .putter)
        game.send(.beginCharge); game.send(.setPower(0.38)); game.send(.release)
        advance(&game, frames: 12)
        XCTAssertEqual(controller.sample(state: game.state, reducedMotion: false, elapsed: 0).pose, .putt)
    }

    func testSettledGolferTakesShortRepositionStepAndThenReturnsToIdle() throws {
        var game = try makeGame()
        var controller = GolferAnimationController()
        _ = controller.sample(state: game.state, reducedMotion: false, elapsed: 0)
        game.send(.beginCharge); game.send(.setPower(0.78)); game.send(.release)
        advance(&game, frames: 1_200)
        XCTAssertEqual(game.state.phase, .aiming)
        let step = controller.sample(state: game.state, reducedMotion: false, elapsed: 0.05)
        XCTAssertEqual(step.pose, .walk)
        XCTAssertEqual(step.groundPosition, game.state.ball.position)
        XCTAssertLessThan(step.opacity, 1)
        _ = controller.sample(state: game.state, reducedMotion: false, elapsed: 0.25)
        XCTAssertEqual(controller.sample(state: game.state, reducedMotion: false, elapsed: 0).pose, .idle)
    }

    /// Drive the core with legal 60 Hz frames. A single large elapsed value is an
    /// overloaded frame, not a request to simulate all of that duration.
    private func advance(_ game: inout GameReducer, frames: Int) {
        for _ in 0..<frames { game.advance(by: 1.0 / 60) }
    }

    private func makeGame() throws -> GameReducer {
        let data = Data(#"{"schemaVersion":1,"id":"hole-1","par":3,"bounds":{"width":100,"height":190},"tee":{"x":50,"y":20},"pin":{"x":50,"y":164.4752},"green":{"center":{"x":50,"y":164.4752},"radiusX":13,"radiusY":11},"fairway":[{"x":30,"y":10},{"x":70,"y":10},{"x":70,"y":180},{"x":30,"y":180}]}"#.utf8)
        return GameReducer(hole: try HoleDefinition.decode(data))
    }
}
