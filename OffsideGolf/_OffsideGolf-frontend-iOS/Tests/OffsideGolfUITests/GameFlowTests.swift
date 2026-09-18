import XCTest

@MainActor
final class GameFlowTests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
    }

    func testPlayMeadowStartAndCancelSwing() {
        let app = XCUIApplication()
        app.launchEnvironment["OFFSIDE_UI_TEST_SAVE"] = UUID().uuidString
        app.launch()
        let play = app.buttons["play.meadow"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        play.tap()
        XCTAssertTrue(app.staticTexts["game.phase"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["game.strokes"].label, "Strokes 0")
        app.otherElements["swing.pad"].tap()
        XCTAssertEqual(app.staticTexts["game.strokes"].label, "Strokes 0")
        XCTAssertEqual(app.staticTexts["game.phase"].label, "Ready to swing")
        app.buttons["game.pause"].tap()
        XCTAssertTrue(app.buttons["game.resume"].waitForExistence(timeout: 5))
        app.buttons["game.resume"].tap()
        XCTAssertEqual(app.staticTexts["game.strokes"].label, "Strokes 0")
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = "M1-playable-hole"
        image.lifetime = .keepAlways
        add(image)
    }

    func testCompleteHoleWithPreciseControlsAndReplay() {
        let app = openGame()
        app.buttons["controls.precise"].tap()
        setPower(44, in: app)
        app.buttons["swing.commit"].tap()
        waitForLabel("Putter", element: app.staticTexts["game.club"])
        XCTAssertEqual(app.staticTexts["game.strokes"].label, "Strokes 1")
        capture("M1-putting")
        setPower(63, in: app)
        app.buttons["swing.commit"].tap()
        XCTAssertTrue(app.staticTexts["result.title"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["result.title"].label, "Birdie")
        XCTAssertEqual(app.staticTexts["result.strokes"].label, "2 strokes · Par 3")
        capture("M1-hole-complete")
        app.buttons["result.replay"].tap()
        XCTAssertEqual(app.staticTexts["game.strokes"].label, "Strokes 0")
        XCTAssertEqual(app.staticTexts["game.club"].label, "5 Iron")
        app.buttons["game.pause"].tap()
        app.buttons["Leave hole"].tap()
        XCTAssertTrue(app.buttons["play.meadow"].waitForExistence(timeout: 5))
        app.buttons["play.meadow"].tap()
        XCTAssertEqual(app.staticTexts["game.strokes"].label, "Strokes 0")
    }

    func testDragShotAndRotationPreserveProgress() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = openGame()
        let pad = app.otherElements["swing.pad"]
        let start = pad.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 48)))
        waitForLabel("Strokes 1", element: app.staticTexts["game.strokes"])
        waitForLabel("Ready to swing", element: app.staticTexts["game.phase"])
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(app.staticTexts["game.strokes"].label, "Strokes 1")
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["game.resume"].waitForExistence(timeout: 5))
        app.buttons["game.restart"].tap()
        XCTAssertTrue(app.buttons["game.restart.confirm"].waitForExistence(timeout: 5))
        app.buttons["Keep playing"].tap()
        app.buttons["game.resume"].tap()
        XCTAssertEqual(app.staticTexts["game.strokes"].label, "Strokes 1")
        capture("M1-landscape-play")
    }

    func testRiverWaterPenaltyAndSafeDropCanFinishWithRealControls() {
        let app = XCUIApplication()
        app.launchEnvironment["OFFSIDE_UI_TEST_SAVE"] = UUID().uuidString
        app.launch()
        reveal(app.buttons["course.explore"],in: app).tap()
        reveal(app.buttons["hole.whispering-coast-06"],in: app).tap()
        reveal(app.buttons["play.meadow"],in: app).tap()
        XCTAssertTrue(app.staticTexts["game.phase"].waitForExistence(timeout: 5))
        app.buttons["controls.precise"].tap()
        app.buttons["club.selector"].tap();app.buttons["club.driver"].tap()
        for _ in 0..<2 { app.buttons["Aim one degree left"].tap() }
        setPower(52,in: app);app.buttons["swing.commit"].tap()
        waitForLabel("Strokes 2",element: app.staticTexts["game.strokes"])
        waitForLabel("Ready to swing",element: app.staticTexts["game.phase"])
        XCTAssertTrue(app.staticTexts["Water · +1 penalty · Moved to a safe drop"].exists)
        capture("river-water-safe-drop")
        app.buttons["club.selector"].tap();app.buttons["club.pitchingWedge"].tap()
        setPower(83,in: app);app.buttons["swing.commit"].tap()
        waitForLabel("Ready to swing",element: app.staticTexts["game.phase"])
        XCTAssertEqual(app.staticTexts["game.strokes"].label,"Strokes 3")
        app.buttons["club.selector"].tap();app.buttons["club.putter"].tap()
        app.segmentedControls["putt.range"].buttons["3 yd"].tap()
        for _ in 0..<9 { app.buttons["Aim one degree right"].tap() }
        setPower(17,in: app);app.buttons["swing.commit"].tap()
        XCTAssertTrue(app.staticTexts["result.strokes"].waitForExistence(timeout: 20))
        XCTAssertEqual(app.staticTexts["result.strokes"].label,"4 strokes · Par 4")
        capture("river-penalty-recovered-par")
    }

    func testLargestTextCanUseUntimedControlsAndPauseAfterShot() {
        let app = XCUIApplication()
        app.launchEnvironment["OFFSIDE_UI_TEST_SAVE"] = UUID().uuidString
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        reveal(app.buttons["play.meadow"], in: app).tap()
        XCTAssertTrue(app.staticTexts["game.phase"].waitForExistence(timeout: 5))
        reveal(app.buttons["controls.precise"], in: app).tap()
        let power = reveal(app.sliders["swing.power"], in: app)
        power.adjust(toNormalizedSliderPosition: 0.4)
        reveal(app.buttons["swing.commit"], in: app).tap()
        waitForLabel("Strokes 1",element: app.staticTexts["game.strokes"])
        capture("game-largest-text")
        for _ in 0..<12 where !app.buttons["game.pause"].isHittable { app.swipeDown() }
        app.buttons["game.pause"].tap()
        XCTAssertTrue(app.buttons["game.resume"].waitForExistence(timeout: 5))
        app.buttons["game.resume"].tap()
        XCTAssertEqual(app.staticTexts["game.strokes"].label,"Strokes 1")
    }

    @discardableResult private func reveal(_ element: XCUIElement,in app: XCUIApplication) -> XCUIElement {
        _ = element.waitForExistence(timeout: 2)
        for _ in 0..<12 where !element.exists || !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        XCTAssertTrue(element.isHittable)
        return element
    }

    private func openGame() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--profile-frames"]
        app.launchEnvironment["OFFSIDE_UI_TEST_SAVE"] = UUID().uuidString
        app.launch()
        let play = app.buttons["play.meadow"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        for _ in 0..<4 where !play.isHittable { app.swipeUp() }
        play.tap()
        XCTAssertTrue(app.staticTexts["game.phase"].waitForExistence(timeout: 5))
        return app
    }

    private func setPower(_ percent: Int, in app: XCUIApplication) {
        app.sliders["swing.power"].adjust(toNormalizedSliderPosition: CGFloat(percent) / 100)
        // Slider geometry may round one or two percent differently on phone/tablet.
        for _ in 0..<8 {
            let text = app.staticTexts["game.power"].label
            let actual = Int(text.filter(\.isNumber)) ?? -1
            if actual == percent { return }
            app.buttons[actual < percent ? "power.increase" : "power.decrease"].tap()
        }
        XCTAssertEqual(app.staticTexts["game.power"].label, "Power \(percent)%")
    }

    private func waitForLabel(_ label: String, element: XCUIElement) {
        expectation(for: NSPredicate(format: "label == %@", label), evaluatedWith: element)
        waitForExpectations(timeout: 20)
    }

    private func capture(_ name: String) {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = name
        image.lifetime = .keepAlways
        add(image)
    }

}
