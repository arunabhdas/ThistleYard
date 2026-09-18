import Foundation

/// Sweep the complete rolling segment; evaluate speed inside the disk, not at the frame endpoint.
enum CupCapture {
    static func captures(from start: Vector2, to end: Vector2, initialSpeed: Double, deceleration: Double, pin: Vector2) -> Bool {
        let segment = end - start, length = segment.length
        let radius = SimulationConfig.cupRadius, maxSpeed = SimulationConfig.cupMaximumSpeed
        guard length > 0 else { return start.distance(to: pin) <= radius && initialSpeed <= maxSpeed }
        let direction = segment * (1 / length), offset = start - pin
        let projection = offset.dot(direction)
        let discriminant = projection * projection - offset.dot(offset) + radius * radius
        guard discriminant >= 0 else { return false }
        let root = sqrt(discriminant)
        let entry = max(0, -projection - root), exit = min(length, -projection + root)
        guard entry <= exit else { return false }
        let slowDistance = deceleration > 0 ? max(0, (initialSpeed * initialSpeed - maxSpeed * maxSpeed) / (2 * deceleration)) : 0
        if deceleration == 0 && initialSpeed > maxSpeed { return false }
        return max(entry, slowDistance) <= exit
    }
}
