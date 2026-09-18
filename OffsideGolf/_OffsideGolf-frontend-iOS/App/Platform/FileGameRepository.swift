import Foundation
import OffsideGolfCore

/// One actor owns writes to the profile and resumable round. I/O never touches UI state.
actor FileGameRepository {
    private let directory: URL
    private var currentURL: URL { directory.appendingPathComponent("save.json") }
    private var backupURL: URL { directory.appendingPathComponent("save.backup.json") }

    init(directory: URL? = nil) {
        self.directory = directory ?? URL.applicationSupportDirectory.appendingPathComponent("OffsideGolf", isDirectory: true)
    }

    func load() -> GameLoadResult {
        let current = read(currentURL)
        switch current {
        case .success(let save): return .current(save)
        case .failure(.unsupportedSchema(let found, let supported)):
            return .failure(current: .unsupportedSchema(found: found, supported: supported), backup: nil)
        default: break
        }
        let backup = read(backupURL)
        switch (current, backup) {
        case (.missing, .missing): return .absent
        case (_, .success(let save)): return .recoveredBackup(save, currentFailure: current.error ?? .missingCurrent)
        case (_, .failure(let backupError)):
            return .failure(current: current.error ?? .missingCurrent, backup: backupError)
        case (.failure(let error), .missing): return .failure(current: error, backup: nil)
        default: return .absent
        }
    }

    /// Returned revision is authoritative. A failed call must remain visible to the caller.
    /// Recovery is explicit; newer schemas are protected even with acknowledgement.
    func save(_ proposed: SaveGame, replacingCorruptCurrent: Bool = false) throws -> SaveGame {
        try SaveGameCodec.validate(proposed)
        var existingRevision: UInt64 = 0
        var lastGoodData: Data?
        switch load() {
        case .current(let existing):
            existingRevision = existing.revision
            lastGoodData = try SaveGameCodec.encode(existing)
            if case .failure(.unsupportedSchema(let found, let supported)) = read(backupURL) {
                throw GameRepositoryError.unsupportedSchema(found: found, supported: supported)
            }
        case .recoveredBackup(let existing, let failure):
            if case .io = failure { throw failure }
            guard replacingCorruptCurrent else { throw GameRepositoryError.recoveryAcknowledgementRequired }
            existingRevision = existing.revision
        case .failure(let current, let backup):
            if case .unsupportedSchema = current { throw current }
            if let backup, case .unsupportedSchema = backup { throw backup }
            if case .io = current { throw current }
            if let backup, case .io = backup { throw backup }
            guard replacingCorruptCurrent else { throw GameRepositoryError.recoveryAcknowledgementRequired }
        case .absent: break
        }
        let baseRevision = max(existingRevision, proposed.revision)
        guard baseRevision < UInt64.max else { throw GameRepositoryError.revisionExhausted }
        var saved = proposed
        saved.revision = baseRevision + 1
        let data = try SaveGameCodec.encode(saved)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            // Rotate only validated current bytes; a corrupt current never destroys its backup.
            if let lastGoodData { try lastGoodData.write(to: backupURL, options: .atomic) }
            try data.write(to: currentURL, options: .atomic)
        } catch { throw GameRepositoryError.io(error.localizedDescription) }
        return saved
    }

    private enum ReadResult {
        case success(SaveGame), missing, failure(GameRepositoryError)
        var error: GameRepositoryError? { if case .failure(let error) = self { error } else { nil } }
    }

    private func read(_ url: URL) -> ReadResult {
        do {
            let data = try Data(contentsOf: url)
            do { return .success(try SaveGameCodec.decode(data)) }
            catch let error as GameRepositoryError { return .failure(error) }
            catch { return .failure(.corrupt(error.localizedDescription)) }
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            return .missing
        } catch { return .failure(.io(error.localizedDescription)) }
    }
}
