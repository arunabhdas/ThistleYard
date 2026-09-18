import SwiftUI
import SpriteKit
import OffsideGolfCore

enum PlayMode { case practice, round, resume }

struct GameContainer: View {
    let hole: HoleSummary
    var course: CourseManifest? = nil
    var mode: PlayMode = .practice
    @State private var session: GameSession?
    @State private var currentHole: HoleSummary?
    @State private var loadFailed = false
    @State private var restoreFailed = false
    @State private var completed: [SavedHoleScore] = []
    @State private var roundID = UUID()
    @State private var assisted = false
    @State private var settledCheckpoint: GameCheckpoint?
    @State private var roundComplete = false
    @State private var practiceResultRecorded = false
    @State private var showScorecard = false
    @State private var confirmRestart = false
    @State private var tutorialDismissed = false
    #if DEBUG
    @State private var showDebug = false
    #endif
    @Environment(PlayerStore.self) private var player
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    private var displayedHole: HoleSummary { currentHole ?? hole }

    var body: some View {
        Group {
            if roundComplete, let course {
                ScorecardView(course: course,scores: completed,complete: true,eligible: !assisted) {
                    dismiss()
                }
            } else if let session {
                GeometryReader { geometry in
                    ZStack {
                        layout(session, size: geometry.size)
                            .accessibilityHidden(session.hud.phase == .paused || session.hud.result != nil)
                        if session.hud.phase == .paused {
                            modal {
                                Text("Take a breather").font(.title2.bold())
                                Button("Resume", action: session.resume).accessibilityIdentifier("game.resume")
                                Button("Restart hole") { confirmRestart = true }
                                    .accessibilityIdentifier("game.restart")
                                if mode != .practice {
                                    Text("Restarting makes this a practice round, so it won’t replace your personal best.").font(.footnote)
                                }
                                Button("Leave hole") { saveCheckpoint(session.checkpoint); dismiss() }
                                #if DEBUG
                                Button("Developer tools") { showDebug = true }.accessibilityIdentifier("debug.open")
                                #endif
                                Text(mode == .practice ? "Practice starts fresh next time." : "Your round is saved here.").font(.footnote)
                            }
                        } else if let result = session.hud.result {
                            modal {
                                Text(displayedHole.name.uppercased()).font(.caption.weight(.bold)).tracking(2)
                                Text(result.title).font(.system(.largeTitle,design: .serif,weight: .semibold))
                                    .accessibilityIdentifier("result.title")
                                Text("\(result.strokes) strokes · Par \(result.par)")
                                    .font(.title3).accessibilityIdentifier("result.strokes")
                                Text(result.relativeToPar == 0 ? "Right on par." : "\(abs(result.relativeToPar)) \(result.relativeToPar < 0 ? "under" : "over") par.")
                                if mode == .practice {
                                    Button("Play again",action: session.restart).accessibilityIdentifier("result.replay")
                                    Button("Back to the course") { dismiss() }.accessibilityIdentifier("result.done")
                                } else {
                                    Button(displayedHole.number == 9 ? "View course score" : "Next hole",action: advanceHole)
                                        .disabled(player.saving || player.errorMessage != nil)
                                        .accessibilityIdentifier("result.next")
                                }
                                saveStatus
                            }
                        }
                    }
                    .onChange(of: geometry.size) { _, _ in session.send(.cancelCharge) }
                }
                .alert("Restart this hole?",isPresented: $confirmRestart) {
                    Button("Restart hole",role: .destructive) {
                        if mode != .practice { assisted = true }
                        session.restart()
                    }.accessibilityIdentifier("game.restart.confirm")
                    Button("Keep playing",role: .cancel) { }
                } message: {
                    Text("This hole’s strokes will be reset. Restarted rounds do not replace personal bests.")
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase != .active {
                        session.send(.pause); player.audio.suspend()
                        player.flushForBackground()
                    }
                    else { player.audio.resume() }
                }
                .onDisappear { session.send(.pause); player.audio.suspend() }
                .sheet(isPresented: $showScorecard) {
                    if let course {
                        ScorecardView(course: course,scores: completed,complete: false,eligible: !assisted) {
                            showScorecard = false
                        }
                    }
                }
                #if DEBUG
                .sheet(isPresented: $showDebug) {
                    DebugToolsView(session: session) { number in
                        assisted = true
                        if let summary = course?.holes.first(where: { $0.number == number }) {
                            session.onCheckpoint = nil; load(next: summary)
                        }
                    }
                }
                #endif
            } else if loadFailed || restoreFailed {
                ContentUnavailableView {
                    Label(restoreFailed ? "This checkpoint needs attention" : "The meadow needs a moment",systemImage: "leaf")
                } description: {
                    Text(restoreFailed ? "Your saved round has been kept. You can recover its last settled position as a practice round." : "We couldn’t open this hole. Please try again.")
                } actions: {
                    if restoreFailed, player.save.round?.lastSettledCheckpoint != nil {
                        Button("Recover last settled position") { load(recover: true) }
                    } else if !restoreFailed { Button("Try again") { load() } }
                    Button("Back") { dismiss() }
                }
            } else { ProgressView("Opening the meadow…") }
        }
        .background(GolfTheme.cream)
        .foregroundStyle(GolfTheme.pine)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .task { if session == nil { load() } }
    }

    @ViewBuilder private func layout(_ session: GameSession,size: CGSize) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView {
                VStack(spacing: 12) {
                    header(session)
                    courseView(session).frame(height: 300)
                    controls(session)
                }.padding(16)
            }
        } else if size.width > size.height {
            HStack(spacing: 12) {
                if player.settings.leftHanded { controls(session).frame(width: 270) }
                VStack(spacing: 8) { header(session);courseView(session) }
                if !player.settings.leftHanded { controls(session).frame(width: 270) }
            }.padding(12)
        } else {
            VStack(spacing: 10) {
                header(session)
                courseView(session)
                controls(session)
            }.padding(16)
        }
    }
    private func header(_ session: GameSession) -> some View {
        VStack(spacing: 5) {
            HUDView(session: session,hole: displayedHole)
            if !player.save.profile.tutorialCompleted && !tutorialDismissed && displayedHole.number <= 3 && session.hud.canAim {
                HStack(alignment: .top) {
                    Text(tutorialText(session)).font(.caption)
                    Spacer(minLength: 4)
                    Button("Got it") {
                        tutorialDismissed = true
                        if displayedHole.number == 3 { player.finishTutorial() }
                    }.font(.caption.bold()).frame(minHeight: 44)
                }.padding(.horizontal,10).background(GolfTheme.mist,in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
    private func controls(_ session: GameSession) -> some View {
        ScrollView {
            SwingControls(session: session)
            let footerLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading,spacing: 16))
                : AnyLayout(HStackLayout(spacing: 8))
            footerLayout {
                Button("Overview") { session.scene.toggleOverview() }
                if !dynamicTypeSize.isAccessibilitySize { Spacer() }
                if course != nil { Button("Scorecard") { showScorecard = true } }
                else { Button("Practice swing") { session.scene.practiceSwing() }.disabled(!session.hud.canAim) }
            }.font(.caption).frame(minHeight: 44)
            saveStatus
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: dynamicTypeSize.isAccessibilitySize ? 700 : 330)
    }
    private func tutorialText(_ session: GameSession) -> String {
        if session.hud.club == .putter { return "On the green! Choose a short range, aim, then use a gentle pull." }
        if displayedHole.number == 2 { return "Try the club selector. Shorter clubs give you a more controlled approach." }
        if displayedHole.number == 3 { return "Wind pushes airborne shots toward the arrow. Leave room on the safe side." }
        return session.hud.strokes == 0 ? "Tap the course to aim. Pull down on the pad, then release to swing." : "The ball is ready. Aim toward the flag and try another small swing."
    }
    @ViewBuilder private var saveStatus: some View {
        if mode != .practice && player.saving { Text("Saving…").font(.caption) }
        if let error = player.errorMessage {
            Text(error).font(.caption).foregroundStyle(GolfTheme.clay)
            if !player.storageBlocked { Button("Retry save",action: player.retrySave) }
        }
    }
    private func courseView(_ session: GameSession) -> some View {
        GameSceneHost(scene: session.scene,paused: session.hud.phase == .paused)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .accessibilityLabel("\(displayedHole.name). Tap the course to aim, or use the aim controls below.")
            .accessibilityIdentifier("game.course")
    }
    private func modal<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            GolfTheme.pine.opacity(0.4).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16,content: content).buttonStyle(GolfPrimaryButtonStyle()).padding(24)
                    .frame(maxWidth: 430).background(GolfTheme.cream,in: RoundedRectangle(cornerRadius: 24))
                    .padding(24).frame(maxWidth: .infinity)
            }.fixedSize(horizontal: false,vertical: true)
        }.accessibilityAddTraits(.isModal)
    }
    private func load(recover: Bool = false, next: HoleSummary? = nil) {
        do {
            let selected = next ?? displayedHole
            guard let url = Bundle.main.url(forResource: selected.id,withExtension: "json") else { throw CocoaError(.fileNoSuchFile) }
            let definition = try HoleDefinition.decode(Data(contentsOf: url))
            guard definition.id == selected.id,definition.par == selected.par else { throw CocoaError(.fileReadCorruptFile) }
            var restored: GameReducer?
            if mode == .resume, next == nil, selected.id == hole.id, let round = player.save.round {
                do {
                    if recover,let checkpoint = round.lastSettledCheckpoint {
                        restored = try GameReducer(hole: definition,recoveringSettledCheckpoint: checkpoint)
                        assisted = true
                    } else { restored = try GameReducer(hole: definition,checkpoint: round.checkpoint);assisted = round.assisted }
                    if restored?.state.phase == .paused { restored?.send(.resume) }
                    roundID = round.id
                    completed = round.completedHoles.filter { $0.holeID != selected.id }
                    settledCheckpoint = round.lastSettledCheckpoint
                } catch { restoreFailed = true;return }
            }
            var settings = player.settings
            settings.reducedMotion = settings.reducedMotion || systemReduceMotion
            let created = GameSession(hole: definition,restored: restored,settings: settings,appearance: player.appearance,audio: player.audio)
            currentHole = selected;session = created
            created.onCheckpoint = { checkpoint in saveCheckpoint(checkpoint) }
            created.onAssisted = { assisted = true }
            if mode != .practice {
                created.mayAdvance = { !player.saving && player.errorMessage == nil && !player.storageBlocked }
            }
            if restored == nil { settledCheckpoint = created.checkpoint }
            loadFailed = false;restoreFailed = false;tutorialDismissed = false
            player.audio.resume();player.audio.startAmbience();player.audio.startMusic()
            saveCheckpoint(created.checkpoint)
        } catch {
            currentHole = next ?? displayedHole
            session = nil
            loadFailed = true
        }
    }
    private func saveCheckpoint(_ checkpoint: GameCheckpoint) {
        guard let course, let session else { return }
        if mode == .practice {
            if let result = session.hud.result, !practiceResultRecorded {
                practiceResultRecorded = true
                player.recordPractice(SavedHoleScore(holeID: displayedHole.id,strokes: result.strokes,par: result.par),
                                      courseID: course.id,contentVersion: session.hole.contentVersion,
                                      physicsVersion: session.hole.physicsVersion,eligible: !assisted)
            } else if session.hud.result == nil { practiceResultRecorded = false }
            return
        }
        if session.hud.phase == .aiming || session.hud.phase == .complete { settledCheckpoint = checkpoint }
        var scores = completed
        if let result = session.hud.result, !scores.contains(where: { $0.holeID == displayedHole.id }) {
            scores.append(SavedHoleScore(holeID: displayedHole.id,strokes: result.strokes,par: result.par))
        }
        player.setRound(RoundProgress(id: roundID,courseID: course.id,contentVersion: checkpoint.contentVersion,
                                     currentHoleID: displayedHole.id,completedHoles: scores,checkpoint: checkpoint,
                                     assisted: assisted,lastSettledCheckpoint: settledCheckpoint))
    }
    private func advanceHole() {
        guard let result = session?.hud.result,let course else { return }
        completed.removeAll { $0.holeID == displayedHole.id }
        completed.append(SavedHoleScore(holeID: displayedHole.id,strokes: result.strokes,par: result.par))
        if displayedHole.number == 9 {
            session?.onCheckpoint = nil
            player.finishRound(completed,courseID: course.id,contentVersion: course.contentVersion,
                               physicsVersion: session?.hole.physicsVersion ?? 2,eligible: !assisted && completed.count == 9)
            roundComplete = true
        } else if let next = course.holes.first(where: { $0.number == displayedHole.number + 1 }) {
            session?.onCheckpoint = nil
            load(next: next)
        }
    }
}

private struct GameSceneHost: UIViewRepresentable {
    let scene: GameScene
    let paused: Bool
    func makeUIView(context: Context) -> SKView {
        let view = SKView();view.preferredFramesPerSecond = 60;view.presentScene(scene)
        #if DEBUG
        view.showsFPS = ProcessInfo.processInfo.arguments.contains("--show-fps")
        view.showsNodeCount = view.showsFPS
        #endif
        return view
    }
    func updateUIView(_ view: SKView,context: Context) {
        if view.scene !== scene { view.presentScene(scene) }
        view.isPaused = paused
    }
    static func dismantleUIView(_ view: SKView,coordinator: ()) { view.isPaused = true;view.presentScene(nil) }
}
