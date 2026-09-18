#if DEBUG
import Foundation
import XCTest
@testable import OffsideGolfCore

final class DebugCommandsTests: XCTestCase {
    func testTeleportRejectsWaterBoundsTreesAndNonfiniteWithoutMutation() throws {
        let hole = try extendedHole {
            $0["regions"] = [["id":"pond","terrain":"water","priority":100,"polygon":[["x":40,"y":90],["x":60,"y":90],["x":60,"y":110],["x":40,"y":110]]]]
            $0["trees"] = [["id":"tree","position":["x":70,"y":100],"trunkRadius":0.5,"trunkHeight":5,"canopyRadius":3,"canopyBottom":3,"canopyTop":10]]
        }
        var game = GameReducer(hole:hole)
        let original = game.state
        for point in [Vector2(x:50,y:100),Vector2(x:-1,y:20),Vector2(x:70,y:100),Vector2(x:.nan,y:20),Vector2(x:0.1,y:20)] {
            game.debugTeleport(to:point)
            XCTAssertEqual(game.state,original)
        }
    }
    func testTeleportCancelsPendingShotAndResetsMetadataWithoutScoring() throws {
        var game = GameReducer(hole:try extendedHole())
        game.send(.beginCharge);game.send(.setPower(0.5));game.send(.release)
        let oldID=try XCTUnwrap(game.state.shotID)
        game.debugTeleport(to:Vector2(x:50,y:160))
        XCTAssertEqual(game.state.phase,.aiming)
        XCTAssertEqual(game.state.club,.putter)
        XCTAssertEqual(game.state.ball,BallState(position:Vector2(x:50,y:160)))
        XCTAssertEqual(game.state.strokeCount,0)
        XCTAssertNil(game.state.shotID)
        XCTAssertNil(game.state.result)
        XCTAssertNil(game.state.firstLanding)
        XCTAssertNil(game.state.lastOutcome)
        XCTAssertEqual(game.state.activeShotElapsed,0)
        XCTAssertEqual(game.state.swingProgress,0)
        game.send(.impact(shotID:oldID))
        game.advance(by:0.2)
        XCTAssertEqual(game.state.strokeCount,0)
        game.send(.beginCharge);game.send(.setPower(0.5));game.send(.release)
        XCTAssertGreaterThan(try XCTUnwrap(game.state.shotID),oldID)
        for _ in 0..<66 { game.advance(by:1.0/120) }
        let eventID=try XCTUnwrap(game.events.last?.id)
        game.debugTeleport(to:Vector2(x:50,y:150))
        XCTAssertEqual(game.state.strokeCount,1,"Already-counted real strokes remain counted")
        game.send(.restart)
        game.send(.beginCharge);game.send(.setPower(0.5));game.send(.release)
        for _ in 0..<66 { game.advance(by:1.0/120) }
        XCTAssertGreaterThan(try XCTUnwrap(game.events.last?.id),eventID)
    }
    func testCompletionIsDeterministicIdempotentAndCheckpointValid() throws {
        let hole=try extendedHole()
        var game=GameReducer(hole:hole)
        game.debugCompleteHole()
        XCTAssertEqual(game.state.phase,.complete)
        XCTAssertEqual(game.state.result,HoleResult(strokes:1,par:hole.par))
        XCTAssertEqual(game.state.ball.position,hole.pin)
        XCTAssertEqual(game.events.map(\.kind),[.cupCapture])
        let result=game.state
        let eventID=try XCTUnwrap(game.events.last?.id)
        game.debugCompleteHole()
        XCTAssertEqual(game.state,result)
        XCTAssertTrue(game.events.isEmpty)
        XCTAssertEqual(try GameReducer(hole:hole,checkpoint:game.checkpoint()).state,result)
        game.send(.restart);game.debugCompleteHole()
        XCTAssertGreaterThan(try XCTUnwrap(game.events.last?.id),eventID)
    }
    func testWindOverrideCheckpointCannotSilentlyResumeWithBundledWind() throws {
        let bundled=try extendedHole()
        var game=GameReducer(hole:bundled)
        game.debugSetWind(speedMPH:8,towardDegrees:90)
        let stable=game.checkpoint()
        game.send(.beginCharge);game.send(.setPower(0.5));game.send(.release)
        for _ in 0..<100 { game.advance(by:1.0/120) }
        XCTAssertEqual(try GameReducer(hole:game.hole,checkpoint:game.checkpoint()).state,game.state)
        XCTAssertThrowsError(try GameReducer(hole:bundled,checkpoint:game.checkpoint()))
        let recovered=try GameReducer(hole:bundled,recoveringSettledCheckpoint:stable)
        XCTAssertEqual(recovered.state.ball.position,bundled.tee)
        XCTAssertEqual(recovered.hole.wind,.calm)
    }
    func testWindOverrideChangesRealPreviewOnlyAtRest() throws {
        var game=GameReducer(hole:try extendedHole())
        let original=ShotPredictor.predict(hole:game.hole,state:game.state,power:0.3)
        game.debugSetWind(speedMPH:8,towardDegrees:90)
        XCTAssertEqual(game.hole.wind.speedMPH,8)
        XCTAssertEqual(game.hole.wind.towardDegrees,90)
        let changed=ShotPredictor.predict(hole:game.hole,state:game.state,power:0.3)
        XCTAssertGreaterThan(try XCTUnwrap(changed.firstLanding).x,try XCTUnwrap(original.firstLanding).x)
        game.debugSetWind(speedMPH:.nan,towardDegrees:0)
        game.debugSetWind(speedMPH:61,towardDegrees:0)
        XCTAssertEqual(game.hole.wind.speedMPH,8)
        game.send(.pause);game.debugSetWind(speedMPH:4,towardDegrees:180)
        XCTAssertEqual(game.hole.wind.speedMPH,4)
        XCTAssertEqual(game.state.phase,.paused)
        game.send(.resume);game.send(.beginCharge);game.send(.setPower(0.3));game.send(.release)
        game.debugSetWind(speedMPH:2,towardDegrees:0)
        XCTAssertEqual(game.hole.wind.speedMPH,4)
    }
}
#endif
