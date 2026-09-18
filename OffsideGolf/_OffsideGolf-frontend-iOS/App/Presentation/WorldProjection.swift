import CoreGraphics
import OffsideGolfCore

/// A flat-ground 65° projection. M1 has no elevation patches to invert.
struct WorldProjection {
    let worldBounds: CGRect
    let scale: CGFloat
    private let origin: CGPoint
    private let sine = sin(65.0 * .pi / 180)
    private let cosine = cos(65.0 * .pi / 180)
    private let hole: HoleDefinition?

    init(worldBounds: CGRect, viewport: CGSize, hole: HoleDefinition? = nil) {
        self.worldBounds = worldBounds
        self.hole = hole
        let availableWidth = max(1, viewport.width - 48)
        let availableHeight = max(1, viewport.height - 48)
        scale = min(availableWidth / max(1, worldBounds.width),
                    availableHeight / max(1, worldBounds.height * sine))
        origin = CGPoint(x: (viewport.width - worldBounds.width * scale) / 2,
                         y: (viewport.height - worldBounds.height * scale * sine) / 2)
    }

    func point(for position: Vector2, altitude: Double = 0) -> CGPoint {
        CGPoint(x: origin.x + (position.x - worldBounds.minX) * scale,
                y: origin.y + ((position.y - worldBounds.minY) * sine + ((hole?.elevation(at: position) ?? 0) + altitude) * cosine) * scale)
    }

    func groundPoint(at point: CGPoint) -> Vector2 {
        let x = (point.x - origin.x) / scale + worldBounds.minX
        let flatY = (point.y - origin.y) / (scale * sine) + worldBounds.minY
        var y = flatY
        // Authored gradients are gentle; fixed-point inversion converges without view-dependent physics.
        for _ in 0..<12 {
            y = flatY - (hole?.elevation(at: Vector2(x: x, y: y)) ?? 0) * cosine / sine
        }
        return Vector2(x: x, y: y)
    }
}
