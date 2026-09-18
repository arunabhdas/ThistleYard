import Foundation
import OffsideGolfCore

/// Row-major indices in the original four-column, three-row pose sheet.
enum GolferPose: Int, CaseIterable, Sendable {
    case idle, aim, practice, backswing, downswing, impact
    case followThrough, watchBall, celebrate, disappointed, putt, walk
}

struct GolferAnimationFrame: Equatable {
    let pose: GolferPose
    let groundPosition: Vector2
    var rotation: Double = 0
    var verticalOffset: Double = 0
    var scaleY: Double = 1
    var opacity: Double = 1
}

/// A presentation-only sampler. Committed swings use core clocks, never elapsed render time.
/// No animation marker calls back into gameplay; dropped frames cannot suppress or duplicate impact.
struct GolferAnimationController {
    private var anchor: Vector2?
    private var lastPhase: GamePhase = .aiming
    private var lastFrame: GolferAnimationFrame?
    private var practiceElapsed: Double?
    private var poseElapsed = 0.0
    private var idleElapsed = 0.0
    private var repositionElapsed: Double?

    mutating func startPractice() {
        guard lastPhase == .aiming else { return }
        practiceElapsed = 0
    }

    mutating func cancelPractice() { practiceElapsed = nil }

    mutating func sample(state: GameState, reducedMotion: Bool, elapsed: Double) -> GolferAnimationFrame {
        if state.phase == .paused, let lastFrame { return lastFrame }
        let delta = elapsed.isFinite ? min(0.25, max(0, elapsed)) : 0
        if lastPhase != state.phase { poseElapsed = 0 }
        else { poseElapsed += delta }
        idleElapsed += delta

        if anchor == nil { anchor = state.ball.position }
        if state.phase == .aiming || state.phase == .charging || state.phase == .complete {
            if anchor != state.ball.position {
                anchor = state.ball.position
                repositionElapsed = 0
            }
        }
        if state.phase != .aiming { practiceElapsed = nil }
        var pose = pose(for: state)
        if let time = practiceElapsed {
            let next = time + delta
            practiceElapsed = next < 0.8 ? next : nil
            if next < 0.8 { pose = .practice }
        }
        if !reducedMotion, repositionElapsed != nil, pose == .idle { pose = .walk }
        var frame = GolferAnimationFrame(pose: pose, groundPosition: anchor ?? state.ball.position)
        if !reducedMotion {
            switch pose {
            case .idle:
                frame.scaleY = 1 + sin(idleElapsed * .pi) * 0.009
            case .practice:
                frame.rotation = sin((practiceElapsed ?? 0) / 0.8 * .pi * 2) * 0.055
            case .backswing, .downswing:
                frame.rotation = sin(state.swingProgress * .pi * 2) * 0.018
            case .putt:
                frame.rotation = sin(state.swingProgress * .pi * 2) * 0.012
            case .walk:
                frame.verticalOffset = sin(min(0.3, repositionElapsed ?? 0) / 0.3 * .pi) * 1.2
            case .celebrate:
                frame.verticalOffset = max(0, sin(min(poseElapsed, 1.2) / 1.2 * .pi * 2)) * 2
            default: break
            }
            if let time = repositionElapsed {
                let next = time + delta
                repositionElapsed = next < 0.3 ? next : nil
                frame.opacity = 0.5 + min(1, next / 0.3) * 0.5
            }
        } else { repositionElapsed = nil }
        lastPhase = state.phase
        lastFrame = frame
        return frame
    }

    private func pose(for state: GameState) -> GolferPose {
        switch state.phase {
        case .aiming:
            if (state.lastOutcome == .outOfBounds || state.lastOutcome == .water), poseElapsed < 0.6 {
                return .disappointed
            }
            return .idle
        case .charging: return .aim
        case .swinging:
            if state.club == .putter { return .putt }
            if state.swingProgress < 0.12 { return .aim }
            return state.swingProgress < 0.72 ? .backswing : .downswing
        case .inFlight, .rolling:
            if state.activeShotElapsed < 0.065 { return state.club == .putter ? .putt : .impact }
            if state.activeShotElapsed < 0.35 { return state.club == .putter ? .putt : .followThrough }
            return .watchBall
        case .complete: return poseElapsed < 1.2 ? .celebrate : .idle
        case .paused: return lastFrame?.pose ?? .idle
        }
    }
}
