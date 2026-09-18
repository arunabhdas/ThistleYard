import Foundation
import XCTest
@testable import OffsideGolfCore

final class SaveGameTests: XCTestCase {
    func testLegacyCourseRecordsDefaultToOriginalContentAndPhysicsVersions() throws {
        let record = try JSONDecoder().decode(CourseRecord.self, from: Data(#"{"courseID":"coast","bestTotalStrokes":35,"holeBestStrokes":{"one":3}}"#.utf8))
        XCTAssertEqual(record.contentVersion, 1)
        XCTAssertEqual(record.physicsVersion, 1)
        XCTAssertTrue(record.matches(courseID: "coast", contentVersion: 1, physicsVersion: 1))
        XCTAssertFalse(record.matches(courseID: "coast", contentVersion: 1, physicsVersion: 2))
    }

    func testCourseRecordsRemainSeparateAcrossContentAndPhysicsVersions() throws {
        let records = [
            CourseRecord(courseID: "coast", bestTotalStrokes: 35, contentVersion: 1, physicsVersion: 1),
            CourseRecord(courseID: "coast", bestTotalStrokes: 32, contentVersion: 1, physicsVersion: 2),
            CourseRecord(courseID: "coast", bestTotalStrokes: 38, contentVersion: 2, physicsVersion: 2)
        ]
        let save = SaveGame(profile: PlayerProfile(records: records))
        let restored = try SaveGameCodec.decode(SaveGameCodec.encode(save))
        XCTAssertEqual(restored.profile.records, records)
        XCTAssertEqual(restored.profile.records.first { $0.matches(courseID: "coast", contentVersion: 1, physicsVersion: 2) }?.bestTotalStrokes, 32)
    }

    func testDuplicateVersionedRecordAndInvalidVersionsAreRejected() {
        let record = CourseRecord(courseID: "coast", contentVersion: 1, physicsVersion: 2)
        XCTAssertThrowsError(try SaveGameCodec.encode(SaveGame(profile: PlayerProfile(records: [record, record]))))
        for invalid in [CourseRecord(courseID: "coast", contentVersion: 0, physicsVersion: 2),
                        CourseRecord(courseID: "coast", contentVersion: 1, physicsVersion: -1)] {
            XCTAssertThrowsError(try SaveGameCodec.encode(SaveGame(profile: PlayerProfile(records: [invalid]))))
        }
    }

    func testSettingsAndAppearanceSurviveVersionedRoundTrip() throws {
        var profile = PlayerProfile()
        profile.settings.musicVolume = 0.25
        profile.settings.leftHanded = true
        profile.settings.preciseControls = true
        profile.settings.reducedMotion = true
        profile.appearance.hairStyle = 2
        profile.appearance.skinPalette = 3
        profile.tutorialCompleted = true
        let save = SaveGame(profile: profile)
        let restored = try SaveGameCodec.decode(SaveGameCodec.encode(save))
        XCTAssertEqual(restored.profile, profile)
        XCTAssertNil(restored.round)
    }

    func testFutureSchemaIsDistinguishedFromCorruptionBeforePayloadDecode() {
        XCTAssertThrowsError(try SaveGameCodec.decode(Data(#"{"schemaVersion":999}"#.utf8))) {
            XCTAssertEqual($0 as? GameRepositoryError, .unsupportedSchema(found: 999, supported: 1))
        }
        XCTAssertThrowsError(try SaveGameCodec.decode(Data("broken".utf8))) {
            guard case .corrupt = $0 as? GameRepositoryError else { return XCTFail("Must identify corruption") }
        }
    }

    func testInvalidSettingsAndRecordsCannotBeWritten() {
        var save = SaveGame()
        save.profile.settings.effectsVolume = 2
        XCTAssertThrowsError(try SaveGameCodec.encode(save))
        save.profile.settings.effectsVolume = 0.5
        save.profile.appearance.hairStyle = 99
        XCTAssertThrowsError(try SaveGameCodec.encode(save))
        save.profile.appearance.hairStyle = 0
        save.profile.records = [CourseRecord(courseID: "course", bestTotalStrokes: -1)]
        XCTAssertThrowsError(try SaveGameCodec.encode(save))
    }

    func testInvalidDecodedValuesAreRejected() throws {
        let valid = try SaveGameCodec.encode(SaveGame())
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: valid) as? [String: Any])
        var profile = try XCTUnwrap(json["profile"] as? [String: Any])
        var settings = try XCTUnwrap(profile["settings"] as? [String: Any])
        settings["musicVolume"] = -0.1
        profile["settings"] = settings; json["profile"] = profile
        XCTAssertThrowsError(try SaveGameCodec.decode(JSONSerialization.data(withJSONObject: json)))
    }

    func testRoundPreservesScoresAndSettledRecoveryCheckpoint() throws {
        let checkpoint = GameCheckpoint(schemaVersion: 1, physicsVersion: 1, contentVersion: 1,
                                        holeID: "hole-2", snapshot: Data("snapshot".utf8))
        let round = RoundProgress(courseID: "course", contentVersion: 1, currentHoleID: "hole-2",
                                  completedHoles: [SavedHoleScore(holeID: "hole-1", strokes: 4, par: 3)],
                                  checkpoint: checkpoint, assisted: true, lastSettledCheckpoint: checkpoint)
        let restored = try SaveGameCodec.decode(SaveGameCodec.encode(SaveGame(round: round)))
        XCTAssertEqual(restored.round, round)
        var wrongHole = round
        wrongHole.currentHoleID = "hole-3"
        XCTAssertThrowsError(try SaveGameCodec.encode(SaveGame(round: wrongHole)))
        var duplicateScores = round
        duplicateScores.completedHoles.append(round.completedHoles[0])
        XCTAssertThrowsError(try SaveGameCodec.encode(SaveGame(round: duplicateScores)))
    }

    func testCombinedCheckpointPayloadCannotCreateAnUnreadableOversizeSave() {
        let checkpoint = GameCheckpoint(schemaVersion: 1, physicsVersion: 1, contentVersion: 1,
                                        holeID: "hole-1", snapshot: Data(repeating: 1, count: 3_200_000))
        let round = RoundProgress(courseID: "course", contentVersion: 1, currentHoleID: "hole-1",
                                  checkpoint: checkpoint, lastSettledCheckpoint: checkpoint)
        XCTAssertThrowsError(try SaveGameCodec.encode(SaveGame(round: round)))
    }
}
