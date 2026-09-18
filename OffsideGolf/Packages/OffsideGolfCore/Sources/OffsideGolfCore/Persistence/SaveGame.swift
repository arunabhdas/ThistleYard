import Foundation

public struct SavedHoleScore: Codable, Equatable, Sendable {
    public var holeID: String
    public var strokes: Int
    public var par: Int
    public init(holeID: String, strokes: Int, par: Int) {
        self.holeID = holeID; self.strokes = strokes; self.par = par
    }
}

/// Practice sessions never occupy this slot. The checkpoint owns the full shot ledger
/// and in-progress simulation so resuming cannot charge an already counted stroke.
public struct RoundProgress: Codable, Equatable, Sendable {
    public var id: UUID
    public var courseID: String
    public var contentVersion: Int
    public var currentHoleID: String
    public var completedHoles: [SavedHoleScore]
    public var checkpoint: GameCheckpoint
    public var assisted: Bool
    /// Retained while a shot is active; used only after explicit assisted-recovery acknowledgement.
    public var lastSettledCheckpoint: GameCheckpoint?
    public init(id: UUID = UUID(), courseID: String, contentVersion: Int, currentHoleID: String,
                completedHoles: [SavedHoleScore] = [], checkpoint: GameCheckpoint, assisted: Bool = false,
                lastSettledCheckpoint: GameCheckpoint? = nil) {
        self.id = id; self.courseID = courseID; self.contentVersion = contentVersion
        self.currentHoleID = currentHoleID; self.completedHoles = completedHoles
        self.checkpoint = checkpoint; self.assisted = assisted
        self.lastSettledCheckpoint = lastSettledCheckpoint
    }
}

public struct SaveGame: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1
    public var schemaVersion: Int
    public var revision: UInt64
    public var profile: PlayerProfile
    public var round: RoundProgress?
    public init(schemaVersion: Int = currentSchemaVersion, revision: UInt64 = 0,
                profile: PlayerProfile = PlayerProfile(), round: RoundProgress? = nil) {
        self.schemaVersion = schemaVersion; self.revision = revision; self.profile = profile; self.round = round
    }
}

public enum GameRepositoryError: Error, Equatable, Sendable, LocalizedError {
    case unsupportedSchema(found: Int, supported: Int)
    case corrupt(String)
    case io(String)
    case missingCurrent
    case recoveryAcknowledgementRequired
    case revisionExhausted

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema: "This save belongs to a different version of OffsideGolf. It has been kept unchanged."
        case .corrupt: "The save could not be read. Your files have been kept for recovery."
        case .io: "Progress could not be read or saved. Please try again."
        case .missingCurrent: "The current save is missing. A previous checkpoint is available."
        case .recoveryAcknowledgementRequired: "Recover the previous checkpoint before saving again."
        case .revisionExhausted: "This save cannot accept another revision."
        }
    }
}

public enum GameLoadResult: Equatable, Sendable {
    case current(SaveGame)
    case recoveredBackup(SaveGame, currentFailure: GameRepositoryError)
    case absent
    case failure(current: GameRepositoryError, backup: GameRepositoryError?)
}

public enum SaveGameCodec {
    public static let maximumEncodedBytes = 8_000_000
    public static func encode(_ save: SaveGame) throws -> Data {
        try validate(save)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            let data = try encoder.encode(save)
            guard data.count <= maximumEncodedBytes else { throw GameRepositoryError.corrupt("Save exceeds size limit") }
            return data
        }
        catch { throw GameRepositoryError.corrupt(error.localizedDescription) }
    }

    public static func decode(_ data: Data) throws -> SaveGame {
        do {
            guard data.count <= maximumEncodedBytes else { throw GameRepositoryError.corrupt("Save exceeds size limit") }
            // Read the version before requiring any fields from a newer schema.
            let header = try JSONDecoder().decode(Header.self, from: data)
            guard header.schemaVersion == SaveGame.currentSchemaVersion else {
                throw GameRepositoryError.unsupportedSchema(found: header.schemaVersion, supported: SaveGame.currentSchemaVersion)
            }
            let save = try JSONDecoder().decode(SaveGame.self, from: data)
            try validate(save)
            return save
        } catch let error as GameRepositoryError { throw error }
        catch { throw GameRepositoryError.corrupt(error.localizedDescription) }
    }

    public static func validate(_ save: SaveGame) throws {
        guard save.schemaVersion == SaveGame.currentSchemaVersion else {
            throw GameRepositoryError.unsupportedSchema(found: save.schemaVersion, supported: SaveGame.currentSchemaVersion)
        }
        let settings = save.profile.settings, appearance = save.profile.appearance
        guard [settings.musicVolume, settings.ambientVolume, settings.effectsVolume, settings.interfaceVolume]
            .allSatisfy({ $0.isFinite && (0...1).contains($0) }),
              (0..<4).contains(appearance.skinPalette), (0..<3).contains(appearance.hairStyle),
              (0..<4).contains(appearance.outfitPalette) else { throw GameRepositoryError.corrupt("Invalid profile settings") }
        guard save.profile.records.count <= 100,
              Set(save.profile.records.map { RecordKey(courseID: $0.courseID, contentVersion: $0.contentVersion,
                                                       physicsVersion: $0.physicsVersion) }).count == save.profile.records.count else {
            throw GameRepositoryError.corrupt("Invalid course records")
        }
        for record in save.profile.records {
            guard hasText(record.courseID), record.contentVersion > 0, record.physicsVersion > 0,
                  record.bestTotalStrokes.map({ (1...9_000).contains($0) }) ?? true,
                  record.holeBestStrokes.count <= 100,
                  record.holeBestStrokes.allSatisfy({ hasText($0.key) && (1...1_000).contains($0.value) }) else {
                throw GameRepositoryError.corrupt("Invalid personal best")
            }
        }
        if let round = save.round {
            if round.checkpoint.schemaVersion != 1 {
                throw GameRepositoryError.unsupportedSchema(found: round.checkpoint.schemaVersion, supported: 1)
            }
            guard hasText(round.courseID), hasText(round.currentHoleID), round.contentVersion > 0,
                  round.checkpoint.holeID == round.currentHoleID, round.checkpoint.contentVersion == round.contentVersion,
                  round.checkpoint.physicsVersion > 0, round.checkpoint.schemaVersion > 0,
                  !round.checkpoint.snapshot.isEmpty, round.checkpoint.snapshot.count <= 4_000_000,
                  round.completedHoles.count <= 9,
                  Set(round.completedHoles.map(\.holeID)).count == round.completedHoles.count,
                  round.completedHoles.allSatisfy({ hasText($0.holeID) && (1...1_000).contains($0.strokes) && (3...5).contains($0.par) }) else {
                throw GameRepositoryError.corrupt("Invalid round progress")
            }
            if let settled = round.lastSettledCheckpoint {
                if settled.schemaVersion != 1 {
                    throw GameRepositoryError.unsupportedSchema(found: settled.schemaVersion, supported: 1)
                }
                guard settled.holeID == round.currentHoleID, settled.contentVersion == round.contentVersion else {
                    throw GameRepositoryError.corrupt("Recovery checkpoint does not match the current hole")
                }
                do { try settled.validate() }
                catch { throw GameRepositoryError.corrupt("Invalid settled recovery checkpoint") }
            }
        }
    }

    private static func hasText(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.count <= 256
    }
    private struct Header: Decodable { let schemaVersion: Int }
    private struct RecordKey: Hashable {
        let courseID: String
        let contentVersion: Int
        let physicsVersion: Int
    }
}
