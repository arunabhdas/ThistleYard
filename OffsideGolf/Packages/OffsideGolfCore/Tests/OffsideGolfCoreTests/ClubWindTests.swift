import Foundation
import XCTest
@testable import OffsideGolfCore

func extendedHole(_ edit: (inout [String: Any]) -> Void = { _ in }) throws -> HoleDefinition {
    var object = try XCTUnwrap(JSONSerialization.jsonObject(with: practiceHoleData()) as? [String: Any])
    object["physicsVersion"] = 2
    edit(&object)
    return try HoleDefinition.decode(JSONSerialization.data(withJSONObject: object))
}

final class ClubWindTests: XCTestCase {
    func testLongHoleRecommendsLongestLegalClubAtTee() throws {
        let hole=try extendedHole {
            $0["bounds"]=["width":100,"height":600]
            $0["pin"]=["x":50,"y":550]
            $0["green"]=["center":["x":50,"y":550],"radiusX":13,"radiusY":11]
        }
        XCTAssertEqual(GameReducer(hole:hole).state.club,.driver)
    }
    func testRecommendationUsesElevatedGroundCollision() throws {
        let flat=try extendedHole {
            $0["pin"]=["x":50,"y":160]
            $0["green"]=["center":["x":50,"y":160],"radiusX":13,"radiusY":11]
        }
        let uphill=try extendedHole {
            $0["pin"]=["x":50,"y":160]
            $0["green"]=["center":["x":50,"y":160],"radiusX":13,"radiusY":11]
            $0["elevation"]=["origin":["x":50,"y":20],"baseHeight":0,"gradient":["x":0,"y":0.08]]
        }
        XCTAssertEqual(ClubRecommendation.recommend(hole:flat,position:flat.tee,target:flat.pin),.fiveIron)
        XCTAssertEqual(ClubRecommendation.recommend(hole:uphill,position:uphill.tee,target:uphill.pin),.driver)
    }
    func testSixClubsCalibrateToIndependentlySpecifiedCarry() {
        for (club, yards) in [(GolfClubType.driver, 230.0), (.fiveIron,180), (.sevenIron,145), (.pitchingWedge,100), (.sandWedge,65)] {
            var ball = FlightSolver.launch(position: .zero, direction: Vector2(x: 0,y: 1), power: 1, club: club, drag: 0.04)
            for _ in 0..<2400 {
                let step = FlightSolver.advance(ball, by: 1.0 / 120, wind: .calm, drag: 0.04)
                ball = step.ball
                if step.landed { break }
            }
            XCTAssertEqual(ball.position.y, yards * 0.9144, accuracy: 0.2286)
        }
        XCTAssertEqual(GolfClubType.allCases.count, 6)
    }
    func testMirroredWindAndHeadTailResponse() {
        func landing(_ wind: WindCondition) -> Vector2 {
            var ball = FlightSolver.launch(position: .zero, direction: Vector2(x: 0,y: 1), power: 1, club: .fiveIron, drag: 0.04)
            for _ in 0..<2400 {
                let step = FlightSolver.advance(ball, by: 1.0 / 120, wind: wind, drag: 0.04)
                ball = step.ball; if step.landed { break }
            }
            return ball.position
        }
        let east = landing(WindCondition(speedMPH: 5, towardDegrees: 90))
        let west = landing(WindCondition(speedMPH: 5, towardDegrees: 270))
        XCTAssertGreaterThan(east.x, 0)
        XCTAssertEqual(east.x, -west.x, accuracy: 0.000001)
        XCTAssertEqual(east.y, west.y, accuracy: 0.000001)
        XCTAssertGreaterThan(landing(WindCondition(speedMPH: 5,towardDegrees: 0)).y, landing(.calm).y)
        XCTAssertLessThan(landing(WindCondition(speedMPH: 5,towardDegrees: 180)).y, landing(.calm).y)
    }
    func testManualClubAndFrozenPuttingRangeCommands() throws {
        var game = GameReducer(hole: try extendedHole())
        game.send(.chooseClub(.sevenIron)); game.send(.beginCharge); game.send(.setPower(0.5))
        XCTAssertEqual(game.state.club, .sevenIron)
        game.send(.release); game.send(.chooseClub(.driver))
        XCTAssertEqual(game.state.club, .sevenIron)
        game.send(.restart); game.send(.chooseClub(.putter)); game.send(.setPuttRange(.short))
        game.send(.beginCharge); game.send(.setPower(0.5)); game.send(.release)
        game.send(.setPuttRange(.long))
        XCTAssertEqual(game.state.puttRange, .short)
    }
    func testPreviewUsesRealSimulationAndLeavesSourceUnchanged() throws {
        let hole = try extendedHole()
        var game = GameReducer(hole: hole)
        game.send(.chooseClub(.sevenIron))
        let original = game.state
        let prediction = ShotPredictor.predict(hole: hole, state: game.state, power: 0.6)
        XCTAssertEqual(game.state, original)
        game.send(.beginCharge); game.send(.setPower(0.6)); game.send(.release)
        for _ in 0..<4000 { game.advance(by: 1.0 / 120) }
        XCTAssertEqual(prediction.finalPosition.x, game.state.ball.position.x, accuracy: 1e-9)
        XCTAssertEqual(prediction.finalPosition.y, game.state.ball.position.y, accuracy: 1e-9)
        XCTAssertNotNil(prediction.firstLanding)
        XCTAssertGreaterThan(prediction.samples.count, 3)
    }
}
