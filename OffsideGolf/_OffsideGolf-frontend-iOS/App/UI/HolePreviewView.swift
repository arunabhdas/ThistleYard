import SwiftUI
import OffsideGolfCore

struct HolePreviewView: View {
    @Environment(PlayerStore.self) private var player
    let hole: HoleSummary
    var course: CourseManifest? = nil
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                Group {
                    if geometry.size.width > geometry.size.height && !dynamicTypeSize.isAccessibilitySize {
                        HStack(alignment: .center, spacing: 28) {
                            CourseIllustration(seed: hole.number)
                                .frame(width: geometry.size.width * 0.44, height: max(220, geometry.size.height - 48))
                            details
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 28) {
                            CourseIllustration(seed: hole.number)
                                .frame(height: max(220, min(420, geometry.size.height * 0.5)))
                            details
                        }
                    }
                }
                .padding(24)
                .frame(maxWidth: 1_100)
                .frame(maxWidth: .infinity)
            }
            .background(GolfTheme.cream)
        }
        .navigationTitle("Hole \(hole.number)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("COURSE PREVIEW")
                .font(.caption.weight(.bold))
                .tracking(2)
                .foregroundStyle(GolfTheme.secondary)
                .accessibilityIdentifier("hole.preview.status")
            Text(hole.name)
                .font(.system(.largeTitle, design: .serif, weight: .semibold))
                .foregroundStyle(GolfTheme.pine)
                .fixedSize(horizontal: false, vertical: true)
            CourseFacts(par: hole.par, yards: hole.distanceYards)
            if !hole.id.isEmpty {
                NavigationLink("Play this hole") { GameContainer(hole: hole, course: course) }
                    .buttonStyle(GolfPrimaryButtonStyle())
                    .accessibilityIdentifier("play.meadow")
                    .disabled(!player.loaded || player.storageBlocked)
            }
            Text(hole.summary)
                .font(.body)
                .foregroundStyle(GolfTheme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Label(hole.landmark, systemImage: "binoculars")
                .font(.subheadline)
                .foregroundStyle(GolfTheme.pine)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(GolfTheme.mist, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}
