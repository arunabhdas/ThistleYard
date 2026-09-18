import CoreGraphics
import Foundation
import OffsideGolfCore
import XCTest
@testable import OffsideGolf

final class CameraTests: XCTestCase {
    private let viewports = [CGSize(width: 360, height: 580), CGSize(width: 690, height: 300), CGSize(width: 900, height: 700)]
    private func hole(putting: Bool = false) throws -> HoleDefinition {
        let teeY = putting ? 155 : 20
        return try HoleDefinition.decode(Data("""
        {"schemaVersion":1,"id":"camera-hole","par":3,"bounds":{"width":100,"height":190},"tee":{"x":50,"y":\(teeY)},"pin":{"x":50,"y":164.4752},"green":{"center":{"x":50,"y":164.4752},"radiusX":13,"radiusY":11},"fairway":[{"x":30,"y":10},{"x":70,"y":10},{"x":70,"y":180},{"x":30,"y":180}]}
        """.utf8))
    }
    private func projection(_ hole: HoleDefinition, _ viewport: CGSize) -> WorldProjection {
        WorldProjection(worldBounds: CGRect(x: 0, y: 0, width: hole.bounds.width, height: hole.bounds.height), viewport: viewport)
    }
    private func assertVisible(_ points: [Vector2], projection: WorldProjection, pose: CameraPose, viewport: CGSize,
                               file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(pose.scale.isFinite && pose.scale > 0, file: file, line: line)
        XCTAssertTrue(pose.position.x.isFinite && pose.position.y.isFinite, file: file, line: line)
        for point in points {
            let scene = projection.point(for: point)
            let x = (scene.x - pose.position.x) / pose.scale + viewport.width / 2
            let y = (scene.y - pose.position.y) / pose.scale + viewport.height / 2
            XCTAssertTrue((0...viewport.width).contains(x), "Point \(point) is outside viewport x=\(x)", file: file, line: line)
            XCTAssertTrue((0...viewport.height).contains(y), "Point \(point) is outside viewport y=\(y)", file: file, line: line)
        }
    }

    func testSetupAndPuttingKeepBallAndRelevantTargetVisibleAcrossRotation() throws {
        for putting in [false, true] {
            let hole = try hole(putting: putting), game = GameReducer(hole: hole)
            var camera = GameCameraController()
            for viewport in viewports {
                let projection = projection(hole, viewport)
                let pose = camera.update(hole: hole, state: game.state, projection: projection, viewport: viewport, elapsed: 0, reducedMotion: true)
                XCTAssertEqual(camera.mode, putting ? .putting : .playerSetup)
                let relevantTarget = putting ? hole.pin : hole.tee + game.state.aimDirection * 30
                assertVisible([game.state.ball.position, relevantTarget], projection: projection, pose: pose, viewport: viewport)
                let roundTrip = projection.groundPoint(at: projection.point(for: game.state.ball.position))
                XCTAssertEqual(roundTrip.x, game.state.ball.position.x, accuracy: 1e-9)
                XCTAssertEqual(roundTrip.y, game.state.ball.position.y, accuracy: 1e-9)
            }
        }
    }

    func testFlightCameraKeepsBallAndLookAheadVisible() throws {
        let hole = try hole()
        var game = GameReducer(hole: hole)
        game.send(.beginCharge); game.send(.setPower(0.7)); game.send(.release)
        for _ in 0..<150 { game.advance(by: 1.0 / 120) }
        XCTAssertEqual(game.state.phase, .inFlight)
        XCTAssertGreaterThan(game.state.ball.altitude, 8)
        for viewport in viewports {
            var camera = GameCameraController()
            let projection = projection(hole, viewport)
            let pose = camera.update(hole: hole, state: game.state, projection: projection, viewport: viewport, elapsed: 0, reducedMotion: true)
            XCTAssertEqual(camera.mode, .ballFlight)
            assertVisible([game.state.ball.position, game.state.ball.position + game.state.ball.velocity.normalized * 20],
                          projection: projection, pose: pose, viewport: viewport)
        }
    }

    func testReducedMotionSnapsImmediatelyAndSmoothingConvergesAtDifferentFrameRates() throws {
        let hole = try hole(), viewport = viewports[0]
        let projection = projection(hole, viewport)
        var game = GameReducer(hole: hole), baseline = GameCameraController()
        let initial = baseline.update(hole: hole, state: game.state, projection: projection, viewport: viewport, elapsed: 2, reducedMotion: false)
        game.send(.chooseClub(.putter))
        var immediate = baseline
        let target = immediate.update(hole: hole, state: game.state, projection: projection, viewport: viewport, elapsed: 0, reducedMotion: true)
        XCTAssertNotEqual(initial, target)
        var fresh = GameCameraController()
        XCTAssertEqual(target, fresh.update(hole: hole, state: game.state, projection: projection, viewport: viewport, elapsed: 0, reducedMotion: true))
        var poses: [CameraPose] = []
        for rate in [30, 60, 120] {
            var camera = baseline, result = initial
            for _ in 0..<(rate * 2) { result = camera.update(hole: hole, state: game.state, projection: projection, viewport: viewport, elapsed: 1.0 / Double(rate), reducedMotion: false) }
            XCTAssertEqual(result.position.x, target.position.x, accuracy: 0.02)
            XCTAssertEqual(result.position.y, target.position.y, accuracy: 0.02)
            XCTAssertEqual(result.scale, target.scale, accuracy: 0.001)
            poses.append(result)
        }
        for result in poses.dropFirst() {
            XCTAssertEqual(result.position.x, poses[0].position.x, accuracy: 1e-8)
            XCTAssertEqual(result.position.y, poses[0].position.y, accuracy: 1e-8)
            XCTAssertEqual(result.scale, poses[0].scale, accuracy: 1e-8)
        }
    }

    func testResetClearsManualOverviewAndRefitsWithoutReplayingIntro() throws {
        let hole = try hole(), viewport = viewports[0]
        let game = GameReducer(hole: hole)
        var camera = GameCameraController()
        camera.overviewEnabled = true
        _ = camera.update(hole: hole, state: game.state, projection: projection(hole, viewport), viewport: viewport, elapsed: 2, reducedMotion: false)
        XCTAssertEqual(camera.mode, .holeOverview)
        camera.reset()
        let result = camera.update(hole: hole, state: game.state, projection: projection(hole, viewport), viewport: viewport, elapsed: 1.0 / 60, reducedMotion: false)
        XCTAssertFalse(camera.overviewEnabled)
        XCTAssertEqual(camera.mode, .playerSetup)
        var fresh = GameCameraController()
        let target = fresh.update(hole: hole, state: game.state, projection: projection(hole, viewport), viewport: viewport, elapsed: 2, reducedMotion: false)
        XCTAssertEqual(result, target, "Reset must remove interpolation from the previous framing")
    }
}
