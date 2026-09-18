import CoreGraphics
import Foundation
import OffsideGolfCore

/// World-space BODY direction, clockwise from north. Art is authored per direction;
/// none of these directions is synthesized by mirroring a right-handed swing.
enum GolferFacing: String, CaseIterable, Sendable {
    case north, northEast, east, southEast, south, southWest, west, northWest

    var sheetName: String { self == .southEast ? "golfer_poses_sheet" : "golfer_\(rawValue)" }

    /// Right-handed stance: shot north means body east, with the golfer west of the ball.
    static func forAim(_ aim: Vector2, fallback: Self = .east) -> Self {
        let unit = aim.normalized
        guard unit != .zero else { return fallback }
        let body = Vector2(x: unit.y, y: -unit.x)
        let sector = Int(floor(atan2(body.x, body.y) / (.pi / 4) + 0.5))
        return allCases[(sector % 8 + 8) % 8]
    }

    /// Retain the actual aim within a 45-degree sector for a smoothly moving stance.
    func bodyDirection(forAim aim: Vector2) -> Vector2 {
        let unit = aim.normalized
        guard unit != .zero else {
            let index: Int
            switch self {
            case .north: index = 0
            case .northEast: index = 1
            case .east: index = 2
            case .southEast: index = 3
            case .south: index = 4
            case .southWest: index = 5
            case .west: index = 6
            case .northWest: index = 7
            }
            let angle = Double(index) * .pi / 4
            return Vector2(x: sin(angle), y: cos(angle))
        }
        return Vector2(x: unit.y, y: -unit.x)
    }

    /// Sheet cells are authored from top-left; SpriteKit texture rects use bottom-left.
    func textureRect(for pose: GolferPose) -> CGRect {
        CGRect(x: Double(pose.rawValue % 4) / 4,
               y: Double(2 - pose.rawValue / 4) / 3, width: 0.25, height: 1.0 / 3)
    }

    func footAnchor(for pose: GolferPose) -> CGPoint {
        self == .southEast ? Self.southEastFeet[pose.rawValue] : CGPoint(x: 0.5, y: 0.04)
    }

    /// Source-cell nape registrations. The seven new directions use approximate
    /// silhouette-specific anchors pending final per-frame artist registration.
    func napeAnchor(for pose: GolferPose) -> CGPoint {
        if self == .southEast { return Self.southEastNapes[pose.rawValue] }
        let x: Double
        switch self {
        case .north, .northEast, .northWest: x = 0.50 // Back of cap.
        case .east: x = 0.40 // Right-looking profile: nape on screen left.
        case .west: x = 0.60 // Left-looking profile: nape on screen right.
        case .south: x = 0.58
        case .southWest: x = 0.60
        case .southEast: x = 0.40
        }
        let heights = [0.77, 0.72, 0.75, 0.72, 0.73, 0.72, 0.73, 0.74, 0.75, 0.75, 0.73, 0.73]
        return CGPoint(x: x, y: heights[pose.rawValue])
    }

    var hairFallsRight: Bool { self == .west || self == .southWest || self == .south }
    var showsBackOfHead: Bool { self == .north || self == .northEast || self == .northWest }

    // Preserve the original southeast sheet's measured registrations.
    private static let southEastFeet: [CGPoint] = [
        .init(x: 0.53, y: 0.045), .init(x: 0.51, y: 0.045), .init(x: 0.62, y: 0.055), .init(x: 0.52, y: 0.04),
        .init(x: 0.57, y: 0.055), .init(x: 0.55, y: 0.06), .init(x: 0.56, y: 0.06), .init(x: 0.52, y: 0.055),
        .init(x: 0.53, y: 0.065), .init(x: 0.54, y: 0.055), .init(x: 0.52, y: 0.05), .init(x: 0.55, y: 0.06)
    ]
    private static let southEastNapes: [CGPoint] = [
        .init(x: 0.40, y: 0.77), .init(x: 0.43, y: 0.72), .init(x: 0.50, y: 0.75), .init(x: 0.50, y: 0.72),
        .init(x: 0.54, y: 0.73), .init(x: 0.43, y: 0.72), .init(x: 0.39, y: 0.73), .init(x: 0.46, y: 0.74),
        .init(x: 0.43, y: 0.75), .init(x: 0.44, y: 0.75), .init(x: 0.47, y: 0.73), .init(x: 0.45, y: 0.73)
    ]
}
