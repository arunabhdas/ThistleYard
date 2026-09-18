import Foundation

enum CollisionSolver {
    enum Kind { case ground, water, bounds, trunk(TreeDefinition), canopy(TreeDefinition) }
    struct Contact { let fraction: Double; let id: String; let kind: Kind }

    static func first(from start: BallState, to end: BallState, hole: HoleDefinition, airborne: Bool, ignoredTrees: Set<String>) -> Contact? {
        var contacts: [Contact] = []
        if !hole.bounds.contains(end.position) {
            let d = end.position - start.position
            var fraction = 1.0
            if end.position.x < 0 { fraction = min(fraction, -start.position.x / d.x) }
            if end.position.x > hole.bounds.width { fraction = min(fraction, (hole.bounds.width - start.position.x) / d.x) }
            if end.position.y < 0 { fraction = min(fraction, -start.position.y / d.y) }
            if end.position.y > hole.bounds.height { fraction = min(fraction, (hole.bounds.height - start.position.y) / d.y) }
            contacts.append(Contact(fraction: max(0, fraction), id: "bounds", kind: .bounds))
        }
        for region in hole.regions where region.terrain == .water {
            for fraction in Polygon.crossings(from: start.position, to: end.position, vertices: region.polygon) {
                let point = start.position + (end.position - start.position) * fraction
                let height = start.altitude + (end.altitude - start.altitude) * fraction
                if !airborne || height <= hole.elevation(at: point) + SimulationConfig.collisionTimeTolerance {
                    contacts.append(Contact(fraction: fraction, id: region.id, kind: .water)); break
                }
            }
        }
        for tree in hole.trees {
            if !ignoredTrees.contains("trunk:" + tree.id), let fraction = cylinderEntry(start: start, end: end, tree: tree, base: hole.elevation(at: tree.position)) {
                contacts.append(Contact(fraction: fraction, id: "trunk:" + tree.id, kind: .trunk(tree)))
            }
            if airborne, !ignoredTrees.contains("canopy:" + tree.id), let fraction = canopyEntry(start: start, end: end, tree: tree, base: hole.elevation(at: tree.position)) {
                contacts.append(Contact(fraction: fraction, id: "canopy:" + tree.id, kind: .canopy(tree)))
            }
        }
        return contacts.sorted { abs($0.fraction - $1.fraction) > 1e-10 ? $0.fraction < $1.fraction : $0.id < $1.id }.first
    }
    static func treeContains(_ id: String, ball: BallState, hole: HoleDefinition) -> Bool {
        guard let tree = hole.trees.first(where: { id == "trunk:" + $0.id || id == "canopy:" + $0.id }) else { return false }
        let z = ball.altitude - hole.elevation(at: tree.position)
        if id.hasPrefix("trunk:") { return ball.position.distance(to: tree.position) <= tree.trunkRadius + SimulationConfig.ballRadius + 0.001 && z <= tree.trunkHeight && z >= 0 }
        let radiusZ = (tree.canopyTop - tree.canopyBottom) / 2
        let delta = ball.position - tree.position, vertical = (z - (tree.canopyTop + tree.canopyBottom) / 2) / radiusZ
        return delta.dot(delta) / (tree.canopyRadius * tree.canopyRadius) + vertical * vertical <= 1.001
    }
    private static func interval(a: Double, b: Double, c: Double) -> (Double, Double)? {
        if a < 1e-20 { return c <= 0 ? (0,1) : nil }
        let discriminant = b * b - 4 * a * c
        guard discriminant >= 0 else { return nil }
        let root = sqrt(discriminant), lower = max(0, (-b - root) / (2 * a)), upper = min(1, (-b + root) / (2 * a))
        return lower <= upper ? (lower,upper) : nil
    }
    private static func cylinderEntry(start: BallState, end: BallState, tree: TreeDefinition, base: Double) -> Double? {
        let offset = start.position - tree.position, d = end.position - start.position, radius = tree.trunkRadius + SimulationConfig.ballRadius
        guard var range = interval(a: d.dot(d), b: 2 * offset.dot(d), c: offset.dot(offset) - radius * radius) else { return nil }
        let dz = end.altitude - start.altitude
        if abs(dz) < 1e-12 { return (base...base + tree.trunkHeight).contains(start.altitude) ? range.0 : nil }
        let a = (base - start.altitude) / dz, b = (base + tree.trunkHeight - start.altitude) / dz
        range = (max(range.0,min(a,b)),min(range.1,max(a,b)))
        return range.0 <= range.1 ? range.0 : nil
    }
    private static func canopyEntry(start: BallState, end: BallState, tree: TreeDefinition, base: Double) -> Double? {
        let radius = tree.canopyRadius, radiusZ = (tree.canopyTop - tree.canopyBottom) / 2
        let offset = (start.position - tree.position) * (1 / radius), d = (end.position - start.position) * (1 / radius)
        let z = (start.altitude - base - (tree.canopyTop + tree.canopyBottom) / 2) / radiusZ, dz = (end.altitude - start.altitude) / radiusZ
        return interval(a: d.dot(d) + dz * dz, b: 2 * (offset.dot(d) + z * dz), c: offset.dot(offset) + z * z - 1)?.0
    }
}
