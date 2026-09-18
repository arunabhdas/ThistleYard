import Foundation
import XCTest
@testable import OffsideGolfCore

final class RecoveryPuttingTests: XCTestCase {
    func testWaterPenaltyUsesSafeNotCloserDropOnce() throws {
        let hole = try extendedHole {
            $0["regions"] = [["id":"river","terrain":"water","priority":100,"polygon":[["x":20,"y":90],["x":80,"y":90],["x":80,"y":130],["x":20,"y":130]]]]
            $0["drops"] = [["id":"safe","position":["x":30,"y":80],"hazardID":"river"], ["id":"closer","position":["x":30,"y":140],"hazardID":"river"]]
        }
        var game = GameReducer(hole: hole)
        game.send(.chooseClub(.fiveIron)); game.send(.beginCharge); game.send(.setPower(0.5)); game.send(.release)
        let id = try XCTUnwrap(game.state.shotID)
        var splashes = 0
        for _ in 0..<4000 {
            game.advance(by: 1.0 / 120)
            splashes += game.events.filter { $0.kind == .splash }.count
        }
        XCTAssertEqual(game.state.lastOutcome, .water)
        XCTAssertEqual(game.state.ball.position, Vector2(x: 30,y: 80))
        XCTAssertEqual(game.state.penaltyCount, 1)
        XCTAssertEqual(game.state.strokeCount, 2)
        XCTAssertEqual(splashes, 1)
        game.send(.impact(shotID: id))
        XCTAssertEqual(game.state.strokeCount, 2)
    }
    func testFlatHalfPowerTenYardPuttRollsFiveYards() throws {
        let hole = try extendedHole { $0["tee"] = ["x":50,"y":156] }
        var game = GameReducer(hole: hole)
        game.send(.chooseClub(.putter)); game.send(.setPuttRange(.medium))
        game.send(.beginCharge); game.send(.setPower(0.5)); game.send(.release)
        for _ in 0..<3000 { game.advance(by: 1.0 / 120) }
        XCTAssertEqual(game.state.ball.position.y, 160.572, accuracy: 0.01)
        XCTAssertEqual(game.state.phase, .aiming)
        XCTAssertEqual(game.state.club, .putter)
        XCTAssertEqual(game.state.puttRange, .medium)
    }
    func testFullPhysicsRefreshRatesAgree() throws {
        var states: [GameState] = []
        for fps in [30,60,120] {
            var game = GameReducer(hole: try extendedHole())
            game.send(.chooseClub(.fiveIron)); game.send(.beginCharge); game.send(.setPower(0.4)); game.send(.release)
            for _ in 0..<(fps * 32) { game.advance(by: 1 / Double(fps)) }
            states.append(game.state)
        }
        XCTAssertEqual(states[0],states[1]); XCTAssertEqual(states[1],states[2])
        XCTAssertEqual(states[0].phase,.aiming)
        XCTAssertEqual(states[0].lastOutcome,.settled)
    }
    func testCheckpointRestoresCommittedSwingAndFlightExactly() throws {
        let hole = try extendedHole()
        for ticks in [20,100,500] {
            var original = GameReducer(hole: hole)
            original.send(.chooseClub(.sevenIron)); original.send(.beginCharge); original.send(.setPower(0.5)); original.send(.release)
            for _ in 0..<ticks { original.advance(by: 1.0 / 120) }
            let data = try JSONEncoder().encode(original.checkpoint())
            var restored = try GameReducer(hole: hole,checkpoint: JSONDecoder().decode(GameCheckpoint.self,from: data))
            for _ in 0..<4000 { original.advance(by: 1.0 / 120); restored.advance(by: 1.0 / 120) }
            XCTAssertEqual(restored.state,original.state)
            XCTAssertEqual(restored.state.strokeCount,1)
        }
    }
    func testFrameCatchupIsBoundedAndLargeGapDoesNotAdvance() throws {
        var game = GameReducer(hole: try extendedHole())
        game.send(.beginCharge);game.send(.setPower(0.5));game.send(.release)
        game.advance(by:10)
        XCTAssertEqual(game.state.swingProgress,0)
        game.advance(by:0.1)
        XCTAssertEqual(game.state.swingProgress,8.0/66,accuracy:1e-10)
    }
    func testSnapshotMissingActiveSimulationCannotStrandFlight() throws {
        let hole = try extendedHole()
        var game = GameReducer(hole:hole)
        game.send(.beginCharge);game.send(.setPower(0.5));game.send(.release)
        for _ in 0..<100 { game.advance(by:1.0/120) }
        let checkpoint=game.checkpoint()
        var snapshot=try XCTUnwrap(JSONSerialization.jsonObject(with:checkpoint.snapshot) as? [String:Any])
        snapshot.removeValue(forKey:"simulation")
        let broken=GameCheckpoint(schemaVersion:1,physicsVersion:2,contentVersion:1,holeID:hole.id,snapshot:try JSONSerialization.data(withJSONObject:snapshot))
        XCTAssertThrowsError(try GameReducer(hole:hole,checkpoint:broken))
    }
    func testCorruptAndMismatchedCheckpointRejected() throws {
        let hole = try extendedHole(), game = GameReducer(hole: hole)
        let checkpoint = game.checkpoint()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(checkpoint)) as? [String: Any])
        object["physicsVersion"] = 999
        let old = try JSONDecoder().decode(GameCheckpoint.self,from: JSONSerialization.data(withJSONObject: object))
        XCTAssertThrowsError(try GameReducer(hole: hole,checkpoint: old))
        let recovered = try GameReducer(hole: hole,recoveringSettledCheckpoint: old)
        XCTAssertEqual(recovered.state,game.state)
        object["snapshot"] = Data("invalid".utf8).base64EncodedString()
        let corrupt = try JSONDecoder().decode(GameCheckpoint.self,from: JSONSerialization.data(withJSONObject: object))
        XCTAssertThrowsError(try GameReducer(hole: hole,recoveringSettledCheckpoint: corrupt))
    }
}
