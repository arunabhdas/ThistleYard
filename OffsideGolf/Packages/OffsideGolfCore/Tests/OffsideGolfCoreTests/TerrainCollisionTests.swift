import Foundation
import XCTest
@testable import OffsideGolfCore

final class TerrainCollisionTests: XCTestCase {
    func testAllMaterialsStopInSpecifiedOrder() {
        var distances: [Double] = []
        for material in [TerrainMaterial.bunker, .rough, .fairway, .green] {
            var ball = BallState(position: .zero, velocity: Vector2(x: 3,y: 0))
            for _ in 0..<2000 { ball = RollSolver.advance(ball, by: 1.0 / 120, deceleration: material.rollingDeceleration, slope: .zero) }
            distances.append(ball.position.x)
        }
        XCTAssertEqual(distances[0], 0.75, accuracy: 0.01)
        XCTAssertEqual(distances[1], 1.8, accuracy: 0.01)
        XCTAssertEqual(distances[2], 4.090909, accuracy: 0.01)
        XCTAssertEqual(distances[3], 10, accuracy: 0.01)
    }
    func testSupportedSlopeRestsAndSteepSlopeReleases() {
        let stationary = BallState(position: .zero)
        XCTAssertEqual(RollSolver.advance(stationary, by: 1.0 / 120, deceleration: 0.45, slope: Vector2(x: 0.02,y: 0)), stationary)
        let downhill = RollSolver.advance(stationary, by: 1.0 / 120, deceleration: 0.45, slope: Vector2(x: 0.1,y: 0))
        XCTAssertLessThan(downhill.velocity.x, 0)
    }
    func testThinWaterSweepCatchesRollingButAllowsHighFlight() throws {
        let hole = try waterHole()
        var roll = ShotSimulation(ball: BallState(position: Vector2(x: 40,y: 100),velocity: Vector2(x: 2400,y: 0)), phase: .rolling)
        let contact = roll.advance(hole: hole, club: .putter, by: 1.0 / 120)
        XCTAssertEqual(contact.hazard?.outcome, .water)
        XCTAssertEqual(contact.hazard?.id, "river")
        var flight = ShotSimulation(ball: BallState(position: Vector2(x: 40,y: 100),altitude: 20,velocity: Vector2(x: 2400,y: 0)), phase: .inFlight)
        XCTAssertNil(flight.advance(hole: hole,club: .fiveIron,by: 1.0 / 120).hazard)
        XCTAssertGreaterThan(flight.ball.position.x, 59)
    }
    func testWaterAndBunkerPriorityOverrideFairway() throws {
        let hole = try waterHole()
        XCTAssertEqual(hole.terrain(at: Vector2(x: 50,y: 100)), .water)
        XCTAssertEqual(hole.terrain(at: Vector2(x: 45,y: 100)), .fairway)
        XCTAssertEqual(hole.terrain(at: Vector2(x: 5,y: 100)), .rough)
    }
    func testBounceLosesEnergyAndThenSettles() throws {
        let hole = try extendedHole()
        var simulation = ShotSimulation(ball: BallState(position: Vector2(x: 50,y: 100),altitude: 0.01,velocity: Vector2(x: 3,y: 0),verticalVelocity: -10),phase: .inFlight)
        let first = simulation.advance(hole: hole,club: .fiveIron,by: 1.0 / 120)
        XCTAssertTrue(first.events.contains(.bounce))
        XCTAssertGreaterThan(simulation.ball.verticalVelocity, 0)
        XCTAssertLessThan(simulation.ball.verticalVelocity, 4)
        for _ in 0..<3000 { _ = simulation.advance(hole: hole,club: .fiveIron,by: 1.0 / 120) }
        XCTAssertEqual(simulation.ball.velocity, .zero)
        XCTAssertEqual(simulation.ball.altitude, 0)
    }
    func testCanopyContactOncePerEntryAndHighClearance() throws {
        let hole = try extendedHole { $0["trees"] = [["id":"oak","position":["x":50,"y":100],"trunkRadius":0.4,"trunkHeight":5,"canopyRadius":4,"canopyBottom":3,"canopyTop":12]] }
        var simulation = ShotSimulation(ball: BallState(position: Vector2(x: 44,y: 100),altitude: 7,velocity: Vector2(x: 30,y: 0)),phase: .inFlight)
        var contacts = 0
        for _ in 0..<30 { contacts += simulation.advance(hole: hole,club: .fiveIron,by: 1.0 / 120).events.filter { $0 == .tree }.count }
        XCTAssertEqual(contacts, 1)
        var high = ShotSimulation(ball: BallState(position: Vector2(x: 44,y: 100),altitude: 20,velocity: Vector2(x: 30,y: 0)),phase: .inFlight)
        for _ in 0..<30 { XCTAssertFalse(high.advance(hole: hole,club: .fiveIron,by: 1.0 / 120).events.contains(.tree)) }
    }
    func testElevationSlopeMatchesSurfaceHeight() throws {
        let hole = try extendedHole { $0["elevation"] = ["origin":["x":50,"y":20],"baseHeight":0,"gradient":["x":0,"y":0.04]]; $0["greenSlope"] = ["x":0.01,"y":0] }
        XCTAssertEqual(hole.elevation(at: Vector2(x: 50,y: 100)), 3.2, accuracy: 1e-9)
        XCTAssertEqual(hole.slope(at: hole.pin).x, 0.01, accuracy: 0.00001)
        XCTAssertEqual(hole.slope(at: hole.pin).y, 0, accuracy: 0.00001)
    }
    func testSmoothElevationPatchValleyAndFlatGreenStayContinuous() throws {
        let hole = try extendedHole { $0["elevationPatches"] = [["center":["x":50,"y":80],"radius":30,"height":-3]] }
        XCTAssertEqual(hole.elevation(at:Vector2(x:50,y:80)),-3,accuracy:0.000001)
        XCTAssertGreaterThan(hole.elevation(at:Vector2(x:50,y:20)),-0.5)
        XCTAssertEqual(hole.slope(at:hole.pin).length,0,accuracy:0.00001)
        let edge = Vector2(x:50,y:hole.green.center.y-hole.green.radiusY)
        XCTAssertLessThan(abs(hole.elevation(at:edge+Vector2(x:0,y:0.001))-hole.elevation(at:edge-Vector2(x:0,y:0.001))),0.001)
    }
    func testUphillRollTurnsDownhillRatherThanSettlingOnUnsupportedSlope() throws {
        let hole=try extendedHole { $0["elevation"]=["origin":["x":50,"y":20],"baseHeight":0,"gradient":["x":0.15,"y":0]] }
        var simulation=ShotSimulation(ball:BallState(position:Vector2(x:50,y:100),velocity:Vector2(x:0.012,y:0)),phase:.rolling)
        _=simulation.advance(hole:hole,club:.putter,by:1.0/120)
        XCTAssertEqual(simulation.phase,.rolling)
        _=simulation.advance(hole:hole,club:.putter,by:1.0/120)
        XCTAssertLessThan(simulation.ball.velocity.x,0)
    }
    private func waterHole() throws -> HoleDefinition {
        try extendedHole { $0["regions"] = [["id":"river","terrain":"water","priority":100,"polygon":[["x":49.99,"y":60],["x":50.01,"y":60],["x":50.01,"y":140],["x":49.99,"y":140]]]] }
    }
}
