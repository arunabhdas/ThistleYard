import Foundation
import Observation
import OffsideGolfCore

@MainActor
@Observable
final class AppCoordinator {
    enum ContentState {
        case loading
        case ready(CourseManifest)
        case failed(String)
    }

    private(set) var content: ContentState = .loading
    private let loadData: @MainActor () throws -> Data

    init(loadData: @escaping @MainActor () throws -> Data = AppCoordinator.bundledCourseData) {
        self.loadData = loadData
    }

    func loadCourse() {
        do {
            content = .ready(try CourseManifest.decode(loadData()))
        } catch {
            content = .failed("The course could not be opened. Please try again. If this continues, close and reopen OffsideGolf.")
        }
    }

    private static func bundledCourseData() throws -> Data {
        guard let url = Bundle.main.url(forResource: "whispering-coast", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try Data(contentsOf: url)
    }
}
