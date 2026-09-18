import XCTest
import SwiftUI
import UIKit
import OffsideGolfCore
@testable import OffsideGolf

@MainActor
final class GameSessionTests: XCTestCase {
    private func makeSession() throws -> GameSession {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "whispering-coast-01", withExtension: "json"))
        return try GameSession(hole: HoleDefinition.decode(Data(contentsOf: url)))
    }

    func testBundledHoleMatchesManifest() throws {
        let session = try makeSession()
        XCTAssertEqual(session.hud.distanceYards, 158)
        XCTAssertEqual(session.hud.club, .fiveIron)
        XCTAssertEqual(session.hud.strokes, 0)
    }

    func testFrameGapAndPauseDoNotLaunchOrDuplicateStroke() throws {
        let session = try makeSession()
        session.setPower(0.78)
        session.send(.release)
        session.frame(at: 1)
        session.frame(at: 20) // A suspended display link must not fast-forward impact.
        XCTAssertEqual(session.hud.strokes, 0)
        session.send(.pause)
        session.frame(at: 21)
        session.frame(at: 21.1)
        XCTAssertEqual(session.hud.strokes, 0)
        session.resume()
        for frame in 0...60 { session.frame(at: 30 + Double(frame) / 60) }
        XCTAssertEqual(session.hud.strokes, 1)
        XCTAssertEqual(session.hud.phase, .inFlight)
        session.send(.impact(shotID: try XCTUnwrap(session.state.shotID)))
        XCTAssertEqual(session.hud.strokes, 1)
    }

    func testCancelledChargeAndRestartResetHUD() throws {
        let session = try makeSession()
        session.setPower(0.8)
        session.send(.cancelCharge)
        session.send(.release)
        XCTAssertEqual(session.hud.phase, .aiming)
        XCTAssertEqual(session.hud.power, 0)
        session.setPower(0.78)
        session.send(.release)
        for frame in 0...60 { session.frame(at: Double(frame) / 60) }
        XCTAssertEqual(session.hud.strokes, 1)
        session.restart()
        XCTAssertEqual(session.hud.strokes, 0)
        XCTAssertEqual(session.hud.distanceYards, 158)
        XCTAssertEqual(session.hud.phase, .aiming)
    }
    func testPullCapturesAimButUntimedChargingCanStillAdjustIt() throws {
        let session = try makeSession()
        let original = session.state.aimDirection
        session.beginPull()
        session.setPower(0.4)
        session.rotateAim(degrees: 20)
        session.aim(at: Vector2(x: 5, y: 5))
        XCTAssertEqual(session.state.aimDirection, original)
        session.send(.cancelCharge)
        session.setPower(0.4)
        session.rotateAim(degrees: 20)
        XCTAssertNotEqual(session.state.aimDirection, original)
    }
    func testPendingDurableSaveHoldsCommittedSwingUntilStorageAllowsAdvance() throws {
        let session = try makeSession()
        var durable = false
        session.mayAdvance = { durable }
        session.setPower(0.4); session.send(.release)
        for frame in 0...120 { session.frame(at: Double(frame)/60) }
        XCTAssertEqual(session.hud.strokes, 0)
        durable = true
        for frame in 121...180 { session.frame(at: Double(frame)/60) }
        XCTAssertEqual(session.hud.strokes, 1)
    }

    func testCancellingPowerClearsPredictionAndHazardWarningImmediately() async throws {
        let session = try makeSession()
        session.setPower(0.9)
        session.frame(at: 0); session.frame(at: 0.2)
        for _ in 0..<100 where session.scene.prediction == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertNotNil(session.scene.prediction)
        session.send(.cancelCharge)
        XCTAssertNil(session.scene.prediction)
        XCTAssertNil(session.previewWarning)
    }

    func testPullControlsKeepTheirHeightWhenHazardAdvisoryAppearsAndClears() async throws {
        for textSize in [DynamicTypeSize.large, .accessibility5] {
            for width in [270.0, 370.0] {
                let session = try makeSession()
                let host = UIHostingController(rootView: SwingControls(session: session)
                    .environment(\.dynamicTypeSize, textSize))
                let proposed = CGSize(width: width, height: 2_000)
                let originalHeight = host.sizeThatFits(in: proposed).height
                session.beginPull()
                session.setPower(0.9)
                session.frame(at: 0); session.frame(at: 0.2)
                for _ in 0..<100 where session.scene.prediction == nil {
                    try await Task.sleep(for: .milliseconds(10))
                }
                XCTAssertEqual(session.scene.prediction?.outcome, .outOfBounds)
                XCTAssertNotNil(session.previewWarning)
                // Allow SwiftUI observation to apply the asynchronous prediction.
                try await Task.sleep(for: .milliseconds(30))
                XCTAssertEqual(host.sizeThatFits(in: proposed).height, originalHeight, accuracy: 0.5,
                               "A warning must not move the swing pad during a pull (width \(width), \(textSize))")

                session.setPower(0.15)
                session.frame(at: 0.4)
                for _ in 0..<100 where session.previewWarning != nil {
                    try await Task.sleep(for: .milliseconds(10))
                }
                XCTAssertNil(session.previewWarning)
                try await Task.sleep(for: .milliseconds(30))
                XCTAssertEqual(host.sizeThatFits(in: proposed).height, originalHeight, accuracy: 0.5)
                XCTAssertEqual(session.hud.power, 15)
                XCTAssertEqual(session.hud.strokes, 0)
                session.send(.cancelCharge)
                XCTAssertNil(session.previewWarning)
                XCTAssertEqual(host.sizeThatFits(in: proposed).height, originalHeight, accuracy: 0.5)
            }
        }
    }

    #if DEBUG
    func testDetailedDebugGuidesMarkAndPersistAssistedStatusBeforeDisplay() throws {
        let session = try makeSession()
        var assisted = false, persisted = false
        session.onAssisted = { assisted = true }
        session.onCheckpoint = { _ in persisted = assisted }
        session.setDebugTrajectory(true)
        XCTAssertTrue(assisted); XCTAssertTrue(persisted)
        XCTAssertTrue(session.scene.debugTrajectory)
        assisted = false; persisted = false
        session.setDebugGeometry(true)
        XCTAssertTrue(assisted); XCTAssertTrue(persisted)
        XCTAssertTrue(session.scene.debugGeometry)
    }
    #endif

}
