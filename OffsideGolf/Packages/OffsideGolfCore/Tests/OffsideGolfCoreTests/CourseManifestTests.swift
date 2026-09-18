import Foundation
import XCTest
@testable import OffsideGolfCore

final class CourseManifestTests: XCTestCase {
    func testValidCourseLoadsAllHolesAndDerivesRoundTotals() throws {
        let course = try CourseManifest.decode(fixture())
        XCTAssertEqual(course.holes.count, 9)
        XCTAssertEqual(course.totalPar, 35)
        XCTAssertEqual(course.totalDistanceYards, 2_848)
        XCTAssertEqual(course.holes.first?.name, "Meadow Start")
        XCTAssertEqual(course.holes.last?.number, 9)
    }

    func testUnsupportedSchemaDoesNotSilentlyLoad() throws {
        try expectInvalid(.unsupportedSchema(2)) { $0["schemaVersion"] = 2 }
    }

    func testMissingHoleCannotBecomeACompleteCourse() throws {
        try expectInvalid(.invalidHoleCount) { object in
            var holes = try XCTUnwrap(object["holes"] as? [[String: Any]])
            holes.removeLast()
            object["holes"] = holes
        }
    }

    func testDuplicateHoleIdentityIsRejected() throws {
        try expectInvalid(.duplicateHoleID) { object in
            var holes = try XCTUnwrap(object["holes"] as? [[String: Any]])
            holes[1]["id"] = holes[0]["id"]
            object["holes"] = holes
        }
    }

    func testDuplicateOrOutOfOrderNumberCannotMislabelRoundProgress() throws {
        try expectInvalid(.invalidHoleSequence) { object in
            var holes = try XCTUnwrap(object["holes"] as? [[String: Any]])
            holes[1]["number"] = 1
            object["holes"] = holes
        }
    }

    func testInvalidParCannotEnterScoring() throws {
        try expectInvalid(.invalidHole(number: 1)) { object in
            var holes = try XCTUnwrap(object["holes"] as? [[String: Any]])
            holes[0]["par"] = 0
            object["holes"] = holes
        }
    }

    func testZeroAndNegativeDistanceAreRejected() throws {
        for distance in [0, -20] {
            try expectInvalid(.invalidHole(number: 1)) { object in
                var holes = try XCTUnwrap(object["holes"] as? [[String: Any]])
                holes[0]["distanceYards"] = distance
                object["holes"] = holes
            }
        }
    }

    func testBlankHoleTextCannotProduceAnEmptyNavigationLabel() throws {
        try expectInvalid(.invalidHole(number: 1)) { object in
            var holes = try XCTUnwrap(object["holes"] as? [[String: Any]])
            holes[0]["name"] = " \n "
            object["holes"] = holes
        }
    }

    func testInvalidCourseMetadataIsRejected() throws {
        for field in ["id", "name", "summary"] {
            try expectInvalid(.invalidMetadata) { $0[field] = " " }
        }
        try expectInvalid(.invalidMetadata) { $0["contentVersion"] = 0 }
    }

    func testMalformedJSONReturnsErrorRatherThanDefaultCourse() {
        XCTAssertThrowsError(try CourseManifest.decode(Data("{broken".utf8)))
    }

    func testMissingRequiredFieldIsRejected() throws {
        var object = try fixtureObject()
        object.removeValue(forKey: "holes")
        let data = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try CourseManifest.decode(data))
    }

    private func fixture() throws -> Data {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "manifest", withExtension: "json", subdirectory: "Fixtures"))
        return try Data(contentsOf: url)
    }

    private func fixtureObject() throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: fixture()) as? [String: Any])
    }

    private func expectInvalid(
        _ expected: CourseManifestError,
        file: StaticString = #filePath,
        line: UInt = #line,
        mutate: (inout [String: Any]) throws -> Void
    ) throws {
        var object = try fixtureObject()
        try mutate(&object)
        let data = try JSONSerialization.data(withJSONObject: object)
        XCTAssertThrowsError(try CourseManifest.decode(data), file: file, line: line) { error in
            XCTAssertEqual(error as? CourseManifestError, expected, file: file, line: line)
        }
    }
}
