import Foundation

/// Scalar altitude keeps flat M1 ground-plane math explicit without an unnecessary Vector3.
public struct BallState: Codable, Equatable, Sendable {
    public let position: Vector2
    public let altitude: Double
    public let velocity: Vector2
    public let verticalVelocity: Double
    public init(position: Vector2, altitude: Double = 0, velocity: Vector2 = .zero, verticalVelocity: Double = 0) {
        self.position = position; self.altitude = altitude
        self.velocity = velocity; self.verticalVelocity = verticalVelocity
    }
}

public enum GamePhase: String, Codable, CaseIterable, Sendable {
    case aiming, charging, swinging, inFlight, rolling, complete, paused
}
public enum ShotOutcome: String, Codable, CaseIterable, Sendable { case settled, outOfBounds, timedOut, water }
public enum GameCommand: Sendable {
    case aim(Vector2), beginCharge, setPower(Double), cancelCharge, release
    case impact(shotID: Int), pause, resume, restart
    case chooseClub(GolfClubType), setPuttRange(PuttRange)
}

public struct HoleResult: Codable, Equatable, Sendable {
    public let strokes: Int
    public let par: Int
    public var relativeToPar: Int { strokes - par }
    public var title: String {
        if strokes == 1 { return "Ace" }
        switch relativeToPar {
        case -3: return "Albatross"
        case -2: return "Eagle"
        case -1: return "Birdie"
        case 0: return "Par"
        case 1: return "Bogey"
        case 2: return "Double Bogey"
        case let score where score < 0: return "\(abs(score)) under par"
        default: return "+\(relativeToPar) over par"
        }
    }
    public init(strokes: Int, par: Int) { self.strokes = strokes; self.par = par }
}

public struct GameState: Codable, Equatable, Sendable {
    public internal(set) var ball: BallState
    public internal(set) var aimDirection: Vector2
    public internal(set) var power: Double = 0
    public internal(set) var club: PracticeClub = .fiveIron
    public internal(set) var phase: GamePhase = .aiming
    public internal(set) var strokeCount: Int = 0
    public internal(set) var penaltyCount: Int = 0
    public internal(set) var result: HoleResult?
    public internal(set) var shotID: Int?
    public internal(set) var lastOutcome: ShotOutcome?
    public internal(set) var puttRange: PuttRange = .long
    public internal(set) var firstLanding: Vector2?
    public internal(set) var activeShotElapsed: Double = 0
    public internal(set) var swingProgress: Double = 0
    public internal(set) var lie: TerrainMaterial = .tee
}
