import Foundation

/// Shared v2 simulation consumed by live play and prediction. Ball altitude remains above local terrain.
struct ShotSimulation: Codable, Sendable {
    var ball: BallState
    var phase: GamePhase
    private var ignoredTrees: Set<String> = []
    struct Hazard { let outcome: ShotOutcome; let id: String; let crossing: Vector2 }
    struct Step {
        var events: [SimulationEvent.Kind] = []
        var firstLanding: Vector2?
        var hazard: Hazard?
        var captured = false
    }
    init(ball: BallState, phase: GamePhase) { self.ball = ball; self.phase = phase }

    mutating func advance(hole: HoleDefinition, club: GolfClubType, by elapsed: Double) -> Step {
        var result = Step(), remaining = elapsed
        guard phase == .inFlight || phase == .rolling else { return result }
        for _ in 0..<SimulationConfig.maximumContactsPerTick {
            guard remaining > 1e-10 else { break }
            let flying = phase == .inFlight
            let worldStart = world(ball, hole: hole)
            ignoredTrees = ignoredTrees.filter { CollisionSolver.treeContains($0, ball: worldStart, hole: hole) }
            let next: BallState
            if flying { next = FlightSolver.airborne(worldStart, by: remaining, wind: hole.wind, drag: SimulationConfig.drag) }
            else {
                let rolled = RollSolver.advance(ball, by: remaining, deceleration: hole.terrain(at: ball.position).rollingDeceleration, slope: hole.slope(at: ball.position))
                next = world(rolled, hole: hole)
            }
            var contact = CollisionSolver.first(from: worldStart, to: next, hole: hole, airborne: flying, ignoredTrees: ignoredTrees)
            if flying, let groundTime = groundContact(start: worldStart, hole: hole, duration: remaining) {
                let fraction = groundTime / remaining
                if contact.map({ fraction < $0.fraction }) ?? true {
                    contact = CollisionSolver.Contact(fraction: fraction, id: "ground", kind: .ground)
                }
            }
            guard let contact else {
                ball = local(next, hole: hole)
                if !flying {
                    if CupCapture.captures(from: worldStart.position, to: next.position, initialSpeed: worldStart.velocity.length,
                                           deceleration: hole.terrain(at: worldStart.position).rollingDeceleration, pin: hole.pin) {
                        ball = BallState(position: hole.pin); phase = .complete; result.captured = true
                    } else if ball.velocity == .zero {
                        let slope = hole.slope(at: ball.position)
                        let downhillForce = SimulationConfig.gravity * slope.length / (1 + slope.dot(slope))
                        let support = hole.terrain(at: ball.position).rollingDeceleration * SimulationConfig.staticFrictionMultiplier
                        if downhillForce <= support { phase = .aiming }
                    }
                }
                return result
            }
            let duration = remaining * contact.fraction
            let atContact: BallState
            if flying { atContact = FlightSolver.airborne(worldStart, by: duration, wind: hole.wind, drag: SimulationConfig.drag) }
            else {
                let point = worldStart.position + (next.position - worldStart.position) * contact.fraction
                atContact = BallState(position: point, altitude: hole.elevation(at: point), velocity: worldStart.velocity)
            }
            ball = local(atContact, hole: hole)
            remaining -= duration
            switch contact.kind {
            case .bounds, .water:
                result.hazard = Hazard(outcome: contact.id == "bounds" ? .outOfBounds : .water, id: contact.id, crossing: ball.position)
                return result
            case .ground:
                ball = BallState(position: ball.position, velocity: ball.velocity, verticalVelocity: ball.verticalVelocity)
                let material = hole.terrain(at: ball.position)
                if material == .water {
                    let id = hole.regions.filter { $0.terrain == .water && $0.contains(ball.position) }.sorted { $0.id < $1.id }.first?.id ?? "water"
                    result.hazard = Hazard(outcome: .water,id: id,crossing: ball.position); return result
                }
                if result.firstLanding == nil { result.firstLanding = ball.position }
                result.events.append(material == .bunker ? .sand : .bounce)
                bounce(hole: hole, club: club, material: material)
                if phase == .rolling && CupCapture.captures(from: ball.position,to: ball.position,initialSpeed: ball.velocity.length,deceleration: 0,pin: hole.pin) {
                    ball = BallState(position: hole.pin); phase = .complete; result.captured = true; return result
                }
            case .trunk(let tree):
                ignoredTrees.insert(contact.id)
                var normal = (ball.position - tree.position).normalized
                if normal == .zero { normal = ball.velocity.normalized * -1 }
                let incoming = ball.velocity.dot(normal)
                ball = BallState(position: ball.position + normal * SimulationConfig.contactSeparation, altitude: ball.altitude,
                                 velocity: ball.velocity - normal * ((1 + SimulationConfig.treeTrunkRestitution) * min(0,incoming)), verticalVelocity: ball.verticalVelocity)
                result.events.append(.tree)
            case .canopy(let tree):
                ignoredTrees.insert(contact.id)
                let normal = (ball.position - tree.position).normalized
                let speed = ball.velocity.length * SimulationConfig.canopyRetention
                let direction = (ball.velocity.normalized + normal * SimulationConfig.canopyDeflection).normalized
                ball = BallState(position: ball.position, altitude: ball.altitude, velocity: direction * speed,
                                 verticalVelocity: ball.verticalVelocity * SimulationConfig.canopyRetention)
                result.events.append(.tree)
            }
            if contact.fraction < 1e-8 { remaining = max(0, remaining - SimulationConfig.collisionTimeTolerance) }
        }
        // Bounded contact work prevents pathological loops; settle only if the whole tick could not progress.
        if remaining > SimulationConfig.collisionTimeTolerance {
            ball = BallState(position: ball.position); phase = .aiming
        }
        return result
    }
    private func world(_ value: BallState, hole: HoleDefinition) -> BallState {
        BallState(position: value.position, altitude: value.altitude + hole.elevation(at: value.position), velocity: value.velocity, verticalVelocity: value.verticalVelocity)
    }
    private func local(_ value: BallState, hole: HoleDefinition) -> BallState {
        BallState(position: value.position, altitude: max(0,value.altitude - hole.elevation(at: value.position)), velocity: value.velocity, verticalVelocity: value.verticalVelocity)
    }
    private func groundContact(start: BallState, hole: HoleDefinition, duration: Double) -> Double? {
        var previous = 0.0
        for index in 1...8 {
            let time = duration * Double(index) / 8
            let sample = FlightSolver.airborne(start, by: time, wind: hole.wind, drag: SimulationConfig.drag)
            if sample.altitude <= hole.elevation(at: sample.position) {
                var low = previous, high = time
                for _ in 0..<20 {
                    let mid = (low + high) / 2, point = FlightSolver.airborne(start, by: mid, wind: hole.wind, drag: SimulationConfig.drag)
                    if point.altitude > hole.elevation(at: point.position) { low = mid } else { high = mid }
                }
                return high
            }
            previous = time
        }
        return nil
    }
    private mutating func bounce(hole: HoleDefinition, club: GolfClubType, material: TerrainMaterial) {
        let slope = hole.slope(at: ball.position), scale = 1 / sqrt(1 + slope.dot(slope))
        let normalXY = slope * -scale, normalZ = scale
        let dot = ball.velocity.dot(normalXY) + ball.verticalVelocity * normalZ
        let tangentXY = ball.velocity - normalXY * dot, tangentZ = ball.verticalVelocity - normalZ * dot
        let retention = material.retention * club.landingStopFactor
        let velocity = tangentXY * retention - normalXY * (min(0,dot) * material.restitution)
        let vertical = tangentZ * retention - normalZ * (min(0,dot) * material.restitution)
        if vertical < SimulationConfig.rollingThreshold {
            ball = BallState(position: ball.position, velocity: velocity); phase = .rolling
        } else { ball = BallState(position: ball.position, altitude: 0.00001,velocity: velocity,verticalVelocity: vertical) }
    }
}
