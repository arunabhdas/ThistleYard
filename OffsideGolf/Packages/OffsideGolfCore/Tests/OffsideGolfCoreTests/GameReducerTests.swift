import XCTest
@testable import OffsideGolfCore

final class GameReducerTests: XCTestCase {
    func testPrecisionAimCanChangeAfterPowerBeforeRelease() throws {
        var game = GameReducer(hole: try practiceHole())
        game.send(.beginCharge); game.send(.setPower(0.5))
        game.send(.aim(Vector2(x: 1, y: 0)))
        XCTAssertEqual(game.state.aimDirection, Vector2(x: 1, y: 0))
        XCTAssertEqual(game.state.power, 0.5)
        game.send(.release)
        game.send(.aim(Vector2(x: 0, y: 1)))
        for _ in 0..<80 { game.advance(by: 1.0 / 120) }
        XCTAssertGreaterThan(game.state.ball.position.x, game.hole.tee.x)
        XCTAssertEqual(game.state.ball.position.y, game.hole.tee.y)
    }
    func testReleaseWaitsForImpactAndDuplicateEventsCannotScore() throws {
        var game = GameReducer(hole: try practiceHole())
        game.send(.beginCharge); game.send(.setPower(0.78)); game.send(.release)
        let id = try XCTUnwrap(game.state.shotID)
        XCTAssertEqual(game.state.phase, .swinging)
        XCTAssertEqual(game.state.strokeCount, 0)
        XCTAssertEqual(game.state.ball.position, game.hole.tee)
        game.send(.impact(shotID: id)); game.send(.release)
        XCTAssertEqual(game.state.strokeCount, 0, "Even matching early impact must await contact time")
        for _ in 0..<65 { game.advance(by: 1.0 / 120) }
        XCTAssertEqual(game.state.strokeCount, 0)
        game.advance(by: 1.0 / 120)
        XCTAssertEqual(game.state.strokeCount, 1)
        XCTAssertEqual(game.state.phase, .inFlight)
        game.send(.impact(shotID: id)); game.send(.impact(shotID: id + 1))
        XCTAssertEqual(game.state.strokeCount, 1)
    }
    func testInvalidInputsAndCancelledChargeDoNotMakeShots() throws {
        var game = GameReducer(hole: try practiceHole())
        let originalAim = game.state.aimDirection
        for vector in [Vector2.zero, Vector2(x: .nan, y: 1), Vector2(x: .infinity, y: 0)] { game.send(.aim(vector)) }
        XCTAssertEqual(game.state.aimDirection, originalAim)
        game.send(.release); game.send(.cancelCharge)
        for power in [0.0, -.infinity, .infinity, .nan, -1] {
            game.send(.beginCharge); game.send(.setPower(power)); game.send(.release)
            XCTAssertEqual(game.state.phase, .aiming)
        }
        game.send(.beginCharge); game.send(.setPower(0.8)); game.send(.cancelCharge); game.send(.release)
        advanceToRest(&game)
        XCTAssertEqual(game.state.strokeCount, 0)
        XCTAssertEqual(game.state.ball.position, game.hole.tee)
    }
    func testPauseFreezesAndResumeCancelsChargeButPreservesFlight() throws {
        var game = GameReducer(hole: try practiceHole())
        game.send(.beginCharge); game.send(.setPower(0.8)); game.send(.pause)
        game.advance(by: 10); game.send(.release); game.send(.resume)
        XCTAssertEqual(game.state.phase, .aiming)
        XCTAssertEqual(game.state.power, 0)
        shoot(&game, power: 0.78)
        game.advance(by: 0.1)
        let ball = game.state.ball, shotID = game.state.shotID
        game.send(.pause)
        for _ in 0..<100 { game.advance(by: 1) }
        XCTAssertEqual(game.state.ball, ball)
        game.send(.resume)
        XCTAssertEqual(game.state.phase, .inFlight)
        XCTAssertEqual(game.state.shotID, shotID)
        game.send(.restart)
        XCTAssertEqual(game.state.ball.position, game.hole.tee)
        XCTAssertEqual(game.state.strokeCount, 0)
        XCTAssertNil(game.state.shotID)
        game.send(.beginCharge); game.send(.setPower(0.5)); game.send(.release)
        XCTAssertGreaterThan(try XCTUnwrap(game.state.shotID), try XCTUnwrap(shotID))
        game.send(.impact(shotID: try XCTUnwrap(shotID)))
        XCTAssertEqual(game.state.strokeCount, 0)
    }
    func testWholeHoleCompletesThroughApproachAndRealPutt() throws {
        var game = GameReducer(hole: try practiceHole())
        shoot(&game, power: 0.78); advanceToRest(&game)
        XCTAssertEqual(game.state.phase, .aiming)
        XCTAssertEqual(game.state.club, .putter)
        XCTAssertEqual(game.state.strokeCount, 1)
        XCTAssertEqual(game.state.lastOutcome, .settled)
        let distance = game.state.ball.position.distance(to: game.hole.pin)
        XCTAssertGreaterThan(distance, 1)
        XCTAssertLessThan(distance, 11)
        shoot(&game, power: distance / 27.432); advanceToRest(&game)
        XCTAssertEqual(game.state.phase, .complete)
        XCTAssertEqual(game.state.ball.position, game.hole.pin)
        XCTAssertEqual(game.state.result?.title, "Birdie")
        XCTAssertEqual(game.state.result?.relativeToPar, -1)
        game.send(.beginCharge); game.send(.release)
        advanceToRest(&game)
        XCTAssertEqual(game.state.strokeCount, 2)
    }
    func testOutOfBoundsReturnsToPreShotPositionWithExactlyOnePenalty() throws {
        var game = GameReducer(hole: try practiceHole())
        game.send(.aim(Vector2(x: 1, y: 0))); shoot(&game, power: 1)
        let id = try XCTUnwrap(game.state.shotID)
        advanceToRest(&game)
        XCTAssertEqual(game.state.ball.position, game.hole.tee)
        XCTAssertEqual(game.state.lastOutcome, .outOfBounds)
        XCTAssertEqual(game.state.penaltyCount, 1)
        XCTAssertEqual(game.state.strokeCount, 2)
        game.send(.impact(shotID: id)); advanceToRest(&game)
        XCTAssertEqual(game.state.penaltyCount, 1)
        XCTAssertEqual(game.state.strokeCount, 2)
    }
    func testFrameSchedulesYieldIdenticalSettledPositionsAndScores() throws {
        var states: [GameState] = []
        for fps in [30, 60, 120] {
            var game = GameReducer(hole: try practiceHole())
            game.send(.beginCharge); game.send(.setPower(0.78)); game.send(.release)
            for _ in 0..<(fps * 20) { game.advance(by: 1 / Double(fps)) }
            states.append(game.state)
        }
        for state in states {
            XCTAssertEqual(state.phase, .aiming)
            XCTAssertEqual(state.strokeCount, 1)
            XCTAssertEqual(state.ball.position.y, states[0].ball.position.y, accuracy: 1e-9)
        }
    }
    func testBadFrameGapsAreIgnoredOrBounded() throws {
        var game = GameReducer(hole: try practiceHole())
        game.send(.beginCharge); game.send(.setPower(0.5)); game.send(.release)
        for elapsed in [Double.nan, .infinity, -1] { game.advance(by: elapsed) }
        XCTAssertEqual(game.state.strokeCount, 0)
        game.advance(by: 1e20)
        XCTAssertEqual(game.state.phase, .swinging)
        XCTAssertEqual(game.state.strokeCount, 0)
    }
    func testRoundedManualPowersFinishAtEveryRenderRate() throws {
        for fps in [30, 60, 120] {
            var game = GameReducer(hole: try practiceHole())
            for power in [0.78, 0.38] {
                game.send(.beginCharge); game.send(.setPower(power)); game.send(.release)
                for _ in 0..<(fps * 20) { game.advance(by: 1 / Double(fps)) }
            }
            XCTAssertEqual(game.state.result, HoleResult(strokes: 2, par: 3))
            XCTAssertEqual(game.state.phase, .complete)
        }
    }
    func testResultNamesAndParDeltasIncludeAceAndLargeScores() {
        let examples: [(Int, Int, Int, String)] = [
            (1, 3, -2, "Ace"), (2, 5, -3, "Albatross"), (2, 4, -2, "Eagle"),
            (2, 3, -1, "Birdie"), (3, 3, 0, "Par"), (4, 3, 1, "Bogey"),
            (5, 3, 2, "Double Bogey"), (8, 3, 5, "+5 over par")
        ]
        for (strokes, par, delta, title) in examples {
            let result = HoleResult(strokes: strokes, par: par)
            XCTAssertEqual(result.relativeToPar, delta)
            XCTAssertEqual(result.title, title)
        }
    }
    func testLaterOutOfBoundsRecoversToItsOwnOriginAndPenaltiesEnterResult() throws {
        var game = GameReducer(hole: try practiceHole())
        game.send(.aim(Vector2(x: 1, y: 0))); shoot(&game, power: 1); advanceToRest(&game)
        shoot(&game, power: 0.78); advanceToRest(&game)
        XCTAssertEqual(game.state.club, .putter)
        shoot(&game, power: 0.38); advanceToRest(&game)
        XCTAssertEqual(game.state.result, HoleResult(strokes: 4, par: 3))
        XCTAssertEqual(game.state.result?.title, "Bogey")

        game.send(.restart)
        shoot(&game, power: 0.78); advanceToRest(&game)
        game.send(.aim(Vector2(x: 1, y: 0))); shoot(&game, power: 1); advanceToRest(&game)
        XCTAssertEqual(game.state.club, .fiveIron)
        let origin = game.state.ball.position
        XCTAssertNotEqual(origin, game.hole.tee)
        game.send(.aim(Vector2(x: 1, y: 0))); shoot(&game, power: 1); advanceToRest(&game)
        XCTAssertEqual(game.state.ball.position, origin)
        XCTAssertEqual(game.state.penaltyCount, 1)
        XCTAssertEqual(game.state.strokeCount, 4)
    }
    func testRestartPreservesMonotonicPresentationEventIDs() throws {
        var game=GameReducer(hole:try practiceHole())
        shoot(&game,power:0.5)
        let first=try XCTUnwrap(game.events.last?.id)
        game.send(.restart)
        shoot(&game,power:0.5)
        XCTAssertGreaterThan(try XCTUnwrap(game.events.last?.id),first)
    }
    private func shoot(_ game: inout GameReducer, power: Double) {
        game.send(.beginCharge); game.send(.setPower(power)); game.send(.release)
        for _ in 0..<66 { game.advance(by: 1.0 / 120) }
    }
    private func advanceToRest(_ game: inout GameReducer) {
        for _ in 0..<2400 { game.advance(by: 1.0 / 120) }
    }
}
