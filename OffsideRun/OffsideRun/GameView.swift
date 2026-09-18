import SpriteKit
import SwiftUI

struct GameView: View {
    var onExit: () -> Void = {}

    @State private var scene = OffsideRunScene(size: CGSize(width: 390, height: 844))

    var body: some View {
        // The GeometryReader stays inside the safe area so it can report the
        // insets; the SpriteView underneath extends to the screen edges and the
        // scene keeps its HUD clear of the notch and home indicator.
        GeometryReader { geometry in
            SpriteView(
                scene: scene,
                options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes]
            )
            .ignoresSafeArea()
            .onAppear {
                scene.scaleMode = .resizeFill
                scene.onExit = onExit
                scene.safeInsets = insets(from: geometry.safeAreaInsets)
            }
            .onChange(of: geometry.safeAreaInsets) { _, newValue in
                scene.safeInsets = insets(from: newValue)
            }
        }
    }

    private func insets(from edges: EdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets(top: edges.top, left: edges.leading, bottom: edges.bottom, right: edges.trailing)
    }
}
