import Foundation
import XCTest
@testable import OffsideGolfCore

final class CourseContentIntegrationTests: XCTestCase {
    private var holesURL: URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { root.deleteLastPathComponent() }
        return root.appendingPathComponent("_OffsideGolf-frontend-iOS/App/Resources/Courses/Holes")
    }
    func testAllShippedHolesDecodeAndRoutesMatchManifestLengths() throws {
        let distances = [158.0,325,365,145,475,340,165,485,390]
        for number in 1...9 {
            let url = holesURL.appendingPathComponent(String(format:"whispering-coast-%02d.json",number))
            let hole = try HoleDefinition.decode(Data(contentsOf: url))
            XCTAssertEqual(hole.physicsVersion, 2)
            let length = zip(hole.route,hole.route.dropFirst()).reduce(0) { $0 + $1.0.distance(to: $1.1) }
            XCTAssertEqual(length / 0.9144, distances[number - 1],accuracy: 0.01)
        }
    }
    func testFullPhysicsHoleOneAceAndApproachPuttAtEveryRefreshRate() throws {
        let hole = try HoleDefinition.decode(Data(contentsOf: holesURL.appendingPathComponent("whispering-coast-01.json")))
        for fps in [30,60,120] {
            var game = GameReducer(hole: hole)
            for power in [0.44,0.63] {
                game.send(.beginCharge); game.send(.setPower(power)); game.send(.release)
                for _ in 0..<(fps * 32) { game.advance(by: 1 / Double(fps)) }
                if power == 0.44 {
                    XCTAssertEqual(game.state.club,.putter)
                    XCTAssertEqual(game.state.puttRange,.medium)
                    XCTAssertEqual(game.state.ball.position.y,168.762809,accuracy:0.001)
                }
            }
            XCTAssertEqual(game.state.result,HoleResult(strokes:2,par:3))
            game.send(.restart); game.send(.beginCharge); game.send(.setPower(0.45)); game.send(.release)
            for _ in 0..<(fps * 32) { game.advance(by: 1 / Double(fps)) }
            XCTAssertEqual(game.state.result?.title,"Ace")
            XCTAssertEqual(game.state.strokeCount,1)
        }
    }
}
