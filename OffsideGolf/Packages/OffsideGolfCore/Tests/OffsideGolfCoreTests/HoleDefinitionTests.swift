import Foundation
import XCTest
@testable import OffsideGolfCore

func practiceHoleData() throws -> Data {
    let url = try XCTUnwrap(Bundle.module.url(forResource: "hole-1", withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}
func practiceHole() throws -> HoleDefinition { try HoleDefinition.decode(practiceHoleData()) }

final class HoleDefinitionTests: XCTestCase {
    func testFixtureHas158YardPlayableHole() throws {
        let hole = try practiceHole()
        XCTAssertEqual(hole.tee.distance(to: hole.pin), 144.4752, accuracy: 0.000001)
        XCTAssertTrue(hole.green.contains(hole.pin))
        XCTAssertFalse(hole.green.contains(hole.tee))
    }
    func testNormalizationRejectsNonfiniteAndZeroWithoutPoisoningMath() {
        XCTAssertEqual(Vector2.zero.normalized, .zero)
        XCTAssertEqual(Vector2(x: .infinity, y: 1).normalized, .zero)
        XCTAssertEqual(Vector2(x: .nan, y: 0).normalized, .zero)
        XCTAssertEqual(Vector2(x: 3, y: 4).normalized.x, 0.6, accuracy: 1e-12)
        XCTAssertEqual(Vector2(x: 3, y: 4).normalized.y, 0.8, accuracy: 1e-12)
        XCTAssertEqual(Vector2(x: 1e300, y: 1e300).normalized.length, 1, accuracy: 1e-12)
    }
    func testInvalidGeometryAndMetadataAreRejected() throws {
        let mutations: [(inout [String: Any]) -> Void] = [
            { $0["schemaVersion"] = 2 }, { $0["id"] = " \n" }, { $0["par"] = 6 },
            { $0["bounds"] = ["width": 0, "height": 190] },
            { $0["bounds"] = ["width": 1e100, "height": 190] },
            { $0["tee"] = ["x": -1, "y": 20] },
            { $0["pin"] = ["x": 99.9, "y": 20] },
            { $0["green"] = ["center": ["x": 50, "y": 164], "radiusX": 0, "radiusY": 11] },
            { $0["green"] = ["center": ["x": 95, "y": 164], "radiusX": 13, "radiusY": 11] },
            { $0["fairway"] = [["x": 20, "y": 20], ["x": 30, "y": 30], ["x": 40, "y": 40]] },
            { $0["fairway"] = [["x": 20, "y": 20], ["x": 80, "y": 80], ["x": 20, "y": 80], ["x": 80, "y": 20]] },
            { $0["fairway"] = [["x": 20, "y": 20], ["x": 20, "y": 20], ["x": 80, "y": 80]] }
        ]
        for mutate in mutations {
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with: practiceHoleData()) as? [String: Any])
            mutate(&object)
            XCTAssertThrowsError(try HoleDefinition.decode(JSONSerialization.data(withJSONObject: object)))
        }
        let nonfinite = String(data: try practiceHoleData(), encoding: .utf8)!.replacingOccurrences(of: "164.4752", with: "1e999")
        XCTAssertThrowsError(try HoleDefinition.decode(Data(nonfinite.utf8)))
    }
}
