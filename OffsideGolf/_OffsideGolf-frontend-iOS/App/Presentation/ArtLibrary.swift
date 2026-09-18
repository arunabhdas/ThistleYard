import SpriteKit

/// Shared sheets remain resident across hole transitions; subtextures do not duplicate pixels.
@MainActor
final class ArtLibrary {
    private let environment = SKTexture(imageNamed: "coast_environment_sheet")
    private var ground: [SKTexture] = []
    private let names = ["tree", "pine", "windmill", "shed", "lookout", "arch", "farmhouse", "hide", "pavilion", "cabin", "lighthouse", "bridge"]
    init() {
        // SKShapeNode.fillTexture does not honor a sprite-sheet subtexture's UV rect.
        // Give shape fills independent pixel images so water/sand can never bleed into grass.
        if let source = UIImage(named: "terrain_sheet")?.cgImage {
            let width = source.width / 2, height = source.height / 2
            for index in 0..<4 {
                if let crop = source.cropping(to: CGRect(x: (index % 2)*width, y: (index / 2)*height, width: width, height: height)) {
                    ground.append(SKTexture(cgImage: crop))
                }
            }
        }
    }
    func environmentTexture(_ name: String) -> SKTexture? {
        guard let index = names.firstIndex(of: name) else { return nil }
        return SKTexture(rect: CGRect(x: Double(index % 4) / 4, y: Double(2 - index / 4) / 3,
                                      width: 0.25, height: 1.0 / 3), in: environment)
    }
    func groundTexture(_ index: Int) -> SKTexture {
        ground.indices.contains(index) ? ground[index] : SKTexture()
    }
    func preload() async { await SKTexture.preload([environment] + ground) }
}
