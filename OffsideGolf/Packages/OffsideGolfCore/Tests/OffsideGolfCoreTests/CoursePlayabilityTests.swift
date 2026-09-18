import Foundation
import XCTest
@testable import OffsideGolfCore

/// Acceptance-only optimizer. Production never exposes the exact final-position guide used here.
final class CoursePlayabilityTests: XCTestCase {
    private struct ShotRecord: Codable {
        let club: GolfClubType
        let aimDeltaDegrees: Int
        let aimX: Double
        let aimY: Double
        let power: Double
        let puttRange: PuttRange
        let strokes: Int
    }
    private struct HoleRecord: Codable {
        let holeID: String
        let windMPH: Double
        let conservative: Bool
        let shots: [ShotRecord]
        let strokes: Int
        let par: Int
        let penalties: Int
    }
    private struct Candidate {
        let club: GolfClubType
        let direction: Vector2
        let aimDeltaDegrees: Int
        let power: Double
        let range: PuttRange
        let prediction: ShotPrediction
        let score: Double
    }
    private var holesURL: URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { root.deleteLastPathComponent() }
        return root.appendingPathComponent("_OffsideGolf-frontend-iOS/App/Resources/Courses/Holes")
    }
    func testConservativeCompleteRoundAtDefaultWinds() throws {
        var records: [HoleRecord] = []
        for number in 1...9 { records.append(try play(number: number, wind: nil, conservative: true)) }
        XCTAssertEqual(records.map(\.par).reduce(0,+),35)
        XCTAssertEqual(records.map(\.strokes).reduce(0,+),records.flatMap(\.shots).count)
        try export(records, name: "course-sequences.json")
    }
    func testAllHolesAtBothAuthoredWindLimits() throws {
        let ranges: [(Double,Double)] = [(0,0),(1,2),(3,5),(1,3),(2,4),(3,5),(2,4),(3,6),(4,6)]
        var records: [HoleRecord] = []
        for number in 1...9 {
            for wind in Set([ranges[number-1].0,ranges[number-1].1]).sorted() {
                records.append(try play(number: number,wind:wind,conservative:true))
            }
        }
        try export(records,name:"course-wind-limits.json")
    }
    func testAggressiveRouteAndWaterRecoveryArePlayable() throws {
        var records: [HoleRecord] = []
        for number in [3,6,8,9] { records.append(try play(number:number,wind:nil,conservative:false)) }
        try export(records,name:"course-aggressive-sequences.json")
        let recovery = try play(number:6,wind:nil,conservative:true,forceWater:true)
        XCTAssertEqual(recovery.penalties,1)
        try export([recovery],name:"course-water-recovery.json")
    }
    private func play(number: Int, wind: Double?, conservative: Bool, forceWater: Bool = false) throws -> HoleRecord {
        let url = holesURL.appendingPathComponent(String(format:"whispering-coast-%02d.json",number))
        var data = try Data(contentsOf:url)
        if let wind {
            var object = try XCTUnwrap(JSONSerialization.jsonObject(with:data) as? [String:Any])
            var setting = try XCTUnwrap(object["wind"] as? [String:Any]);setting["speedMPH"] = wind;object["wind"] = setting
            data = try JSONSerialization.data(withJSONObject:object)
        }
        let hole = try HoleDefinition.decode(data)
        var game = GameReducer(hole:hole), records: [ShotRecord] = []
        if forceWater {
            let water = try XCTUnwrap(hole.regions.first { $0.terrain == .water })
            let center = water.polygon.reduce(Vector2.zero,+) * (1 / Double(water.polygon.count))
            let targetDirection = (center-hole.tee).normalized
            let deltaDegrees=Int((atan2(game.state.aimDirection.cross(targetDirection),game.state.aimDirection.dot(targetDirection))*180 / .pi).rounded())
            let angle=Double(deltaDegrees)*Double.pi/180, aim=game.state.aimDirection
            let direction=Vector2(x:aim.x*cos(angle)-aim.y*sin(angle),y:aim.x*sin(angle)+aim.y*cos(angle))
            var chosen: (GolfClubType,Double)?
            search: for club in [GolfClubType.driver,.fiveIron,.sevenIron,.pitchingWedge] {
                for power in stride(from:0.1,through:1.0,by:0.01) {
                    var copy=game;copy.send(.chooseClub(club));copy.send(.aim(direction))
                    if ShotPredictor.predict(hole:hole,state:copy.state,power:power).outcome == .water { chosen=(club,power);break search }
                }
            }
            let shot=try XCTUnwrap(chosen,"Authored river must permit a controlled water shot")
            game.send(.chooseClub(shot.0));game.send(.aim(direction));game.send(.beginCharge);game.send(.setPower(shot.1));game.send(.release)
            for _ in 0..<3900 { game.advance(by:1.0/120);if game.state.phase == .aiming { break } }
            XCTAssertEqual(game.state.penaltyCount,1);XCTAssertEqual(game.state.strokeCount,2)
            XCTAssertEqual(game.state.lastOutcome,.water)
            records.append(ShotRecord(club:shot.0,aimDeltaDegrees:deltaDegrees,aimX:direction.x,aimY:direction.y,power:shot.1,puttRange:.long,strokes:2))
        }
        for _ in 0..<20 {
            if game.state.phase == .complete { break }
            let candidate = try XCTUnwrap(bestShot(game:game,conservative:conservative),"No safe shot for \(hole.id), \(game.state.ball.position)")
            game.send(.chooseClub(candidate.club));game.send(.setPuttRange(candidate.range));game.send(.aim(candidate.direction))
            game.send(.beginCharge);game.send(.setPower(candidate.power));game.send(.release)
            for _ in 0..<3900 {
                game.advance(by:1.0/120)
                if game.state.phase == .aiming || game.state.phase == .complete { break }
            }
            XCTAssertEqual(game.state.ball.position.x,candidate.prediction.finalPosition.x,accuracy:1e-8)
            XCTAssertEqual(game.state.ball.position.y,candidate.prediction.finalPosition.y,accuracy:1e-8)
            XCTAssertNotEqual(game.state.lastOutcome,.timedOut)
            records.append(ShotRecord(club:candidate.club,aimDeltaDegrees:candidate.aimDeltaDegrees,aimX:candidate.direction.x,aimY:candidate.direction.y,power:candidate.power,puttRange:candidate.range,strokes:game.state.strokeCount))
        }
        XCTAssertEqual(game.state.phase,.complete,"\(hole.id) wind\(hole.wind.speedMPH), remaining \(game.state.ball.position.distance(to:hole.pin))m")
        XCTAssertEqual(game.state.penaltyCount,forceWater ? 1 : 0)
        XCTAssertEqual(game.state.result?.strokes,records.count + (forceWater ? 1 : 0))
        print("PLAYABLE \(hole.id) wind\(hole.wind.speedMPH) conservative=\(conservative) strokes=\(game.state.strokeCount) complete=\(game.state.phase == .complete)")
        return HoleRecord(holeID:hole.id,windMPH:hole.wind.speedMPH,conservative:conservative,shots:records,strokes:game.state.strokeCount,par:hole.par,penalties:game.state.penaltyCount)
    }
    private func bestShot(game: GameReducer, conservative: Bool) -> Candidate? {
        let hole = game.hole, position = game.state.ball.position, distance = position.distance(to:hole.pin)
        let putting = hole.terrain(at:position) == .green
        let target = putting || !conservative || distance < 90 ? hole.pin : routeTarget(hole:hole,position:position,ahead:125)
        let aim = (target-position).normalized
        let clubs: [GolfClubType] = putting ? [.putter] : [.driver,.fiveIron,.sevenIron,.pitchingWedge,.sandWedge]
        let range = PuttRange.recommended(distanceMeters:distance)
        var best: Candidate?
        var evaluated: Set<String> = []
        func evaluate(club: GolfClubType, angle: Double, power: Double) {
            guard power > 0, power <= 1, !(game.state.lie == .deepRough && club == .driver) else { return }
            let requested = Vector2(x:aim.x*cos(angle)-aim.y*sin(angle),y:aim.x*sin(angle)+aim.y*cos(angle))
            let originalAim=game.state.aimDirection
            let degrees=Int((atan2(originalAim.cross(requested),originalAim.dot(requested))*180 / .pi).rounded())
            let quantizedAngle=Double(degrees)*Double.pi/180
            let direction=Vector2(x:originalAim.x*cos(quantizedAngle)-originalAim.y*sin(quantizedAngle),y:originalAim.x*sin(quantizedAngle)+originalAim.y*cos(quantizedAngle))
            let quantizedPower=(power*100).rounded()/100
            guard quantizedPower > 0, evaluated.insert("\(club.rawValue):\(degrees):\(Int(quantizedPower*100))").inserted else { return }
            var preview = game
            preview.send(.chooseClub(club));preview.send(.setPuttRange(range));preview.send(.aim(direction))
            let prediction = ShotPredictor.predict(hole:hole,state:preview.state,power:quantizedPower)
            guard prediction.outcome == .settled else { return }
            let end = prediction.finalPosition
            let score: Double
            if prediction.captured { score = -1_000 }
            else if putting { score = end.distance(to:hole.pin) }
            else {
                score = end.distance(to:target) + (hole.terrain(at:end) == .water ? 1000 : 0) + (hole.terrain(at:end) == .deepRough ? 15 : 0) + (hole.terrain(at:end) == .bunker ? 8 : 0)
            }
            if best.map({score < $0.score}) ?? true { best = Candidate(club:club,direction:direction,aimDeltaDegrees:degrees,power:quantizedPower,range:range,prediction:prediction,score:score) }
        }
        if putting {
            let slope = hole.slope(at:position)
            let estimate = min(1,max(0.01,distance/range.meters*(1+SimulationConfig.gravity*slope.dot(aim)/0.45)))
            for angle in stride(from:-0.45,through:0.45,by:0.075) {
                for factor in [0.75,0.9,1.0,1.1,1.25] { evaluate(club:.putter,angle:angle,power:min(1,estimate*factor)) }
            }
        } else {
            for club in clubs {
                for angle in [-0.06,0,0.06] {
                    for power in stride(from:0.1,through:1.0,by:0.1) { evaluate(club:club,angle:angle,power:power) }
                }
            }
        }
        for precision in [0.035,0.01,0.003] {
            guard let current = best, current.score > -100 else { break }
            let angle = atan2(aim.cross(current.direction),aim.dot(current.direction))
            for offset in [-precision,0,precision] {
                for powerOffset in [-precision,0,precision] { evaluate(club:current.club,angle:angle+offset,power:current.power+powerOffset) }
            }
        }
        return best
    }
    private func routeTarget(hole: HoleDefinition, position: Vector2, ahead: Double) -> Vector2 {
        var nearestDistance = Double.infinity, progress = 0.0, traversed = 0.0
        for (a,b) in zip(hole.route,hole.route.dropFirst()) {
            let segment = b-a, length = segment.length
            let fraction = min(1,max(0,(position-a).dot(segment)/(length*length)))
            let projected = a+segment*fraction, distance = projected.distance(to:position)
            if distance < nearestDistance { nearestDistance=distance;progress=traversed+length*fraction }
            traversed += length
        }
        var targetProgress = min(traversed,progress+ahead)
        for (a,b) in zip(hole.route,hole.route.dropFirst()) {
            let length = a.distance(to:b)
            if targetProgress <= length { return a+(b-a)*(targetProgress/length) }
            targetProgress -= length
        }
        return hole.pin
    }
    private func export(_ records:[HoleRecord],name:String) throws {
        let directory = URL(fileURLWithPath:NSTemporaryDirectory()).appendingPathComponent("offsidegolf-full")
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys]
        try encoder.encode(records).write(to:directory.appendingPathComponent(name),options:.atomic)
        // A stable task artifact location is also used by the UI fixture consumer.
        let taskDirectory=URL(fileURLWithPath:"/tmp/offsidegolf-full")
        try FileManager.default.createDirectory(at:taskDirectory,withIntermediateDirectories:true)
        try encoder.encode(records).write(to:taskDirectory.appendingPathComponent(name),options:.atomic)
    }
}
