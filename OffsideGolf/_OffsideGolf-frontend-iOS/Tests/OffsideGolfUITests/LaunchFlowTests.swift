import XCTest
import UIKit

@MainActor
final class LaunchFlowTests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
        await MainActor.run { XCUIDevice.shared.orientation = .portrait }
    }

    func testExploreCourseOpenHoleAndReturnToMenu() {
        let app = XCUIApplication()
        app.launchEnvironment["OFFSIDE_UI_TEST_SAVE"] = UUID().uuidString
        app.launch()
        openCourse(in: app)
        XCTAssertTrue(app.staticTexts["Par 35"].exists)
        app.buttons["hole.whispering-coast-01"].tap()
        XCTAssertTrue(app.staticTexts["Meadow Start"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["hole.preview.status"].exists)
        capture(app, name: "iOS-hole-preview")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["hole.whispering-coast-01"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["course.explore"].waitForExistence(timeout: 5))
        assertIllustrationIsRendered(in: app)
        capture(app, name: "iOS-menu")
    }

    func testRotationPreservesSelectedHoleAndNavigation() {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchEnvironment["OFFSIDE_UI_TEST_SAVE"] = UUID().uuidString
        app.launch()
        openCourse(in: app)
        app.buttons["hole.whispering-coast-01"].tap()
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.staticTexts["Meadow Start"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars.buttons.element(boundBy: 0).isHittable)
        capture(app, name: "iOS-landscape-preview")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["hole.whispering-coast-01"].tap()
        XCTAssertTrue(app.staticTexts["Meadow Start"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["course.explore"].waitForExistence(timeout: 5))
        capture(app, name: "iOS-landscape-menu")
        openCourse(in: app)
        app.buttons["hole.whispering-coast-01"].tap()
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.staticTexts["Meadow Start"].exists)
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.staticTexts["Meadow Start"].waitForExistence(timeout: 5))
    }

    func testNinthHoleIsReachableAtAccessibilityTextSize() {
        let app = XCUIApplication()
        app.launchEnvironment["OFFSIDE_UI_TEST_SAVE"] = UUID().uuidString
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let explore = app.buttons["course.explore"]
        XCTAssertTrue(explore.waitForExistence(timeout: 5))
        for _ in 0..<5 where !explore.isHittable { app.swipeUp() }
        XCTAssertTrue(explore.isHittable)
        explore.tap()
        let lastHole = app.buttons["hole.whispering-coast-09"]
        for _ in 0..<20 where !lastHole.isHittable { app.swipeUp() }
        XCTAssertTrue(lastHole.isHittable)
        lastHole.tap()
        XCTAssertTrue(app.staticTexts["Lighthouse Home"].waitForExistence(timeout: 5))
        capture(app, name: "iOS-large-text")
    }

    func testScrollingMenuKeepsContentOutOfStatusBar() throws {
        let app = XCUIApplication()
        app.launchEnvironment["OFFSIDE_UI_TEST_SAVE"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.buttons["play.meadow"].waitForExistence(timeout: 5))
        let scroll = app.scrollViews.firstMatch
        // SwiftUI exposes the scroll view's extended frame to XCTest. The initial
        // brand sits 24 pt inside its safe viewport, matching the menu's content inset.
        let safeTop = app.staticTexts["OFFSIDEGOLF"].frame.minY - 24
        XCTAssertGreaterThan(safeTop, 20)
        let start = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        // A slow, short drag moves the brand through the status bar without flick inertia.
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -70)),
                    withVelocity: .slow, thenHoldForDuration: 0.5)
        capture(app, name: "menu-status-bar-scrolled")
        let screenshot = XCUIScreen.main.screenshot().image
        let source = try XCTUnwrap(screenshot.cgImage)
        let scale = CGFloat(source.width) / app.frame.width
        let strip = CGRect(x: 0, y: 0, width: source.width, height: Int(safeTop * scale))
        let crop = try XCTUnwrap(source.cropping(to: strip))
        var pixels = [UInt8](repeating: 0, count: crop.width * crop.height * 4)
        let menuInkPixels = try pixels.withUnsafeMutableBytes { bytes -> Int in
            let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: crop.width, height: crop.height,
                bitsPerComponent: 8, bytesPerRow: crop.width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(crop, in: CGRect(x: 0, y: 0, width: crop.width, height: crop.height))
            let values = bytes.bindMemory(to: UInt8.self)
            // Pine-green menu ink is distinct from the cream background and the
            // system's neutral clock/icons, including the black camera island.
            return stride(from: 0, to: values.count, by: 4).filter {
                Int(values[$0 + 1]) - Int(values[$0]) > 15 && values[$0] < 140
            }.count
        }
        XCTAssertEqual(menuInkPixels, 0, "Menu lettering must not draw into the cream status-bar area")
        // Pulling back to the top restores the full brand and keeps primary actions usable.
        app.swipeDown()
        XCTAssertTrue(app.staticTexts["OFFSIDEGOLF"].exists)
        XCTAssertTrue(app.buttons["play.meadow"].isHittable)
    }

    private func openCourse(in app: XCUIApplication) {
        let button = app.buttons["course.explore"]
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(app.buttons["hole.whispering-coast-01"].waitForExistence(timeout: 5))
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertIllustrationIsRendered(in app: XCUIApplication) {
        let illustration = app.images["course.illustration"]
        XCTAssertTrue(illustration.waitForExistence(timeout: 5))
        // Returning from a button below the fold preserves the menu scroll offset.
        // A partially visible image is hittable but its screenshot can be clipped.
        for _ in 0..<3 { app.swipeDown() }
        capture(app, name: "iOS-menu-render")
        // Inspect the centre of the actual rendered panel, excluding its text badge.
        // A detached SpriteKit view is uniformly grey even though navigation works.
        let rendered = NSPredicate { _, _ in
            guard let source = illustration.screenshot().image.cgImage else { return false }
            let rect = CGRect(x: source.width / 10, y: source.height / 10,
                              width: source.width * 8 / 10, height: source.height * 8 / 10)
            guard let crop = source.cropping(to: rect) else { return false }
            var pixels = [UInt8](repeating: 0, count: 16 * 16 * 4)
            let saturated = pixels.withUnsafeMutableBytes { bytes -> Int in
                guard let context = CGContext(data: bytes.baseAddress, width: 16, height: 16,
                                              bitsPerComponent: 8, bytesPerRow: 64,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return 0 }
                context.draw(crop, in: CGRect(x: 0, y: 0, width: 16, height: 16))
                let values = bytes.bindMemory(to: UInt8.self)
                return stride(from: 0, to: values.count, by: 4).filter { index in
                    let channels = [Int(values[index]), Int(values[index + 1]), Int(values[index + 2])]
                    return (channels.max() ?? 0) - (channels.min() ?? 0) > 25
                }.count
            }
            return saturated > 64
        }
        expectation(for: rendered, evaluatedWith: nil)
        waitForExpectations(timeout: 5)
    }
}
