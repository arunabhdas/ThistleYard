import Foundation

extension GameReducer {
    public func checkpoint() -> GameCheckpoint {
        let value = Snapshot(wind: hole.wind, state: state, accumulator: accumulator, nextShotID: nextShotID, nextEventID: nextEventID,
                             pendingShot: pendingShot, swingElapsed: swingElapsed, shotTimer: shotTimer, pausedPhase: pausedPhase, simulation: simulation)
        do {
            return GameCheckpoint(schemaVersion: 1,physicsVersion: hole.physicsVersion,contentVersion: hole.contentVersion,
                                  holeID: hole.id,snapshot: try JSONEncoder().encode(value))
        } catch { preconditionFailure("Validated finite simulation state must encode: \(error)") }
    }
    public init(hole: HoleDefinition, checkpoint: GameCheckpoint) throws {
        try self.init(hole: hole, restoring: checkpoint, recovering: false)
    }
    /// Call only after the player acknowledges an assisted recovery from a settled checkpoint.
    public init(hole: HoleDefinition, recoveringSettledCheckpoint checkpoint: GameCheckpoint) throws {
        try self.init(hole: hole, restoring: checkpoint, recovering: true)
    }
    private init(hole: HoleDefinition, restoring checkpoint: GameCheckpoint, recovering: Bool) throws {
        try checkpoint.validate()
        guard checkpoint.holeID == hole.id else { throw GameCheckpointError.wrongHole }
        guard recovering || (checkpoint.physicsVersion == hole.physicsVersion && checkpoint.contentVersion == hole.contentVersion) else { throw GameCheckpointError.incompatibleVersion }
        let value = try JSONDecoder().decode(Snapshot.self, from: checkpoint.snapshot)
        guard recovering || value.wind == hole.wind else { throw GameCheckpointError.incompatibleVersion }
        let state = value.state, ball = state.ball, phase = value.pausedPhase ?? state.phase
        guard hole.bounds.contains(ball.position), ball.altitude.isFinite, (0...10_000).contains(ball.altitude),
              ball.velocity.isFinite, ball.velocity.length <= 10_000, ball.verticalVelocity.isFinite, abs(ball.verticalVelocity) <= 10_000,
              state.aimDirection.isFinite, abs(state.aimDirection.length - 1) <= 1e-6,
              state.power.isFinite, (0...1).contains(state.power), state.activeShotElapsed.isFinite,
              (0...31).contains(state.activeShotElapsed), state.swingProgress.isFinite, (0...1).contains(state.swingProgress),
              state.strokeCount >= 0, state.strokeCount <= 100_000, state.penaltyCount >= 0, state.penaltyCount <= state.strokeCount,
              value.nextShotID > (state.shotID ?? 0), (1...100_001).contains(value.nextShotID), (1...10_000_000).contains(value.nextEventID),
              value.shotTimer.elapsed.isFinite, (0...31).contains(value.shotTimer.elapsed),
              abs(value.shotTimer.elapsed - state.activeShotElapsed) <= 1e-7,
              value.pausedPhase != .paused,
              value.accumulator.isFinite, (0...SimulationConfig.maximumFrameDelta).contains(value.accumulator),
              value.swingElapsed.isFinite, (0...1).contains(value.swingElapsed),
              (state.phase == .paused) == (value.pausedPhase != nil) else { throw GameCheckpointError.invalidSnapshot }
        let moving = phase == .swinging || phase == .inFlight || phase == .rolling
        guard moving == (value.pendingShot != nil) else { throw GameCheckpointError.invalidSnapshot }
        if let shot = value.pendingShot {
            guard shot.id == state.shotID, hole.bounds.contains(shot.origin), shot.direction.isFinite,
                  abs(shot.direction.length - 1) <= 1e-6, shot.power.isFinite, shot.power > 0, shot.power <= 1 else { throw GameCheckpointError.invalidSnapshot }
        }
        if checkpoint.physicsVersion > 1 && (phase == .inFlight || phase == .rolling), value.simulation == nil { throw GameCheckpointError.invalidSnapshot }
        if let simulation = value.simulation {
            guard simulation.ball == ball, simulation.phase == phase else { throw GameCheckpointError.invalidSnapshot }
        }
        if phase == .complete {
            guard state.result == HoleResult(strokes: state.strokeCount,par: hole.par), ball.position == hole.pin else { throw GameCheckpointError.invalidSnapshot }
        } else if state.result != nil { throw GameCheckpointError.invalidSnapshot }
        if recovering {
            guard !moving, phase == .aiming || phase == .charging || phase == .complete,
                  hole.terrain(at: ball.position) != .water else { throw GameCheckpointError.invalidSnapshot }
        }
        self.init(hole: hole)
        self.state = state; accumulator = value.accumulator; nextShotID = value.nextShotID; nextEventID = value.nextEventID
        pendingShot = value.pendingShot; swingElapsed = value.swingElapsed; shotTimer = value.shotTimer
        pausedPhase = value.pausedPhase; simulation = value.simulation
        if recovering {
            self.state.phase = phase == .complete ? .complete : .aiming
            self.state.power = 0; pausedPhase = nil; accumulator = 0
            self.state.lie = hole.terrain(at: ball.position)
        }
    }
    private struct Snapshot: Codable {
        // Optional solely to permit acknowledged settled recovery of older snapshot shapes.
        let wind: WindCondition?
        let state: GameState
        let accumulator: Double
        let nextShotID: Int
        let nextEventID: Int
        let pendingShot: ShotInput?
        let swingElapsed: Double
        let shotTimer: ShotTimer
        let pausedPhase: GamePhase?
        let simulation: ShotSimulation?
    }
}
