/// Defensive simulated-time guard. Pause does not advance it, and every shot starts a fresh timer.
struct ShotTimer: Codable, Sendable {
    private(set) var elapsed = 0.0
    mutating func advance(by duration: Double) -> ShotOutcome? {
        elapsed += duration
        return elapsed + SimulationConfig.timeTolerance >= SimulationConfig.shotTimeLimit ? .timedOut : nil
    }
}
