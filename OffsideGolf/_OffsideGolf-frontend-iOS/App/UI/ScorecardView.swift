import SwiftUI
import OffsideGolfCore

struct ScorecardView: View {
    let course: CourseManifest
    let scores: [SavedHoleScore]
    let complete: Bool
    let eligible: Bool
    let done: () -> Void
    @Environment(PlayerStore.self) private var player
    var body: some View {
        ScrollView {
            VStack(alignment: .leading,spacing: 20) {
                Text(complete ? "A day well played." : "Your scorecard")
                    .font(.system(.largeTitle,design: .serif,weight: .semibold))
                Text(course.name).font(.title2)
                if !eligible { Text("Practice round · Personal best unchanged").font(.footnote) }
                ForEach(course.holes) { hole in
                    HStack {
                        Text("\(hole.number)").frame(width: 24)
                        Text(hole.name)
                        Spacer()
                        Text("Par \(hole.par)").foregroundStyle(GolfTheme.secondary)
                        Text(scores.first(where: { $0.holeID == hole.id }).map { String($0.strokes) } ?? "—")
                            .fontWeight(.bold).frame(minWidth: 32)
                    }.font(.subheadline)
                    Divider()
                }
                HStack {
                    Text("Total").font(.headline)
                    Spacer()
                    Text("\(scores.reduce(0) { $0+$1.strokes }) strokes").font(.title2.bold())
                        .accessibilityIdentifier("scorecard.total")
                }
                if player.saving { Text("Saving your round…").font(.caption) }
                if let error = player.errorMessage {
                    Text(error).font(.footnote)
                    Button("Retry save",action: player.retrySave)
                }
                Button("Done",action: done).buttonStyle(GolfPrimaryButtonStyle())
                    .disabled(complete && (player.saving || player.errorMessage != nil))
                    .accessibilityIdentifier("scorecard.done")
            }.padding(24).frame(maxWidth: 650).frame(maxWidth: .infinity)
        }.background(GolfTheme.cream).foregroundStyle(GolfTheme.pine)
    }
}
