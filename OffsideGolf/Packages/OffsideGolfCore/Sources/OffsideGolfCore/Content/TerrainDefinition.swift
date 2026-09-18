import Foundation

public enum TerrainMaterial: String, Codable, CaseIterable, Sendable {
    case tee, fairway, rough, deepRough, green, bunker, water, outOfBounds
    public var rollingDeceleration: Double {
        switch self {
        case .tee: 1.25
        case .fairway: 1.1
        case .rough: 2.5
        case .deepRough: 4.5
        case .green: 0.45
        case .bunker: 6
        case .water, .outOfBounds: 0
        }
    }
    public var restitution: Double { switch self { case .green: 0.22; case .bunker: 0.03; case .rough: 0.16; case .deepRough: 0.08; default: 0.3 } }
    public var retention: Double { switch self { case .green: 0.82; case .bunker: 0.38; case .rough: 0.58; case .deepRough: 0.42; default: 0.78 } }
    public var launchFactor: Double { switch self { case .rough: 0.88; case .deepRough: 0.72; case .bunker: 0.6; default: 1 } }
    public var precedence: Int { switch self { case .outOfBounds: 8; case .water: 7; case .bunker: 6; case .green: 5; case .tee: 4; case .fairway: 3; case .deepRough: 2; case .rough: 1 } }
    public var displayName: String { switch self { case .deepRough: "Deep rough"; case .outOfBounds: "Out of bounds"; default: rawValue.capitalized } }
}

public struct TerrainRegion: Codable, Equatable, Sendable {
    public let id: String
    public let terrain: TerrainMaterial
    public let priority: Int
    public let polygon: [Vector2]
    public init(id: String, terrain: TerrainMaterial, priority: Int = 0, polygon: [Vector2]) {
        self.id = id; self.terrain = terrain; self.priority = priority; self.polygon = polygon
    }
    public func contains(_ point: Vector2) -> Bool { Polygon.contains(point, vertices: polygon) }
}
public struct ElevationDefinition: Codable, Equatable, Sendable {
    public let origin: Vector2
    public let baseHeight: Double
    public let gradient: Vector2
    public init(origin: Vector2 = .zero, baseHeight: Double = 0, gradient: Vector2 = .zero) {
        self.origin = origin; self.baseHeight = baseHeight; self.gradient = gradient
    }
}
public struct TreeDefinition: Codable, Equatable, Sendable {
    public let id: String
    public let position: Vector2
    public let trunkRadius: Double
    public let trunkHeight: Double
    public let canopyRadius: Double
    public let canopyBottom: Double
    public let canopyTop: Double
}
public struct DropDefinition: Codable, Equatable, Sendable {
    public let id: String
    public let position: Vector2
    public let hazardID: String?
}
public struct DecorationDefinition: Codable, Equatable, Sendable {
    public let asset: String
    public let position: Vector2
    public let scale: Double
}

enum Polygon {
    static func contains(_ point: Vector2, vertices: [Vector2]) -> Bool {
        guard vertices.count >= 3 else { return false }
        var inside = false
        for i in vertices.indices {
            let a = vertices[i], b = vertices[(i + 1) % vertices.count], edge = b - a, offset = point - a
            if abs(edge.cross(offset)) < 1e-9 && offset.dot(edge) >= 0 && offset.dot(edge) <= edge.dot(edge) { return true }
            if (a.y > point.y) != (b.y > point.y), point.x < (b.x - a.x) * (point.y - a.y) / (b.y - a.y) + a.x { inside.toggle() }
        }
        return inside
    }
    static func crossings(from start: Vector2, to end: Vector2, vertices: [Vector2]) -> [Double] {
        let direction = end - start
        var values: [Double] = contains(start, vertices: vertices) ? [0] : []
        for i in vertices.indices {
            let a = vertices[i], edge = vertices[(i + 1) % vertices.count] - a
            let denominator = direction.cross(edge)
            guard abs(denominator) > 1e-12 else { continue }
            let offset = a - start, t = offset.cross(edge) / denominator, u = offset.cross(direction) / denominator
            if (0...1).contains(t), (0...1).contains(u) { values.append(t) }
        }
        return values.sorted()
    }
}

/// Smooth Gaussian rise/depression; radius is one standard deviation in metres.
public struct ElevationPatch: Codable, Equatable, Sendable {
    public let center: Vector2
    public let radius: Double
    public let height: Double
}
