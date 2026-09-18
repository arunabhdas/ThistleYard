import Foundation
import OffsideGolfCore
import XCTest
@testable import OffsideGolf

@MainActor final class PlayerStoreReviewTests: XCTestCase {
    func testQueuePersistsLatestValuesWithoutOldCompletionsReplacingMemory() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let repository = FileGameRepository(directory: dir), store = PlayerStore(repository: FileGameRepository(directory: dir))
        await store.load()
        for value in 1...30 {
            var settings = store.settings
            settings.musicVolume = Double(value) / 100
            store.updateSettings(settings)
        }
        store.updateAppearance(GolferAppearance(skinPalette: 3,hairStyle: 2,outfitPalette: 1))
        await store.flush()
        XCTAssertFalse(store.saving)
        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(store.settings.musicVolume,0.3)
        guard case .current(let saved) = await repository.load() else { return XCTFail("Expected disk save") }
        XCTAssertEqual(saved.profile,store.save.profile)
        XCTAssertEqual(saved.revision,31)
        XCTAssertEqual(store.save.revision,31)
    }
    func testAcknowledgedBackupRecoveryCanRetryAfterRealIOFailure() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let repository = FileGameRepository(directory: dir)
        _ = try await repository.save(SaveGame())
        _ = try await repository.save(SaveGame())
        let current = dir.appendingPathComponent("save.json")
        try FileManager.default.removeItem(at: current)
        try FileManager.default.createDirectory(at: current,withIntermediateDirectories: false)
        let store = PlayerStore(repository: repository)
        await store.load()
        XCTAssertNotNil(store.recovery)
        store.recoverBackup()
        await store.flush()
        XCTAssertNotNil(store.errorMessage)
        try FileManager.default.removeItem(at: current)
        store.retrySave()
        await store.flush()
        XCTAssertNil(store.errorMessage)
        guard case .current = await repository.load() else { return XCTFail("Retry must write recovered data") }
    }
    func testPracticeRecordAndRoundRecordsStaySeparateAcrossPhysicsVersions() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = PlayerStore(repository: FileGameRepository(directory: directory))
        await store.load()
        let score = SavedHoleScore(holeID: "hole-1",strokes: 2,par: 3)
        store.recordPractice(score,courseID: "course",contentVersion: 1,physicsVersion: 2,eligible: true)
        store.recordPractice(SavedHoleScore(holeID: "hole-1",strokes: 1,par: 3),courseID: "course",contentVersion: 1,physicsVersion: 2,eligible: false)
        await store.flush()
        let practice = try XCTUnwrap(store.save.profile.records.first)
        XCTAssertEqual(practice.holeBestStrokes["hole-1"],2)
        XCTAssertNil(practice.bestTotalStrokes)
        store.finishRound([score],courseID: "course",contentVersion: 1,physicsVersion: 1,eligible: true)
        await store.flush()
        XCTAssertEqual(store.save.profile.records.count,2)
        XCTAssertNil(store.save.profile.records.first { $0.physicsVersion == 2 }?.bestTotalStrokes)
        XCTAssertEqual(store.save.profile.records.first { $0.physicsVersion == 1 }?.bestTotalStrokes,2)
    }

}
