import SpriteKit
import SwiftUI

struct GameView: View {
    @State private var scene = OffsideRunScene(size: CGSize(width: 390, height: 844))

    var body: some View {
        SpriteView(
            scene: scene,
            options: [.ignoresSiblingOrder, .shouldCullNonVisibleNodes]
        )
        .ignoresSafeArea()
        .onAppear {
            scene.scaleMode = .resizeFill
        }
    }
}
