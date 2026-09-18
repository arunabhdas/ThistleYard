import Foundation

public struct CourseBounds: Codable, Sendable {
    public let width: Double
    public let height: Double
    public init(width: Double, height: Double) { self.width = width; self.height = height }
    public func contains(_ point: Vector2) -> Bool {
        point.isFinite && (0...width).contains(point.x) && (0...height).contains(point.y)
    }
}

public struct GreenDefinition: Codable, Sendable {
    public let center: Vector2
    public let radiusX: Double
    public let radiusY: Double
    public init(center: Vector2, radiusX: Double, radiusY: Double) {
        self.center = center; self.radiusX = radiusX; self.radiusY = radiusY
    }
    public func contains(_ point: Vector2) -> Bool {
        guard point.isFinite, radiusX > 0, radiusY > 0 else { return false }
        let x = (point.x - center.x) / radiusX, y = (point.y - center.y) / radiusY
        return x * x + y * y <= 1
    }
}

/// Validated, metre-based M1 geometry. Construction only occurs through decoding.
public struct HoleDefinition: Sendable {
    public let id: String
    public let par: Int
    public let bounds: CourseBounds
    public let tee: Vector2
    public let pin: Vector2
    public let green: GreenDefinition
    public let fairway: [Vector2]
    public let physicsVersion: Int
    public let contentVersion: Int
    public let safeTarget: Vector2
    public let wind: WindCondition
    public let regions: [TerrainRegion]
    public let elevation: ElevationDefinition
    public let greenSlope: Vector2
    public let trees: [TreeDefinition]
    public let drops: [DropDefinition]
    public let decorations: [DecorationDefinition]
    public let route: [Vector2]
    public let elevationPatches: [ElevationPatch]


    public static func decode(_ data: Data) throws -> Self {
        let doc = try JSONDecoder().decode(Document.self, from: data)
        guard doc.schemaVersion == 1 else { throw HoleDefinitionError.unsupportedSchema }
        guard !doc.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              (3...5).contains(doc.par) else { throw HoleDefinitionError.invalidMetadata }
        let b = doc.bounds, g = doc.green
        guard b.width.isFinite, b.height.isFinite,
              (10...2_000).contains(b.width), (10...2_000).contains(b.height),
              b.contains(doc.tee), b.contains(doc.pin),
              doc.tee.distance(to: doc.pin) >= 1,
              g.center.isFinite, g.radiusX.isFinite, g.radiusY.isFinite,
              (1...100).contains(g.radiusX), (1...100).contains(g.radiusY),
              g.center.x - g.radiusX >= 0.5, g.center.y - g.radiusY >= 0.5,
              g.center.x + g.radiusX <= b.width - 0.5,
              g.center.y + g.radiusY <= b.height - 0.5,
              g.contains(doc.pin),
              doc.tee.x >= 0.5, doc.tee.y >= 0.5,
              doc.tee.x <= b.width - 0.5, doc.tee.y <= b.height - 0.5,
              doc.pin.x >= 0.5, doc.pin.y >= 0.5,
              doc.pin.x <= b.width - 0.5, doc.pin.y <= b.height - 0.5,
              validPolygon(doc.fairway, bounds: b) else { throw HoleDefinitionError.invalidGeometry }
        let hole = Self(id: doc.id, par: doc.par, bounds: b, tee: doc.tee, pin: doc.pin, green: g, fairway: doc.fairway,
                        physicsVersion: doc.physicsVersion ?? 1, contentVersion: doc.contentVersion ?? 1,
                        safeTarget: doc.safeTarget ?? doc.pin, wind: doc.wind ?? .calm, regions: doc.regions ?? [],
                        elevation: doc.elevation ?? ElevationDefinition(), greenSlope: doc.greenSlope ?? .zero,
                        trees: doc.trees ?? [], drops: doc.drops ?? [], decorations: doc.decorations ?? [], route: doc.route ?? [doc.tee, doc.pin], elevationPatches: doc.elevationPatches ?? [])
        try hole.validateExtended()
        return hole
    }

    static func validPolygon(_ points: [Vector2], bounds: CourseBounds) -> Bool {
        guard (3...256).contains(points.count), points.allSatisfy(bounds.contains),
              Set(points).count == points.count else { return false }
        var area = 0.0
        for i in points.indices {
            let a = points[i], b = points[(i + 1) % points.count]
            guard a.distance(to: b) >= 0.01 else { return false }
            area += a.cross(b)
            for j in points.indices where j > i + 1 && !(i == 0 && j == points.count - 1) {
                let c = points[j], d = points[(j + 1) % points.count]
                let ab = b - a, cd = d - c
                let cSide = ab.cross(c - a), dSide = ab.cross(d - a)
                let aSide = cd.cross(a - c), bSide = cd.cross(b - c)
                if cSide * dSide <= 0 && aSide * bSide <= 0,
                   max(min(a.x, b.x), min(c.x, d.x)) <= min(max(a.x, b.x), max(c.x, d.x)),
                   max(min(a.y, b.y), min(c.y, d.y)) <= min(max(a.y, b.y), max(c.y, d.y)) { return false }
            }
        }
        return abs(area) >= 2
    }

    public func terrain(at point: Vector2) -> TerrainMaterial {
        if !bounds.contains(point) { return .outOfBounds }
        var candidates: [(TerrainMaterial, Int, String)] = []
        if green.contains(point) { candidates.append((.green, 0, "base-green")) }
        if point.distance(to: tee) <= 3 { candidates.append((.tee, 0, "base-tee")) }
        if Polygon.contains(point, vertices: fairway) { candidates.append((.fairway, 0, "base-fairway")) }
        candidates += regions.filter { $0.contains(point) }.map { ($0.terrain, $0.priority, $0.id) }
        return candidates.sorted {
            if $0.0.precedence != $1.0.precedence { return $0.0.precedence > $1.0.precedence }
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            return $0.2 < $1.2
        }.first?.0 ?? (physicsVersion == 1 ? .fairway : .rough)
    }
    public func elevation(at point: Vector2) -> Double {
        func baseHeight(_ point: Vector2) -> Double {
            elevation.baseHeight + (point - elevation.origin).dot(elevation.gradient) + elevationPatches.reduce(0) {
                let delta = point - $1.center
                return $0 + $1.height * exp(-delta.dot(delta) / (2 * $1.radius * $1.radius))
            }
        }
        let base = baseHeight(point)
        let delta = point - green.center
        let radius = hypot(delta.x / green.radiusX, delta.y / green.radiusY)
        let t = min(1, max(0, (1 - radius) / 0.2))
        let blend = t * t * (3 - 2 * t)
        return base + (baseHeight(green.center) + delta.dot(greenSlope) - base) * blend
    }
    public func slope(at point: Vector2) -> Vector2 {
        let epsilon = 0.001
        return Vector2(x: (elevation(at: point + Vector2(x: epsilon,y: 0)) - elevation(at: point - Vector2(x: epsilon,y: 0))) / (2 * epsilon),
                       y: (elevation(at: point + Vector2(x: 0,y: epsilon)) - elevation(at: point - Vector2(x: 0,y: epsilon))) / (2 * epsilon))
    }
    private func validateExtended() throws {
        guard (1...2).contains(physicsVersion), contentVersion > 0, bounds.contains(safeTarget),
              wind.speedMPH.isFinite, (0...60).contains(wind.speedMPH), wind.towardDegrees.isFinite,
              elevation.origin.isFinite, elevation.baseHeight.isFinite, abs(elevation.baseHeight) <= 100,
              elevation.gradient.isFinite, elevation.gradient.length <= 0.2,
              greenSlope.isFinite, greenSlope.length <= 0.02,
              (2...128).contains(route.count), route.allSatisfy(bounds.contains),
              route.first == tee, route.last == pin,
              elevationPatches.count <= 32, regions.count <= 128, trees.count <= 256, drops.count <= 64, decorations.count <= 256,
              Set(regions.map(\.id)).count == regions.count, Set(trees.map(\.id)).count == trees.count,
              Set(drops.map(\.id)).count == drops.count else { throw HoleDefinitionError.invalidGeometry }
        for patch in elevationPatches {
            guard bounds.contains(patch.center), patch.radius.isFinite, (1...1000).contains(patch.radius),
                  patch.height.isFinite, abs(patch.height) <= 20, abs(patch.height) / patch.radius <= 0.2 else { throw HoleDefinitionError.invalidGeometry }
        }
        for region in regions {
            guard !region.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  (0...100).contains(region.priority), Self.validPolygon(region.polygon, bounds: bounds),
                  region.terrain != .outOfBounds else { throw HoleDefinitionError.invalidGeometry }
        }
        for tree in trees {
            guard !tree.id.isEmpty, bounds.contains(tree.position),
                  tree.trunkRadius.isFinite, (0.1...3).contains(tree.trunkRadius),
                  tree.trunkHeight.isFinite, (1...25).contains(tree.trunkHeight),
                  tree.canopyRadius.isFinite, (0.5...15).contains(tree.canopyRadius),
                  tree.canopyBottom.isFinite, tree.canopyTop.isFinite,
                  tree.canopyBottom >= 0.5, tree.canopyTop > tree.canopyBottom, tree.canopyTop <= 40,
                  tree.position.distance(to: tee) > tree.trunkRadius + 1,
                  tree.position.distance(to: pin) > tree.trunkRadius + 1 else { throw HoleDefinitionError.invalidGeometry }
        }
        for point in [tee, pin] + drops.map(\.position) {
            guard bounds.contains(point), terrain(at: point) != .water,
                  !trees.contains(where: { $0.position.distance(to: point) <= $0.trunkRadius + 0.5 }) else { throw HoleDefinitionError.invalidGeometry }
        }
        for drop in drops {
            guard !drop.id.isEmpty, drop.position.x >= 0.5, drop.position.y >= 0.5,
                  drop.position.x <= bounds.width - 0.5, drop.position.y <= bounds.height - 0.5,
                  drop.hazardID == nil || regions.contains(where: { $0.id == drop.hazardID && $0.terrain == .water }) else { throw HoleDefinitionError.invalidGeometry }
        }
        for decoration in decorations {
            guard !decoration.asset.isEmpty, bounds.contains(decoration.position), decoration.scale.isFinite,
                  (0.1...10).contains(decoration.scale) else { throw HoleDefinitionError.invalidGeometry }
        }
    }

    #if DEBUG
    func debugReplacingWind(_ wind: WindCondition) throws -> Self {
        let copy = Self(id: id, par: par, bounds: bounds, tee: tee, pin: pin, green: green, fairway: fairway,
                        physicsVersion: physicsVersion, contentVersion: contentVersion, safeTarget: safeTarget,
                        wind: wind, regions: regions, elevation: elevation, greenSlope: greenSlope, trees: trees,
                        drops: drops, decorations: decorations, route: route, elevationPatches: elevationPatches)
        try copy.validateExtended()
        return copy
    }
    #endif

    private struct Document: Decodable {
        let schemaVersion: Int
        let id: String
        let par: Int
        let bounds: CourseBounds
        let tee: Vector2
        let pin: Vector2
        let green: GreenDefinition
        let fairway: [Vector2]
        let physicsVersion: Int?
        let contentVersion: Int?
        let safeTarget: Vector2?
        let wind: WindCondition?
        let regions: [TerrainRegion]?
        let elevation: ElevationDefinition?
        let greenSlope: Vector2?
        let trees: [TreeDefinition]?
        let drops: [DropDefinition]?
        let decorations: [DecorationDefinition]?
        let route: [Vector2]?
        let elevationPatches: [ElevationPatch]?
    }
}

public enum HoleDefinitionError: Error, Sendable {
    case unsupportedSchema, invalidMetadata, invalidGeometry
}
