import Foundation

public struct GameReducer: Sendable {
    public internal(set) var state: GameState
    public internal(set) var hole: HoleDefinition
    public internal(set) var events: [SimulationEvent] = []
    var nextEventID = 1
    var accumulator = 0.0
    var nextShotID = 1
    var pendingShot: ShotInput?
    var swingElapsed = 0.0
    var shotTimer = ShotTimer()
    var pausedPhase: GamePhase?
    var simulation: ShotSimulation?

    public init(hole: HoleDefinition) {
        self.hole = hole
        self.state = GameState(ball: BallState(position: hole.tee), aimDirection: (hole.safeTarget - hole.tee).normalized)
        state.club = hole.green.contains(hole.tee) ? .putter : .fiveIron
        state.lie = hole.terrain(at: hole.tee)
        if hole.physicsVersion > 1 {
            state.puttRange = .recommended(distanceMeters: hole.tee.distance(to: hole.pin))
            state.club = ClubRecommendation.recommend(hole: hole, position: hole.tee, target: hole.safeTarget)
        }
    }

    public mutating func send(_ command: GameCommand) {
        events = []
        switch command {
        case .chooseClub(let club):
            guard state.phase == .aiming || state.phase == .charging else { return }
            guard !(state.lie == .deepRough && club == .driver) else { return }
            state.club = club
        case .setPuttRange(let range):
            guard state.phase == .aiming || state.phase == .charging, state.club == .putter else { return }
            state.puttRange = range
        case .restart:
            let sequence = nextShotID, eventSequence = nextEventID
            self = Self(hole: hole)
            nextEventID = eventSequence
            nextShotID = sequence // An old animation callback must never match a restarted shot.
        case .pause:
            guard state.phase != .paused else { return }
            pausedPhase = state.phase
            state.phase = .paused
        case .resume:
            guard state.phase == .paused, let phase = pausedPhase else { return }
            state.phase = phase == .charging ? .aiming : phase
            if phase == .charging { state.power = 0 }
            pausedPhase = nil
        case .aim(let direction):
            guard state.phase == .aiming || state.phase == .charging else { return }
            let unit = direction.normalized
            if unit != .zero { state.aimDirection = unit }
        case .beginCharge:
            guard state.phase == .aiming else { return }
            state.phase = .charging
            state.power = 0
        case .setPower(let power):
            guard state.phase == .charging else { return }
            state.power = power.isFinite ? min(1, max(0, power)) : 0
        case .cancelCharge:
            guard state.phase == .charging else { return }
            state.phase = .aiming; state.power = 0
        case .release:
            guard state.phase == .charging else { return }
            guard state.power > 0 else { state.phase = .aiming; return }
            pendingShot = ShotInput(id: nextShotID, origin: state.ball.position, direction: state.aimDirection, power: state.power, club: state.club, puttRange: state.puttRange)
            state.shotID = nextShotID
            nextShotID += 1
            state.phase = .swinging
            state.lastOutcome = nil
            swingElapsed = 0
            state.swingProgress = 0
            state.activeShotElapsed = 0
            state.firstLanding = nil
            shotTimer = ShotTimer()
            accumulator = 0
        case .impact(let id):
            impact(id: id)
        }
    }

    /// Discard anomalous excess frame time; normal rendering integrates identical 120 Hz ticks.
    public mutating func advance(by elapsed: Double) {
        events = []
        guard state.phase != .paused, elapsed.isFinite, elapsed > 0, elapsed <= SimulationConfig.maximumFrameDelta else { return }
        guard state.phase == .swinging || state.phase == .inFlight || state.phase == .rolling else { return }
        accumulator = min(SimulationConfig.maximumFrameDelta, accumulator + elapsed)
        for _ in 0..<SimulationConfig.maximumTicksPerFrame {
            guard accumulator + SimulationConfig.timeTolerance >= SimulationConfig.fixedStep else { break }
            accumulator = max(0, accumulator - SimulationConfig.fixedStep)
            tick(SimulationConfig.fixedStep)
        }
    }

    private mutating func impact(id: Int) {
        guard state.phase == .swinging, let shot = pendingShot, shot.id == id,
              swingElapsed + SimulationConfig.timeTolerance >= SimulationConfig.impactDelay else { return }
        state.strokeCount += 1
        emit(.impact)
        if shot.club != .putter {
            state.ball = FlightSolver.launch(position: shot.origin, direction: shot.direction, power: shot.power, club: shot.club, drag: hole.physicsVersion > 1 ? SimulationConfig.drag : 0, launchFactor: hole.physicsVersion > 1 ? (state.lie == .bunker && shot.club == .sandWedge ? 0.9 : state.lie.launchFactor) : 1)
            state.phase = .inFlight
        } else {
            let speed = sqrt(2 * SimulationConfig.greenDeceleration * shot.puttRange.meters * shot.power)
            state.ball = BallState(position: shot.origin, velocity: shot.direction * speed)
            state.phase = .rolling
        }
        if hole.physicsVersion > 1 { simulation = ShotSimulation(ball: state.ball, phase: state.phase) }
    }

    private mutating func tick(_ elapsed: Double) {
        if state.phase == .swinging {
            swingElapsed += elapsed
            state.swingProgress = min(1, swingElapsed / SimulationConfig.impactDelay)
            if let shot = pendingShot { impact(id: shot.id) }
            return
        }
        guard state.phase == .inFlight || state.phase == .rolling else { return }
        state.activeShotElapsed += elapsed
        let timeoutOutcome = shotTimer.advance(by: elapsed)
        if hole.physicsVersion > 1 {
            simulateFullPhysics(by: elapsed)
            if let timeoutOutcome, state.phase == .inFlight || state.phase == .rolling { settle(timeoutOutcome) }
            return
        }
        if state.phase == .inFlight {
            let step = FlightSolver.advance(state.ball, by: elapsed, wind: hole.wind, drag: hole.physicsVersion > 1 ? SimulationConfig.drag : 0)
            state.ball = step.ball
            if recoverIfOutside() { return }
            if step.landed {
                if state.firstLanding == nil { state.firstLanding = state.ball.position }
                emit(.bounce)
                state.ball = BallState(position: state.ball.position, velocity: state.ball.velocity * SimulationConfig.landingRetention)
                state.phase = .rolling
                roll(by: step.remainingTime)
            }
        } else {
            roll(by: elapsed)
        }
        // A distinguishable recovery outcome freezes the last valid in-bounds location.
        if let timeoutOutcome, state.phase == .inFlight || state.phase == .rolling { settle(timeoutOutcome) }
    }

    private mutating func simulateFullPhysics(by elapsed: Double) {
        guard var engine = simulation, let shot = pendingShot else { return }
        let step = engine.advance(hole: hole, club: shot.club, by: elapsed)
        simulation = engine
        state.ball = engine.ball
        state.phase = engine.phase
        if state.firstLanding == nil { state.firstLanding = step.firstLanding }
        for event in step.events { emit(event) }
        if let hazard = step.hazard {
            if hazard.outcome == .water { emit(.splash) }
            state.strokeCount += 1
            state.penaltyCount += 1
            emit(.penalty)
            state.ball = BallState(position: HazardResolver.drop(hole: hole, hazardID: hazard.id, crossing: hazard.crossing, origin: shot.origin))
            settle(hazard.outcome)
        } else if step.captured {
            state.ball = BallState(position: hole.pin)
            state.phase = .complete
            state.power = 0
            state.result = HoleResult(strokes: state.strokeCount, par: hole.par)
            state.lastOutcome = .settled
            emit(.cupCapture)
            pendingShot = nil
            simulation = nil
        } else if engine.phase == .aiming { settle(.settled) }
    }

    private mutating func roll(by elapsed: Double) {
        let before = state.ball
        let deceleration = hole.green.contains(before.position) ? SimulationConfig.greenDeceleration : SimulationConfig.fairwayDeceleration
        state.ball = RollSolver.advance(before, by: elapsed, deceleration: deceleration)
        if recoverIfOutside() { return }
        if CupCapture.captures(from: before.position, to: state.ball.position,
                               initialSpeed: before.velocity.length, deceleration: deceleration, pin: hole.pin) {
            state.ball = BallState(position: hole.pin)
            state.phase = .complete
            state.power = 0
            state.lastOutcome = .settled
            state.result = HoleResult(strokes: state.strokeCount, par: hole.par)
            emit(.cupCapture)
            pendingShot = nil
        } else if state.ball.velocity == .zero {
            settle(.settled)
        }
    }

    private mutating func recoverIfOutside() -> Bool {
        guard !hole.bounds.contains(state.ball.position), let shot = pendingShot else { return false }
        state.strokeCount += 1
        state.penaltyCount += 1
        emit(.penalty)
        state.ball = BallState(position: shot.origin)
        settle(.outOfBounds)
        return true
    }

    private mutating func settle(_ outcome: ShotOutcome) {
        simulation = nil
        state.ball = BallState(position: state.ball.position)
        state.phase = .aiming
        state.power = 0
        state.lie = hole.terrain(at: state.ball.position)
        state.club = hole.green.contains(state.ball.position) ? .putter : .fiveIron
        if hole.physicsVersion > 1 {
            state.puttRange = .recommended(distanceMeters: state.ball.position.distance(to: hole.pin))
            state.club = ClubRecommendation.recommend(hole: hole, position: state.ball.position, target: hole.pin)
        }
        let direction = (hole.pin - state.ball.position).normalized
        if direction != .zero { state.aimDirection = direction }
        state.lastOutcome = outcome
        emit(.settled)
        pendingShot = nil
    }

    mutating func emit(_ kind: SimulationEvent.Kind) {
        guard let shotID = state.shotID else { return }
        events.append(SimulationEvent(id: nextEventID, shotID: shotID, kind: kind, position: state.ball.position, material: hole.terrain(at: state.ball.position)))
        nextEventID += 1
    }
    init(hole: HoleDefinition, previewState: GameState) {
        self.hole = hole
        state = previewState
        state.phase = .aiming
        state.result = nil
    }
    struct ShotInput: Codable, Sendable {
        let id: Int
        let origin: Vector2
        let direction: Vector2
        let power: Double
        let club: PracticeClub
        let puttRange: PuttRange
    }
}
