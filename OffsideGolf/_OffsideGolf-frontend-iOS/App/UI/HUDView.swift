import SwiftUI
import OffsideGolfCore

struct HUDView: View {
    let session: GameSession
    let hole: HoleSummary
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Hole \(hole.number) · \(hole.name)").font(.headline)
                    HStack(spacing: 6) {
                        Text("Par \(hole.par)")
                        if session.hole.wind.speedMPH == 0 { Text("· Calm") }
                        else {
                            Image(systemName: "arrow.up").rotationEffect(.degrees(session.hole.wind.towardDegrees))
                                .accessibilityHidden(true)
                            Text("\(session.hole.wind.speedMPH, specifier: "%.0f") mph")
                                .accessibilityLabel("Wind \(session.hole.wind.speedMPH, specifier: "%.0f") miles per hour toward \(Int(session.hole.wind.towardDegrees)) degrees clockwise from north")
                        }
                    }.font(.subheadline).foregroundStyle(GolfTheme.secondary)
                }
                Spacer(minLength: 8)
                Button { session.send(.pause) } label: {
                    Image(systemName: "pause.fill").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Pause")
                .accessibilityIdentifier("game.pause")
            }
            HStack {
                Text("Strokes \(session.hud.strokes)").accessibilityIdentifier("game.strokes")
                Spacer()
                Text("\(session.hud.distanceYards) yd to pin")
            }.font(.subheadline.monospacedDigit().weight(.semibold))
            Text(session.hud.phaseLabel)
                .font(.caption)
                .foregroundStyle(GolfTheme.secondary)
                .accessibilityIdentifier("game.phase")
            if session.hud.outcome == .outOfBounds {
                Text("Out of bounds · +1 penalty · Returned to your last lie")
                    .font(.caption).foregroundStyle(GolfTheme.clay)
            }
            if session.hud.outcome == .water {
                Text("Water · +1 penalty · Moved to a safe drop").font(.caption).foregroundStyle(GolfTheme.clay)
            }
        }
    }
}
