import CoreGraphics
import OffsideGolfCore
import XCTest
@testable import OffsideGolf

final class WorldProjectionTests: XCTestCase {
    func testGroundAimRoundTripsInPortraitAndLandscape() {
        for size in [CGSize(width: 360, height: 580), CGSize(width: 690, height: 300)] {
            let projection = WorldProjection(worldBounds: CGRect(x: 0, y: 0, width: 100, height: 190), viewport: size)
            let point = Vector2(x: 50, y: 164.4752)
            let recovered = projection.groundPoint(at: projection.point(for: point))
            XCTAssertEqual(recovered.x, 50, accuracy: 0.000001)
            XCTAssertEqual(recovered.y, 164.4752, accuracy: 0.000001)
        }
    }

    func testPuttingViewportDoesNotStretchWorldDistances() {
        let projection = WorldProjection(worldBounds: CGRect(x: 30, y: 145, width: 40, height: 40),
                                         viewport: CGSize(width: 360, height: 500))
        let centre = projection.point(for: Vector2(x: 50, y: 165))
        XCTAssertEqual(centre.x, 180, accuracy: 0.000001)
        XCTAssertEqual(centre.y, 250, accuracy: 0.000001)
        let horizontal = projection.point(for: Vector2(x: 60, y: 165)).x - centre.x
        let vertical = projection.point(for: Vector2(x: 50, y: 175)).y - centre.y
        XCTAssertEqual(vertical / horizontal, sin(65 * .pi / 180), accuracy: 0.000001)
    }

    func testAltitudeRaisesBallWithoutMovingGroundShadow() {
        let projection = WorldProjection(worldBounds: CGRect(x: 0, y: 0, width: 100, height: 190),
                                         viewport: CGSize(width: 360, height: 580))
        let ground = projection.point(for: Vector2(x: 50, y: 80))
        let airborne = projection.point(for: Vector2(x: 50, y: 80), altitude: 10)
        XCTAssertEqual(airborne.x, ground.x)
        XCTAssertGreaterThan(airborne.y, ground.y)
    }
    func testAuthoredElevationAndValleyRoundTripWithoutMovingTheShadowOffGround() throws {
        for number in [5, 7] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: String(format: "whispering-coast-%02d", number), withExtension: "json"))
            let hole = try HoleDefinition.decode(Data(contentsOf: url))
            let projection = WorldProjection(worldBounds: CGRect(x: 0,y: 0,width: hole.bounds.width,height: hole.bounds.height),viewport: CGSize(width: 390,height: 420),hole: hole)
            for y in stride(from: 10.0,through: hole.bounds.height-10,by: 10) {
                let point = Vector2(x: 75,y: y)
                let restored = projection.groundPoint(at: projection.point(for: point))
                XCTAssertEqual(restored.x,point.x,accuracy: 0.00001)
                XCTAssertEqual(restored.y,point.y,accuracy: 0.00001)
            }
        }
    }

}
