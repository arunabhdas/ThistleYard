import SwiftUI
import OffsideGolfCore

struct HoleResultView: View {
    let result: HoleResult
    let replay: () -> Void
    let done: () -> Void
    var body: some View {
        Text("MEADOW START").font(.caption.weight(.bold)).tracking(2)
        Image(systemName: "flag.checkered").font(.largeTitle)
        Text(result.title)
            .font(.system(.largeTitle, design: .serif, weight: .semibold))
            .accessibilityIdentifier("result.title")
        Text("\(result.strokes) strokes · Par \(result.par)")
            .font(.title3).accessibilityIdentifier("result.strokes")
        Text(result.relativeToPar == 0 ? "Right on par." : "\(abs(result.relativeToPar)) \(result.relativeToPar < 0 ? "under" : "over") par.")
        Button("Play again", action: replay).accessibilityIdentifier("result.replay")
        Button("Back to the course", action: done).accessibilityIdentifier("result.done")
    }
}
