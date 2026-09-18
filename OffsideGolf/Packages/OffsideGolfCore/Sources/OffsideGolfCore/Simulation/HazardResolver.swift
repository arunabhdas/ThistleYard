import Foundation

enum HazardResolver {
    static func drop(hole: HoleDefinition, hazardID: String, crossing: Vector2, origin: Vector2) -> Vector2 {
        let pinDistance = crossing.distance(to: hole.pin)
        return hole.drops.filter { drop in
            (drop.hazardID == nil || drop.hazardID == hazardID) &&
            drop.position.distance(to: hole.pin) + 1e-8 >= pinDistance &&
            hole.bounds.contains(drop.position) && hole.terrain(at: drop.position) != .water &&
            !hole.trees.contains(where: { tree in tree.position.distance(to: drop.position) <= tree.trunkRadius + 0.5 })
        }.sorted {
            let left = $0.position.distance(to: crossing), right = $1.position.distance(to: crossing)
            return abs(left - right) > 1e-8 ? left < right : $0.id < $1.id
        }.first?.position ?? origin
    }
}
