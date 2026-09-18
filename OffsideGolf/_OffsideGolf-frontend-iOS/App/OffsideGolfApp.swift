import SwiftUI

@main
struct OffsideGolfApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var coordinator = AppCoordinator()
    @State private var player = Self.makePlayerStore()

    var body: some Scene {
        WindowGroup {
            RootView(coordinator: coordinator)
                .environment(player)
                .task { await player.load() }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { player.flushForBackground(); player.audio.suspend() }
                }
                .tint(GolfTheme.pine)
                .preferredColorScheme(.light)
        }
    }

    private static func makePlayerStore() -> PlayerStore {
        #if DEBUG
        if let identifier = ProcessInfo.processInfo.environment["OFFSIDE_UI_TEST_SAVE"],
           UUID(uuidString: identifier) != nil {
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent("uitest-\(identifier)")
            return PlayerStore(repository: FileGameRepository(directory: directory))
        }
        #endif
        return PlayerStore()
    }
}
