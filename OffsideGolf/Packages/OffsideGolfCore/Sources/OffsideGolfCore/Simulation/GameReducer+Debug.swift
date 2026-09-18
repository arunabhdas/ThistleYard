#if DEBUG
import Foundation

extension GameReducer {
    /// Debug assistance is marked by the app's round owner before calling this method.
    public mutating func debugTeleport(to position: Vector2) {
        guard hole.bounds.contains(position), position.x >= 0.5, position.y >= 0.5,
              position.x <= hole.bounds.width - 0.5, position.y <= hole.bounds.height - 0.5,
              hole.terrain(at: position) != .water,
              !hole.trees.contains(where: { $0.position.distance(to: position) <= $0.trunkRadius + 0.5 }) else { return }
        let slope = hole.slope(at: position)
        let downhill = SimulationConfig.gravity * slope.length / (1 + slope.dot(slope))
        guard downhill <= hole.terrain(at: position).rollingDeceleration * SimulationConfig.staticFrictionMultiplier else { return }
        debugClearPendingMotion()
        state.ball = BallState(position: position)
        state.phase = .aiming
        state.lie = hole.terrain(at: position)
        state.club = ClubRecommendation.recommend(hole: hole, position: position, target: hole.pin)
        state.puttRange = .recommended(distanceMeters: position.distance(to: hole.pin))
        let direction = (hole.pin - position).normalized
        if direction != .zero { state.aimDirection = direction }
    }

    public mutating func debugCompleteHole() {
        events = []
        guard state.phase != .complete else { return }
        debugClearPendingMotion()
        state.ball = BallState(position: hole.pin)
        state.phase = .complete
        state.lie = .green
        state.club = .putter
        state.strokeCount = max(1, state.strokeCount)
        state.result = HoleResult(strokes: state.strokeCount, par: hole.par)
        state.lastOutcome = .settled
        state.shotID = nextShotID
        nextShotID += 1
        emit(.cupCapture)
    }

    public mutating func debugSetWind(speedMPH: Double, towardDegrees: Double) {
        let restingPhase = state.phase == .paused ? pausedPhase : state.phase
        guard restingPhase == .aiming || restingPhase == .charging,
              speedMPH.isFinite, (0...60).contains(speedMPH), towardDegrees.isFinite,
              let replacement = try? hole.debugReplacingWind(WindCondition(speedMPH: speedMPH, towardDegrees: towardDegrees)) else { return }
        hole = replacement
        events = []
    }

    private mutating func debugClearPendingMotion() {
        pendingShot = nil
        simulation = nil
        pausedPhase = nil
        accumulator = 0
        swingElapsed = 0
        shotTimer = ShotTimer()
        events = []
        state.power = 0
        state.shotID = nil
        state.result = nil
        state.lastOutcome = nil
        state.firstLanding = nil
        state.activeShotElapsed = 0
        state.swingProgress = 0
    }
}
#endif
