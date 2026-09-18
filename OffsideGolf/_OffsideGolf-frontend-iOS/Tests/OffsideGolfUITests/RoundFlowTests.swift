import XCTest

@MainActor
final class RoundFlowTests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
    }

    func testNineHolesThroughRealControlsAndPersistedPersonalBest() throws {
        let app = makeApp()
        app.launch()
        openButton("round.new",in: app).tap()
        XCTAssertTrue(app.staticTexts["game.phase"].waitForExistence(timeout: 8))
        app.buttons["controls.precise"].tap()
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "course-sequences",withExtension: "json"))
        let rounds = try JSONDecoder().decode([HoleFixture].self,from: Data(contentsOf: url))
        for (index,hole) in rounds.enumerated() {
            for shot in hole.shots {
                app.buttons["club.selector"].tap()
                app.buttons["club.\(shot.club)"].tap()
                if shot.club == "putter" {
                    let range = ["short":"3 yd","medium":"10 yd","long":"30 yd"][shot.puttRange] ?? "30 yd"
                    app.segmentedControls["putt.range"].buttons[range].tap()
                }
                let turn = shot.aimDeltaDegrees >= 0 ? "Aim one degree left" : "Aim one degree right"
                for _ in 0..<abs(shot.aimDeltaDegrees) { app.buttons[turn].tap() }
                setPower(Int((shot.power*100).rounded()),in: app)
                app.buttons["swing.commit"].tap()
                waitForShot(strokes: shot.strokes,in: app)
            }
            XCTAssertTrue(app.staticTexts["result.strokes"].waitForExistence(timeout: 20))
            XCTAssertEqual(app.staticTexts["result.strokes"].label,"\(hole.strokes) strokes · Par \(hole.par)")
            capture("Round-hole-\(index+1)")
            let next = app.buttons["result.next"]
            expectation(for: NSPredicate(format: "enabled == true"),evaluatedWith: next)
            waitForExpectations(timeout: 10)
            next.tap()
            if index < 8 {
                XCTAssertTrue(app.staticTexts["game.phase"].waitForExistence(timeout: 10))
                waitForLabel("Strokes 0",element: app.staticTexts["game.strokes"])
            }
        }
        XCTAssertTrue(app.staticTexts["scorecard.total"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["scorecard.total"].label,"32 strokes")
        capture("Round-complete-scorecard")
        let done = app.buttons["scorecard.done"]
        expectation(for: NSPredicate(format: "enabled == true"),evaluatedWith: done)
        waitForExpectations(timeout: 10)
        done.tap()
        app.terminate();app.launch()
        let best = app.staticTexts["Personal best · 32 strokes"]
        for _ in 0..<6 where !best.isHittable { app.swipeUp() }
        XCTAssertTrue(best.exists)
        XCTAssertFalse(app.buttons["round.continue"].exists)
    }

    func testCommittedShotSurvivesTerminationAndSettingsPersist() {
        let app = makeApp()
        app.launch()
        openButton("menu.settings",in: app).tap()
        let toggle = app.switches["Untimed power controls"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.92,dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "1")
        openButton("Replay the short tutorial",in: app).tap()
        XCTAssertTrue(app.navigationBars["A few small swings"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        for _ in 0..<6 where !toggle.isHittable { app.swipeDown() }
        XCTAssertEqual(toggle.value as? String,"1")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        openButton("round.new",in: app).tap()
        XCTAssertTrue(app.sliders["swing.power"].waitForExistence(timeout: 5), app.debugDescription)
        setPower(44,in: app)
        app.buttons["swing.commit"].tap()
        waitForLabel("Strokes 1",element: app.staticTexts["game.strokes"])
        app.terminate();app.launch()
        openButton("round.continue",in: app).tap()
        waitForLabel("Ready to swing",element: app.staticTexts["game.phase"])
        XCTAssertEqual(app.staticTexts["game.strokes"].label,"Strokes 1")
        XCTAssertEqual(app.staticTexts["game.club"].label,"Putter")
        XCTAssertTrue(app.sliders["swing.power"].exists)
        capture("Round-resumed-after-termination")
    }

    func testDeveloperAssistedRoundDoesNotCreatePersonalBest() {
        let app = makeApp()
        app.launch()
        openButton("round.new",in: app).tap()
        for _ in 1...9 {
            XCTAssertTrue(app.buttons["game.pause"].waitForExistence(timeout: 5))
            app.buttons["game.pause"].tap()
            app.buttons["debug.open"].tap()
            openButton("debug.complete",in: app).tap()
            let next = app.buttons["result.next"]
            XCTAssertTrue(next.waitForExistence(timeout: 5))
            expectation(for: NSPredicate(format: "enabled == true"),evaluatedWith: next)
            waitForExpectations(timeout: 10)
            next.tap()
        }
        XCTAssertTrue(app.staticTexts["Practice round · Personal best unchanged"].waitForExistence(timeout: 5))
        openButton("scorecard.done",in: app).tap()
        app.terminate();app.launch()
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@","Personal best ·")).firstMatch.exists)
        XCTAssertFalse(app.buttons["round.continue"].exists)
    }

    private func makeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["OFFSIDE_UI_TEST_SAVE"] = UUID().uuidString
        return app
    }
    private func openButton(_ id: String,in app: XCUIApplication) -> XCUIElement {
        let button = app.buttons[id]
        _ = button.waitForExistence(timeout: 2)
        for _ in 0..<8 where !button.exists || !button.isHittable { app.swipeUp() }
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        XCTAssertTrue(button.isHittable)
        return button
    }
    private func waitForShot(strokes: Int,in app: XCUIApplication) {
        let predicate = NSPredicate { _, _ in
            if app.staticTexts["result.strokes"].exists { return true }
            return app.staticTexts["game.strokes"].label == "Strokes \(strokes)" && app.staticTexts["game.phase"].label == "Ready to swing"
        }
        expectation(for: predicate,evaluatedWith: nil);waitForExpectations(timeout: 40)
    }
    private func setPower(_ percent: Int,in app: XCUIApplication) {
        app.sliders["swing.power"].adjust(toNormalizedSliderPosition: CGFloat(percent)/100)
        for _ in 0..<10 {
            let actual = Int(app.staticTexts["game.power"].label.filter(\.isNumber)) ?? -1
            if actual == percent { return }
            app.buttons[actual < percent ? "power.increase" : "power.decrease"].tap()
        }
        XCTAssertEqual(app.staticTexts["game.power"].label,"Power \(percent)%")
    }
    private func waitForLabel(_ label: String,element: XCUIElement) {
        expectation(for: NSPredicate(format: "label == %@",label),evaluatedWith: element)
        waitForExpectations(timeout: 40)
    }
    private func capture(_ name: String) {
        let image = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        image.name = name;image.lifetime = .keepAlways;add(image)
    }
    private struct HoleFixture: Decodable { let par: Int;let strokes: Int;let shots: [Shot] }
    private struct Shot: Decodable { let club: String;let puttRange: String;let power: Double;let aimDeltaDegrees: Int;let strokes: Int }
}
