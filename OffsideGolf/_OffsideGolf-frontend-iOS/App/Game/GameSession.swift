import Foundation
import Observation
import OffsideGolfCore

enum ShotPreviewWarning: String, CaseIterable {
    case water = "Water near the landing area"
    case outOfBounds = "Shot may leave the course"
}

struct HUDSnapshot: Equatable {
    let phase: GamePhase
    let club: PracticeClub
    let strokes: Int
    let penalties: Int
    let power: Int
    let distanceYards: Int
    let result: HoleResult?
    let outcome: ShotOutcome?
    let puttRange: PuttRange
    let lie: TerrainMaterial

    var phaseLabel: String {
        switch phase {
        case .aiming: "Ready to swing"
        case .charging: "Set your power"
        case .swinging: "Swinging"
        case .inFlight: "In the air"
        case .rolling: "Rolling"
        case .complete: "Hole complete"
        case .paused: "Paused"
        }
    }
    var canAim: Bool { phase == .aiming || phase == .charging }
}

/// Owns the synchronous game simulation; SwiftUI observes only changes to the HUD.
@MainActor @Observable
final class GameSession {
    @ObservationIgnored private var reducer: GameReducer
    @ObservationIgnored private var previousFrame: TimeInterval?
    @ObservationIgnored let scene: GameScene
    @ObservationIgnored var onCheckpoint: ((GameCheckpoint) -> Void)?
    @ObservationIgnored var mayAdvance: (() -> Bool)?
    @ObservationIgnored var onAssisted: (() -> Void)?
    @ObservationIgnored private let audio: AudioManager?
    @ObservationIgnored private let haptics: HapticManager
    @ObservationIgnored private var previewTask: Task<Void, Never>?
    @ObservationIgnored private var previewDirty = true
    @ObservationIgnored private var previewVersion = 0
    @ObservationIgnored private var previewTime = 0.0
    @ObservationIgnored private var lastEventID = 0
    @ObservationIgnored private let audioSessionID = UUID().uuidString
    @ObservationIgnored private var pullCaptured = false
    private(set) var previewWarning: ShotPreviewWarning?
    let settings: GameSettings
    var hole: HoleDefinition { reducer.hole }
    var checkpoint: GameCheckpoint { reducer.checkpoint() }
    #if DEBUG
    private(set) var debugSpeed = 1.0
    @ObservationIgnored private var frameSamples: [Double] = []
    @ObservationIgnored private let profileFrames = ProcessInfo.processInfo.arguments.contains("--profile-frames")
    func markAssisted() { onAssisted?(); onCheckpoint?(checkpoint) }
    func setDebugTrajectory(_ enabled: Bool) {
        if enabled { markAssisted() }
        scene.debugTrajectory = enabled
    }
    func setDebugGeometry(_ enabled: Bool) {
        if enabled { markAssisted() }
        scene.debugGeometry = enabled
    }
    func setDebugSpeed(_ speed: Double) { markAssisted(); debugSpeed = speed }
    func debugTeleport(_ point: Vector2) {
        markAssisted(); reducer.debugTeleport(to: point); debugChanged()
    }
    func debugComplete() { markAssisted(); reducer.debugCompleteHole(); consumeEvents(); debugChanged() }
    func debugWind(speed: Double,direction: Double) {
        markAssisted(); reducer.debugSetWind(speedMPH: speed,towardDegrees: direction); scene.updateHole(reducer.hole); debugChanged()
    }
    private func debugChanged() {
        inputGeneration += 1; pullCaptured = false; previousFrame = nil
        previewVersion += 1; previewDirty = true; synchronize(); onCheckpoint?(checkpoint)
    }
    #endif
    private(set) var hud: HUDSnapshot
    private(set) var inputGeneration = 0
    var state: GameState { reducer.state }

    init(hole: HoleDefinition, restored: GameReducer? = nil, settings: GameSettings = GameSettings(),
         appearance: GolferAppearance = GolferAppearance(), audio: AudioManager? = nil) {
        reducer = restored ?? GameReducer(hole: hole)
        self.settings = settings
        self.audio = audio
        haptics = HapticManager(isEnabled: settings.hapticsEnabled)
        scene = GameScene(hole: hole)
        scene.settings = settings
        scene.appearance = appearance
        hud = Self.snapshot(reducer.state, hole: hole)
        scene.onFrame = { [weak self] time in self?.frame(at: time) }
        scene.onAim = { [weak self] point in self?.aim(at: point) }
        scene.render(reducer.state)
    }

    func send(_ command: GameCommand) {
        switch command {
        case .cancelCharge, .pause, .restart: inputGeneration += 1; pullCaptured = false
        default: break
        }
        reducer.send(command)
        previewVersion += 1; previewDirty = true
        if reducer.state.phase != .charging || reducer.state.power <= 0 {
            scene.prediction = nil; previewWarning = nil
        }
        if case .release = command { audio?.play(.swing) }
        consumeEvents()
        if reducer.state.phase == .paused { previousFrame = nil }
        synchronize()
        switch command {
        case .release, .pause, .restart: onCheckpoint?(checkpoint)
        default: break
        }
    }

    func frame(at time: TimeInterval) {
        #if DEBUG
        let frameStart = Date.timeIntervalSinceReferenceDate
        defer {
            if profileFrames {
                frameSamples.append((Date.timeIntervalSinceReferenceDate-frameStart)*1_000)
                if frameSamples.count == 600 {
                    let sorted = frameSamples.sorted()
                    print("OFFSIDE_FRAME_CPU_MS p50=\(sorted[300]) p95=\(sorted[570]) max=\(sorted[599]) nodes=\(scene.children.count)")
                    frameSamples.removeAll(keepingCapacity: true)
                }
            }
        }
        #endif
        defer { previousFrame = time }
        guard let previousFrame, time >= previousFrame else { return }
        let elapsed = time - previousFrame
        guard mayAdvance?() != false else { synchronize(); return }
        // Suspended render loops must not jump a shot forward on re-entry.
        let previousPhase = reducer.state.phase
        let previousStrokes = reducer.state.strokeCount
        if elapsed <= 0.25 {
            #if DEBUG
            let adjusted = elapsed * debugSpeed
            let steps = max(1,Int(ceil(adjusted * 60)))
            for _ in 0..<steps { reducer.advance(by: adjusted / Double(steps)); consumeEvents() }
            #else
            reducer.advance(by: elapsed)
            #endif
        }
        consumeEvents()
        synchronize(elapsed: min(elapsed, 0.1))
        if reducer.state.phase != previousPhase || reducer.state.strokeCount != previousStrokes {
            previewVersion += 1; previewDirty = true
            onCheckpoint?(checkpoint)
        }
        if previewDirty, previewTask == nil, hud.canAim, time - previewTime >= 0.1 {
            previewTime = time; refreshPreview()
        }
    }

    func beginPull() { pullCaptured = true; send(.beginCharge) }
    func endPull() { pullCaptured = false }
    func aim(at point: Vector2) {
        guard !pullCaptured else { return }
        send(.aim(point - reducer.state.ball.position))
    }
    func aimAtFlag() { aim(at: reducer.hole.pin) }
    func rotateAim(degrees: Double) {
        guard !pullCaptured else { return }
        let angle = degrees * .pi / 180
        let aim = reducer.state.aimDirection
        send(.aim(Vector2(x: aim.x * cos(angle) - aim.y * sin(angle),
                         y: aim.x * sin(angle) + aim.y * cos(angle))))
    }
    func setPower(_ value: Double) {
        if reducer.state.phase == .aiming { send(.beginCharge) }
        send(.setPower(value))
    }
    func resume() { previousFrame = nil; send(.resume) }
    func restart() { previousFrame = nil; send(.restart) }

    private func synchronize(elapsed: Double = 0) {
        scene.render(reducer.state, elapsed: elapsed)
        let updated = Self.snapshot(reducer.state, hole: reducer.hole)
        if updated != hud { hud = updated }
    }
    private static func snapshot(_ state: GameState, hole: HoleDefinition) -> HUDSnapshot {
        HUDSnapshot(phase: state.phase, club: state.club, strokes: state.strokeCount,
                    penalties: state.penaltyCount, power: Int((state.power * 100).rounded()),
                    distanceYards: Int((state.ball.position.distance(to: hole.pin) / 0.9144).rounded()),
                    result: state.result, outcome: state.lastOutcome, puttRange: state.puttRange, lie: state.lie)
    }
    private func refreshPreview() {
        previewDirty = false
        let hole = reducer.hole, state = reducer.state, version = previewVersion
        guard state.phase == .charging, state.power > 0 else {
            scene.prediction = nil; previewWarning = nil
            return
        }
        let power = state.power
        previewTask = Task { [weak self] in
            let prediction = await Task.detached(priority: .userInitiated) {
                ShotPredictor.predict(hole: hole, state: state, power: power)
            }.value
            guard let self else { return }
            self.previewTask = nil
            guard version == self.previewVersion else { self.previewDirty = true; return }
            self.scene.prediction = prediction
            self.previewWarning = prediction.outcome == .water ? .water
                : prediction.outcome == .outOfBounds ? .outOfBounds : nil
        }
    }
    private func consumeEvents() {
        for event in reducer.events where event.id > lastEventID {
            lastEventID = event.id
            let id = "\(audioSessionID)-\(hole.id)-\(event.id)"
            switch event.kind {
            case .impact: audio?.play(.impact,eventID: id); haptics.play(.impact)
            case .bounce: audio?.play(.bounce,eventID: id,intensity: 0.4)
            case .sand: audio?.play(.sand,eventID: id)
            case .splash: audio?.play(.splash,eventID: id); haptics.play(.selection)
            case .cupCapture: audio?.play(.cup,eventID: id); haptics.play(.cup)
            case .tree: audio?.play(.bounce,eventID: id,intensity: 0.3)
            case .settled, .penalty: break
            }
            scene.show(event)
        }
    }

}
