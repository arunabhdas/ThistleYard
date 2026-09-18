import Foundation
import XCTest
@testable import OffsideGolf

@MainActor
final class AppCoordinatorTests: XCTestCase {
    func testBundledCourseReachesReadyStateWithNineHoles() throws {
        let coordinator = AppCoordinator()
        coordinator.loadCourse()
        guard case .ready(let course) = coordinator.content else {
            return XCTFail("The shipped course must load successfully.")
        }
        XCTAssertEqual(course.holes.count, 9)
        XCTAssertEqual(course.totalPar, 35)
    }

    func testReadFailureCanRecoverOnRetry() throws {
        let data = try bundledData()
        var attempts = 0
        let coordinator = AppCoordinator {
            attempts += 1
            if attempts == 1 { throw CocoaError(.fileReadUnknown) }
            return data
        }
        coordinator.loadCourse()
        guard case .failed = coordinator.content else {
            return XCTFail("Read failures must be visible.")
        }
        coordinator.loadCourse()
        guard case .ready(let course) = coordinator.content else {
            return XCTFail("Retry must replace the failure with loaded content.")
        }
        XCTAssertEqual(course.id, "whispering-coast")
    }

    func testCorruptContentIsNotShownAsAnEmptyCourse() {
        let coordinator = AppCoordinator { Data("{}".utf8) }
        coordinator.loadCourse()
        guard case .failed(let message) = coordinator.content else {
            return XCTFail("Invalid content must reach the recoverable failure state.")
        }
        XCTAssertFalse(message.isEmpty)
    }

    private func bundledData() throws -> Data {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "whispering-coast", withExtension: "json"))
        return try Data(contentsOf: url)
    }
}
