import SwiftUI
import OffsideGolfCore

struct MainMenuView: View {
    let course: CourseManifest
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(PlayerStore.self) private var player
    @State private var replaceRound = false
    @State private var startRound = false

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                if geometry.size.width > geometry.size.height && !dynamicTypeSize.isAccessibilitySize {
                    HStack(spacing: 32) {
                        CourseIllustration(seed: 0)
                            .frame(width: geometry.size.width * 0.43, height: max(240, geometry.size.height - 48))
                        introduction
                    }
                    .padding(24)
                    .frame(maxWidth: 1_100)
                    .frame(maxWidth: .infinity)
                } else {
                    VStack(alignment: .leading, spacing: 24) {
                        brand
                        CourseIllustration(seed: 0)
                            .frame(height: min(380, max(220, geometry.size.height * 0.40)))
                        invitation
                    }
                    .padding(24)
                    .frame(maxWidth: 700)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        // Confine scrolling artwork and type to the safe viewport. A short fade
        // softens the top edge while the opaque cream stays behind system chrome.
        .mask {
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                    .frame(height: 12)
                Rectangle().fill(.black)
            }
        }
        .background(GolfTheme.cream.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $startRound) {
            if let first = course.holes.first { GameContainer(hole: first, course: course, mode: .round) }
        }
        .confirmationDialog("Start a new round?", isPresented: $replaceRound, titleVisibility: .visible) {
            Button("Replace saved round", role: .destructive) { startRound = true }
        } message: { Text("Your personal bests are kept. The unfinished round will be replaced.") }
    }

    private var brand: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("OFFSIDEGOLF", systemImage: "leaf.fill")
                .font(.subheadline.weight(.bold))
                .tracking(3)
            Text("Small swings.\nBrighter days.")
                .font(.system(.largeTitle, design: .serif, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(GolfTheme.pine)
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 24) {
            brand
            invitation
        }
        .frame(maxWidth: 480, alignment: .leading)
    }

    private var invitation: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(course.name)
                .font(.system(.title2, design: .serif, weight: .semibold))
                .foregroundStyle(GolfTheme.pine)
            Text(course.summary)
                .font(.body)
                .foregroundStyle(GolfTheme.secondary)
            CourseFacts(par: course.totalPar, yards: course.totalDistanceYards)
            if let error = player.errorMessage {
                Text(error).font(.footnote).foregroundStyle(GolfTheme.clay)
                if player.recovery != nil {
                    Button("Recover previous checkpoint", action: player.recoverBackup)
                } else if player.storageBlocked {
                    Button("Retry opening save") { Task { await player.retryLoad() } }
                } else { Button("Retry save", action: player.retrySave) }
            }
            if let round = player.save.round,
               let current = course.holes.first(where: { $0.id == round.currentHoleID }) {
                NavigationLink("Continue · Hole \(current.number)") {
                    GameContainer(hole: current, course: course, mode: .resume)
                }
                .buttonStyle(GolfPrimaryButtonStyle())
                .accessibilityIdentifier("round.continue")
            }
            if let firstHole = course.holes.first {
                NavigationLink {
                    GameContainer(hole: firstHole, course: course)
                } label: {
                    Label("Play Meadow Start", systemImage: "flag.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(GolfPrimaryButtonStyle())
                .accessibilityIdentifier("play.meadow")
                .disabled(player.storageBlocked)
            }
            Button("Play all nine holes") {
                if player.save.round != nil { replaceRound = true } else { startRound = true }
            }
            .buttonStyle(GolfPrimaryButtonStyle())
            .disabled(!player.loaded || player.storageBlocked)
            .accessibilityIdentifier("round.new")
            NavigationLink {
                CourseOverviewView(course: course)
            } label: {
                HStack {
                    Text("Explore the course")
                    Spacer(minLength: 12)
                    Image(systemName: "arrow.right")
                }
            }
            .frame(minHeight: 44)
            .accessibilityIdentifier("course.explore")
            Text("9 holes · A little closer to the coast")
                .font(.footnote)
                .foregroundStyle(GolfTheme.secondary)
            HStack {
                NavigationLink("Your golfer") { GolferCustomizationView() }.disabled(player.storageBlocked)
                Spacer()
                NavigationLink("Settings") { SettingsView() }.accessibilityIdentifier("menu.settings").disabled(player.storageBlocked)
            }.frame(minHeight: 44)
            if let best = player.save.profile.records.first(where: { $0.matches(courseID: course.id, contentVersion: course.contentVersion, physicsVersion: 2) })?.bestTotalStrokes {
                Text("Personal best · \(best) strokes").font(.subheadline)
            }
        }
    }
}
