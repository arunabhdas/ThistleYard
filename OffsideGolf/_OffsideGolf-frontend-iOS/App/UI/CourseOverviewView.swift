import SwiftUI
import OffsideGolfCore

struct CourseOverviewView: View {
    let course: CourseManifest

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("A walk through\nWhispering Coast")
                        .font(.system(.largeTitle, design: .serif, weight: .semibold))
                        .foregroundStyle(GolfTheme.pine)
                    Text("From the first wildflower to the last lighthouse view.")
                        .foregroundStyle(GolfTheme.secondary)
                    CourseFacts(par: course.totalPar, yards: course.totalDistanceYards)
                }
                LazyVStack(spacing: 12) {
                    ForEach(course.holes) { hole in
                        NavigationLink {
                            HolePreviewView(hole: hole, course: course)
                        } label: {
                            holeRow(hole)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("hole.\(hole.id)")
                        .accessibilityLabel("Hole \(hole.number), \(hole.name), par \(hole.par), \(hole.distanceYards) yards")
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: 780)
            .frame(maxWidth: .infinity)
        }
        .background(GolfTheme.cream)
        .navigationTitle("The course")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

    private func holeRow(_ hole: HoleSummary) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(hole.number.formatted(.number.precision(.integerLength(2))))
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(GolfTheme.pine)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                Text(hole.name)
                    .font(.headline)
                    .foregroundStyle(GolfTheme.pine)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Par \(hole.par) · \(hole.distanceYards) yd")
                    .font(.subheadline)
                    .foregroundStyle(GolfTheme.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(GolfTheme.secondary)
                .padding(.top, 6)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 20))
    }
}
