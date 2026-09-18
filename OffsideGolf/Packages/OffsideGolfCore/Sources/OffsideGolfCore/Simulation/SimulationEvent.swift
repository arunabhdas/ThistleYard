import Foundation

public struct SimulationEvent: Codable, Equatable, Sendable, Identifiable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        case impact, bounce, sand, splash, cupCapture, settled, penalty, tree
    }
    public let id: Int
    public let shotID: Int
    public let kind: Kind
    public let position: Vector2
    public let material: TerrainMaterial
}
