import Foundation

public enum GolfClubType: String, Codable, CaseIterable, Sendable {
    case driver, fiveIron, sevenIron, pitchingWedge, sandWedge, putter
    public var displayName: String {
        switch self {
        case .driver: "Driver"
        case .fiveIron: "5 Iron"
        case .sevenIron: "7 Iron"
        case .pitchingWedge: "Pitching Wedge"
        case .sandWedge: "Sand Wedge"
        case .putter: "Putter"
        }
    }
    public var nominalCarryYards: Double {
        switch self {
        case .driver: 230
        case .fiveIron: 180
        case .sevenIron: 145
        case .pitchingWedge: 100
        case .sandWedge: 65
        case .putter: 30
        }
    }
    public var maximumDistanceMeters: Double { nominalCarryYards * 0.9144 }
    public var launchAngleDegrees: Double {
        switch self {
        case .driver: 18
        case .fiveIron: 28
        case .sevenIron: 36
        case .pitchingWedge: 48
        case .sandWedge: 58
        case .putter: 0
        }
    }
    public var launchAngleRadians: Double { launchAngleDegrees * .pi / 180 }
    public var landingStopFactor: Double {
        switch self {
        case .driver: 1
        case .fiveIron: 0.96
        case .sevenIron: 0.92
        case .pitchingWedge: 0.88
        case .sandWedge: 0.8
        case .putter: 1
        }
    }
}
public typealias PracticeClub = GolfClubType

public enum PuttRange: String, Codable, CaseIterable, Sendable {
    case short, medium, long
    public var yards: Double { switch self { case .short: 3; case .medium: 10; case .long: 30 } }
    public var meters: Double { yards * 0.9144 }
    public var displayName: String { "\(Int(yards)) yd" }
    public static func recommended(distanceMeters: Double) -> Self {
        if distanceMeters <= 2.7432 { return .short }
        if distanceMeters <= 9.144 { return .medium }
        return .long
    }
}

public struct WindCondition: Codable, Equatable, Sendable {
    public let speedMPH: Double
    public let towardDegrees: Double
    public init(speedMPH: Double, towardDegrees: Double) {
        self.speedMPH = speedMPH.isFinite ? min(60, max(0, speedMPH)) : 0
        self.towardDegrees = towardDegrees.isFinite ? towardDegrees.truncatingRemainder(dividingBy: 360) : 0
    }
    public static let calm = WindCondition(speedMPH: 0, towardDegrees: 0)
    public var velocity: Vector2 {
        let angle = towardDegrees * .pi / 180
        return Vector2(x: sin(angle), y: cos(angle)) * (speedMPH * 0.44704)
    }
}
