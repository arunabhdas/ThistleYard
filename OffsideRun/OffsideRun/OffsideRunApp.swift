import SwiftUI

@main
struct OffsideRunApp: App {
    @State private var isRunning = false

    var body: some Scene {
        WindowGroup {
            Group {
                if isRunning {
                    GameView(onExit: { isRunning = false })
                        .transition(.opacity)
                } else {
                    LandingView(onStart: { isRunning = true })
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: isRunning)
            .preferredColorScheme(.dark)
        }
    }
}
