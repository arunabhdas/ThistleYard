import Foundation

/// Versioned calm M1 tuning. Future drag, bounce and material changes need a version bump.
public enum SimulationConfig {
    public static let version = 2
    public static let drag = 0.04
    public static let windCoupling = 0.016
    public static let ballRadius = 0.02135
    public static let rollingThreshold = 0.45
    public static let stopSpeed = 0.025
    public static let staticFrictionMultiplier = 1.15
    public static let maximumContactsPerTick = 4
    public static let collisionTimeTolerance = 0.0001
    public static let treeTrunkRestitution = 0.25
    public static let canopyRetention = 0.55
    public static let fixedStep = 1.0 / 120
    public static let maximumFrameDelta = 0.25
    public static let maximumTicksPerFrame = 8
    public static let canopyDeflection = 0.15
    public static let contactSeparation = 0.001
    public static let gravity = 9.81
    public static let ironCarryMeters = 164.592
    public static let ironLaunchRadians = 28.0 * Double.pi / 180
    public static let putterRangeMeters = 27.432
    public static let landingRetention = 0.1
    public static let fairwayDeceleration = 1.1
    public static let greenDeceleration = 0.45
    public static let cupRadius = 0.11
    public static let cupMaximumSpeed = 1.4
    public static let impactDelay = 0.55
    public static let shotTimeLimit = 30.0
    static let timeTolerance = 1e-10
}
