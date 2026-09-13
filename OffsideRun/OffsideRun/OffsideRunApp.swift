import SwiftUI

@main
struct OffsideRunApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .ignoresSafeArea()
                .preferredColorScheme(.dark)
        }
    }
}
