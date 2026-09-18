import Foundation

public struct GameCheckpoint: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let physicsVersion: Int
    public let contentVersion: Int
    public let holeID: String
    public let snapshot: Data
    public func validate() throws {
        guard schemaVersion == 1, physicsVersion > 0, contentVersion > 0,
              !holeID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !snapshot.isEmpty, snapshot.count <= 4_000_000 else { throw GameCheckpointError.invalidSnapshot }
    }
}
public enum GameCheckpointError: Error { case incompatibleVersion, wrongHole, invalidSnapshot }
