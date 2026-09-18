import CoreGraphics
import ImageIO
import OffsideGolfCore
import SpriteKit
import XCTest
@testable import OffsideGolf

final class GolferFacingTests: XCTestCase {
    func testEightShotDirectionsSelectRightHandedBodyFacing() {
        let examples: [(Vector2, GolferFacing)] = [
            (.init(x: 0, y: 1), .east), (.init(x: 1, y: 1), .southEast),
            (.init(x: 1, y: 0), .south), (.init(x: 1, y: -1), .southWest),
            (.init(x: 0, y: -1), .west), (.init(x: -1, y: -1), .northWest),
            (.init(x: -1, y: 0), .north), (.init(x: -1, y: 1), .northEast)
        ]
        for (aim, expected) in examples {
            XCTAssertEqual(GolferFacing.forAim(aim), expected)
            XCTAssertEqual(GolferFacing.forAim(aim * 700), expected)
        }
    }

    func testNearestFacingWrapsAcrossNorthAndInvalidAimKeepsFallback() {
        // Inverse of body=(aim.y,-aim.x) to supply the specified body headings.
        func aim(bodyDegrees: Double) -> Vector2 {
            let angle = bodyDegrees * .pi / 180
            return Vector2(x: -cos(angle), y: sin(angle))
        }
        for angle in [-1.0, 0, 1, 359, 360, 361] {
            XCTAssertEqual(GolferFacing.forAim(aim(bodyDegrees: angle)), .north)
        }
        XCTAssertEqual(GolferFacing.forAim(aim(bodyDegrees: 22.4)), .north)
        XCTAssertEqual(GolferFacing.forAim(aim(bodyDegrees: 22.6)), .northEast)
        XCTAssertEqual(GolferFacing.forAim(aim(bodyDegrees: -22.4)), .north)
        XCTAssertEqual(GolferFacing.forAim(aim(bodyDegrees: -22.6)), .northWest)
        for invalid in [Vector2.zero, .init(x: .nan, y: 1), .init(x: 1, y: .infinity)] {
            XCTAssertEqual(GolferFacing.forAim(invalid, fallback: .southWest), .southWest)
        }
        XCTAssertEqual(GolferFacing.forAim(.zero), .east)
    }

    func testEveryFacingUsesAllTwelveDistinctTopLeftRowMajorCells() {
        let expectedNames = ["golfer_north", "golfer_northEast", "golfer_east", "golfer_poses_sheet",
                             "golfer_south", "golfer_southWest", "golfer_west", "golfer_northWest"]
        let expectedOrigins: [(Double, Double)] = [
            (0, 2.0/3), (0.25, 2.0/3), (0.5, 2.0/3), (0.75, 2.0/3),
            (0, 1.0/3), (0.25, 1.0/3), (0.5, 1.0/3), (0.75, 1.0/3),
            (0, 0), (0.25, 0), (0.5, 0), (0.75, 0)
        ]
        for (index, facing) in GolferFacing.allCases.enumerated() {
            XCTAssertEqual(facing.sheetName, expectedNames[index])
            for (poseIndex, pose) in GolferPose.allCases.enumerated() {
                let cell = facing.textureRect(for: pose)
                XCTAssertEqual(cell.minX, expectedOrigins[poseIndex].0, accuracy: 1e-12)
                XCTAssertEqual(cell.minY, expectedOrigins[poseIndex].1, accuracy: 1e-12)
                XCTAssertEqual(cell.width, 0.25, accuracy: 1e-12)
                XCTAssertEqual(cell.height, 1.0/3, accuracy: 1e-12)
            }
        }
    }

    @MainActor
    func testRenderingChangesFacingAndStanceWithoutMutatingGameOrMirroring() throws {
        var game = try makeGame()
        let renderer = GolferRenderer(sheetProvider: { _ in SKTexture() })
        let projection = WorldProjection(worldBounds: CGRect(x: 0, y: 0, width: 100, height: 190),
                                         viewport: CGSize(width: 390, height: 600))
        let ballPoint = projection.point(for: game.state.ball.position)
        let sprite = try XCTUnwrap(renderer.node.children.compactMap { $0 as? SKSpriteNode }.first)
        var previousTexture: SKTexture?
        let examples: [(Vector2, GolferFacing, Double, Double)] = [
            (.init(x: 0, y: 1), .east, -20, 0),
            (.init(x: 1, y: 0), .south, 0, 20),
            (.init(x: 0, y: -1), .west, 20, 0),
            (.init(x: -1, y: 0), .north, 0, -20)
        ]
        for (aim, expectedFacing, dx, dy) in examples {
            game.send(.aim(aim))
            let before = game.state
            renderer.render(state: game.state, projection: projection, appearance: GolferAppearance(), reducedMotion: true, elapsed: 0, visualScale: 0.5)
            XCTAssertEqual(renderer.facing, expectedFacing)
            let texture = try XCTUnwrap(sprite.texture)
            if let previousTexture { XCTAssertFalse(texture === previousTexture) }
            previousTexture = texture
            // SpriteKit stores transforms at float precision; 0.0001pt is below a visible pixel.
            XCTAssertEqual(renderer.node.position.x, ballPoint.x + dx * 0.5, accuracy: 1e-4)
            XCTAssertEqual(renderer.node.position.y, ballPoint.y + dy * 0.5, accuracy: 1e-4)
            XCTAssertEqual(game.state, before)
            XCTAssertGreaterThan(renderer.node.xScale, 0)
            for child in renderer.node.children { XCTAssertGreaterThan(child.xScale, 0) }
        }
    }

    @MainActor
    func testFacingCacheRetainsThreeMostRecentlyUsedSheets() throws {
        var loaded: [GolferFacing] = []
        let renderer = GolferRenderer(sheetProvider: { facing in loaded.append(facing); return SKTexture() })
        var game = try makeGame()
        let projection = WorldProjection(worldBounds: CGRect(x: 0, y: 0, width: 100, height: 190), viewport: CGSize(width: 390, height: 600))
        func render(_ aim: Vector2) {
            game.send(.aim(aim))
            renderer.render(state: game.state, projection: projection, appearance: GolferAppearance(), reducedMotion: true, elapsed: 0)
        }
        render(.init(x: 0, y: 1)) // East.
        render(.init(x: 1, y: 0)) // South.
        render(.init(x: 0, y: -1)) // West.
        render(.init(x: 0, y: 1)) // Touch East, so South is now oldest.
        render(.init(x: -1, y: 0)) // North evicts South.
        render(.init(x: 0, y: 1)) // East remains resident.
        render(.init(x: 1, y: 0)) // South must load again.
        XCTAssertEqual(loaded, [.east, .south, .west, .north, .south])
    }

    @MainActor
    func testActualBundledSheetsDecodeAndRenderAllEightFacings() throws {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        let renderer = GolferRenderer(bundle: bundle)
        let sprite = try XCTUnwrap(renderer.node.children.compactMap { $0 as? SKSpriteNode }.first)
        var game = try makeGame()
        let projection = WorldProjection(worldBounds: CGRect(x: 0, y: 0, width: 100, height: 190), viewport: CGSize(width: 390, height: 600))
        let aims: [Vector2] = [.init(x: -1, y: 0), .init(x: -1, y: 1), .init(x: 0, y: 1), .init(x: 1, y: 1),
                              .init(x: 1, y: 0), .init(x: 1, y: -1), .init(x: 0, y: -1), .init(x: -1, y: -1)]
        for (index, facing) in GolferFacing.allCases.enumerated() {
            let url = try XCTUnwrap(bundle.url(forResource: facing.sheetName, withExtension: "png"), "Missing \(facing.sheetName).png")
            let source = try XCTUnwrap(CGImageSourceCreateWithURL(url as CFURL, nil))
            let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
            XCTAssertEqual(image.width, 1448)
            XCTAssertEqual(image.height, 1086)
            XCTAssertTrue([CGImageAlphaInfo.first, .last, .premultipliedFirst, .premultipliedLast].contains(image.alphaInfo))
            game.send(.aim(aims[index]))
            renderer.render(state: game.state, projection: projection, appearance: GolferAppearance(), reducedMotion: true, elapsed: 0)
            XCTAssertEqual(renderer.facing, facing)
            let cell = try XCTUnwrap(sprite.texture)
            XCTAssertEqual(cell.size().width, 362, accuracy: 0.01)
            XCTAssertEqual(cell.size().height, 362, accuracy: 0.01)
        }
    }

    @MainActor
    func testEightFacingRenderedVisualAttachments() throws {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        let renderer = GolferRenderer(bundle: bundle)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 512, height: 512))
        let scene = SKScene(size: CGSize(width: 512, height: 512))
        scene.backgroundColor = .clear
        scene.addChild(renderer.node)
        view.presentScene(scene)
        defer { view.presentScene(nil) }
        var game = try makeGame()
        let projection = WorldProjection(worldBounds: CGRect(x: 0, y: 0, width: 100, height: 190), viewport: CGSize(width: 512, height: 512))
        let aims: [Vector2] = [.init(x: -1, y: 0), .init(x: -1, y: 1), .init(x: 0, y: 1), .init(x: 1, y: 1),
                              .init(x: 1, y: 0), .init(x: 1, y: -1), .init(x: 0, y: -1), .init(x: -1, y: -1)]
        for (index, facing) in GolferFacing.allCases.enumerated() {
            game.send(.aim(aims[index]))
            let state = game.state
            renderer.render(state: state, projection: projection, appearance: GolferAppearance(), reducedMotion: true, elapsed: 0, visualScale: 3)
            XCTAssertEqual(renderer.facing, facing)
            XCTAssertEqual(game.state, state)
            XCTAssertGreaterThan(renderer.node.xScale, 0)
            let bounds = renderer.node.calculateAccumulatedFrame()
            XCTAssertGreaterThan(bounds.width, 0)
            XCTAssertGreaterThan(bounds.height, 0)
            guard let texture = view.texture(from: renderer.node) else {
                throw XCTSkip("Offscreen SpriteKit texture capture is unavailable on this test host")
            }
            let image = texture.cgImage()
            XCTAssertGreaterThan(image.width, 0)
            XCTAssertGreaterThan(image.height, 0)
            let png = NSMutableData()
            let destination = try XCTUnwrap(CGImageDestinationCreateWithData(png as CFMutableData, "public.png" as CFString, 1, nil))
            CGImageDestinationAddImage(destination, image, nil)
            XCTAssertTrue(CGImageDestinationFinalize(destination))
            let attachment = XCTAttachment(data: png as Data, uniformTypeIdentifier: "public.png")
            attachment.name = "Golfer-body-\(facing.rawValue)-3x"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private func makeGame() throws -> GameReducer {
        let data = Data(#"{"schemaVersion":1,"id":"hole-1","par":3,"bounds":{"width":100,"height":190},"tee":{"x":50,"y":20},"pin":{"x":50,"y":164.4752},"green":{"center":{"x":50,"y":164.4752},"radiusX":13,"radiusY":11},"fairway":[{"x":30,"y":10},{"x":70,"y":10},{"x":70,"y":180},{"x":30,"y":180}]}"#.utf8)
        return GameReducer(hole: try HoleDefinition.decode(data))
    }
}
