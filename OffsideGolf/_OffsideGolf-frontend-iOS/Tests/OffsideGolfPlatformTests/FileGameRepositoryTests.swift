import Foundation
import XCTest
import OffsideGolfCore
@testable import OffsideGolf

final class FileGameRepositoryTests: XCTestCase, @unchecked Sendable {
    private func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("OffsideGolfRepository-\(UUID())")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }

    func testRealFilesRoundTripAndAdvanceRevision() async throws {
        let url = try directory(), repository = FileGameRepository(directory: url)
        let empty = await repository.load()
        XCTAssertEqual(empty, .absent)
        var save = SaveGame()
        save.profile.settings.highContrast = true
        let first = try await repository.save(save)
        let second = try await repository.save(save)
        XCTAssertEqual(first.revision, 1)
        XCTAssertEqual(second.revision, 2)
        let loaded = await FileGameRepository(directory: url).load()
        XCTAssertEqual(loaded, .current(second))
    }

    func testCorruptCurrentRecoversLastGoodBackupAndRequiresExplicitOverwrite() async throws {
        let url = try directory(), repository = FileGameRepository(directory: url)
        let first = try await repository.save(SaveGame())
        var changed = first
        changed.profile.settings.leftHanded = true
        _ = try await repository.save(changed)
        try Data("broken".utf8).write(to: url.appendingPathComponent("save.json"))
        let loaded = await repository.load()
        guard case .recoveredBackup(let recovered, _) = loaded else { return XCTFail("Expected backup") }
        XCTAssertEqual(recovered, first)
        do { _ = try await repository.save(recovered); XCTFail("Needs acknowledgement") } catch { }
        let repaired = try await repository.save(recovered, replacingCorruptCurrent: true)
        XCTAssertEqual(repaired.revision, 2)
        XCTAssertEqual(try SaveGameCodec.decode(Data(contentsOf: url.appendingPathComponent("save.backup.json"))), first)
    }

    func testFutureSchemaNeverFallsBackOrGetsOverwritten() async throws {
        let url = try directory(), repository = FileGameRepository(directory: url)
        _ = try await repository.save(SaveGame())
        _ = try await repository.save(SaveGame())
        let future = Data(#"{"schemaVersion":999}"#.utf8)
        try future.write(to: url.appendingPathComponent("save.json"))
        let result = await repository.load()
        guard case .failure(let failure, _) = result else { return XCTFail("Future save must be read-only") }
        XCTAssertEqual(failure, .unsupportedSchema(found: 999, supported: 1))
        do { _ = try await repository.save(SaveGame(), replacingCorruptCurrent: true); XCTFail("Must refuse future save") } catch { }
        XCTAssertEqual(try Data(contentsOf: url.appendingPathComponent("save.json")), future)
    }

    func testCorruptionOfBothFilesIsVisible() async throws {
        let url = try directory()
        for name in ["save.json", "save.backup.json"] { try Data("bad".utf8).write(to: url.appendingPathComponent(name)) }
        let result = await FileGameRepository(directory: url).load()
        guard case .failure(_, let backup) = result else { return XCTFail("Must not reset") }
        XCTAssertNotNil(backup)
    }

    func testMissingCurrentRecoversBackup() async throws {
        let url = try directory(), repository = FileGameRepository(directory: url)
        let first = try await repository.save(SaveGame())
        _ = try await repository.save(SaveGame())
        try FileManager.default.removeItem(at: url.appendingPathComponent("save.json"))
        let result = await repository.load()
        guard case .recoveredBackup(let save, _) = result else { return XCTFail("Expected backup") }
        XCTAssertEqual(save, first)
    }

    func testWriteFailureIsThrownAndDoesNotPretendToSave() async throws {
        let url = try directory().appendingPathComponent("not-a-directory")
        try Data("block".utf8).write(to: url)
        let repository = FileGameRepository(directory: url)
        do { _ = try await repository.save(SaveGame()); XCTFail("Expected I/O failure") }
        catch { guard case .io = error as? GameRepositoryError else { return XCTFail("Expected I/O error, got \(error)") } }
        XCTAssertEqual(try Data(contentsOf: url), Data("block".utf8))
    }

    func testInvalidCandidateAndBackupWriteFailurePreserveCurrent() async throws {
        let url = try directory(), repository = FileGameRepository(directory: url)
        let saved = try await repository.save(SaveGame())
        var invalid = saved
        invalid.profile.settings.ambientVolume = -1
        do { _ = try await repository.save(invalid); XCTFail("Must reject invalid candidate") } catch { }
        XCTAssertEqual(try SaveGameCodec.decode(Data(contentsOf: url.appendingPathComponent("save.json"))), saved)
        // A directory at the backup file location forces a real atomic-write failure.
        try FileManager.default.createDirectory(at: url.appendingPathComponent("save.backup.json"), withIntermediateDirectories: false)
        do { _ = try await repository.save(saved); XCTFail("Must report backup write failure") } catch { }
        let result = await repository.load()
        XCTAssertEqual(result, .current(saved))
    }

    func testRevisionOverflowCannotOverwriteCurrent() async throws {
        let url = try directory(), repository = FileGameRepository(directory: url)
        let saved = try await repository.save(SaveGame())
        var exhausted = saved
        exhausted.revision = UInt64.max
        do { _ = try await repository.save(exhausted); XCTFail("Must reject overflow") }
        catch { XCTAssertEqual(error as? GameRepositoryError, .revisionExhausted) }
        let result = await repository.load()
        XCTAssertEqual(result, .current(saved))
    }

    func testFutureBackupIsAlsoProtectedFromRotation() async throws {
        let url = try directory(), repository = FileGameRepository(directory: url)
        let saved = try await repository.save(SaveGame())
        let future = Data(#"{"schemaVersion":999}"#.utf8)
        try future.write(to: url.appendingPathComponent("save.backup.json"))
        do { _ = try await repository.save(saved); XCTFail("Must protect newer backup") }
        catch { XCTAssertEqual(error as? GameRepositoryError, .unsupportedSchema(found: 999, supported: 1)) }
        XCTAssertEqual(try Data(contentsOf: url.appendingPathComponent("save.backup.json")), future)
    }

    func testInFlightRoundResumesFromDiskWithoutAnotherStroke() async throws {
        let hole = try HoleDefinition.decode(Data(#"{"schemaVersion":1,"id":"hole-1","par":3,"bounds":{"width":100,"height":190},"tee":{"x":50,"y":20},"pin":{"x":50,"y":164.4752},"green":{"center":{"x":50,"y":164.4752},"radiusX":13,"radiusY":11},"fairway":[{"x":30,"y":10},{"x":70,"y":10},{"x":70,"y":180},{"x":30,"y":180}]}"#.utf8))
        var original = GameReducer(hole: hole)
        let settled = original.checkpoint()
        original.send(.beginCharge); original.send(.setPower(0.5)); original.send(.release)
        for _ in 0..<100 { original.advance(by: 1.0 / 120) }
        XCTAssertEqual(original.state.strokeCount, 1)
        XCTAssertEqual(original.state.phase, .inFlight)
        let round = RoundProgress(courseID: "course", contentVersion: 1, currentHoleID: hole.id,
                                  checkpoint: original.checkpoint(), lastSettledCheckpoint: settled)
        let url = try directory()
        _ = try await FileGameRepository(directory: url).save(SaveGame(round: round))
        let load = await FileGameRepository(directory: url).load()
        guard case .current(let saved) = load, let progress = saved.round else { return XCTFail("Expected persisted round") }
        XCTAssertEqual(progress.lastSettledCheckpoint, settled)
        var resumed = try GameReducer(hole: hole, checkpoint: progress.checkpoint)
        XCTAssertEqual(resumed.state, original.state)
        for _ in 0..<4_000 { original.advance(by: 1.0 / 120); resumed.advance(by: 1.0 / 120) }
        XCTAssertEqual(resumed.state, original.state)
        XCTAssertEqual(resumed.state.strokeCount, 1)
    }
}
