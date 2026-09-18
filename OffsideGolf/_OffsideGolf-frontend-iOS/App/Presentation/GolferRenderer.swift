import SpriteKit
import ImageIO
import OffsideGolfCore

/// Eight original right-handed body facings with shared palette customization.
/// Directional art is selected, never mirrored; the simulation still owns all shot timing.
@MainActor
final class GolferRenderer {
    let node = SKNode()
    private let sprite = SKSpriteNode()
    private let hair = SKNode()
    private let shadow = SKShapeNode(ellipseOf: CGSize(width: 25, height: 6))
    private var animation = GolferAnimationController()
    private var textureCache: [GolferFacing: [GolferPose: SKTexture]] = [:]
    private var recentlyUsed: [GolferFacing] = []
    private let sheetProvider: (GolferFacing) -> SKTexture
    private(set) var facing: GolferFacing?
    private var lastPose: GolferPose?
    private var lastAppearance: GolferAppearance?
    private let paletteShader = SKShader(source: """
        void main() {
            vec4 texel = texture2D(u_texture, v_tex_coord);
            float alpha = texel.a;
            vec3 rgb = texel.rgb / max(alpha, 0.001);
            // Separate painted green cloth from warm skin, preserving highlights and outlines.
            float cloth = smoothstep(0.025, 0.085, rgb.g - rgb.r)
                        * smoothstep(0.025, 0.09, rgb.g - rgb.b);
            float skin = smoothstep(0.10, 0.20, rgb.r - rgb.g)
                       * smoothstep(0.075, 0.16, rgb.g - rgb.b)
                       * smoothstep(0.28, 0.50, rgb.r);
            // Brown shorts are less saturated than skin; cap, club and eyes stay original.
            skin *= 1.0 - smoothstep(0.72, 0.85, rgb.g / max(rgb.r, 0.001));
            vec3 clothColor = rgb * u_outfit / vec3(0.14, 0.40, 0.24);
            vec3 skinColor = rgb * u_skin / vec3(0.94, 0.59, 0.30);
            rgb = mix(rgb, clamp(clothColor, 0.0, 1.0), cloth * u_outfitBlend);
            rgb = mix(rgb, clamp(skinColor, 0.0, 1.0), skin * u_skinBlend);
            gl_FragColor = vec4(rgb * alpha, alpha) * v_color_mix.a;
        }
        """)

    init(bundle: Bundle = .main, sheetProvider: ((GolferFacing) -> SKTexture)? = nil) {
        self.sheetProvider = sheetProvider ?? { Self.loadSheet($0, bundle: bundle) }
        sprite.size = CGSize(width: 58, height: 58)
        sprite.shader = paletteShader
        shadow.fillColor = .black.withAlphaComponent(0.17)
        shadow.strokeColor = .clear
        node.addChild(shadow)
        node.addChild(hair)
        node.addChild(sprite)
        updateAppearance(GolferAppearance())
    }

    func practiceSwing() { animation.startPractice() }
    func cancelPractice() { animation.cancelPractice() }

    /// `elapsed` is a frame delta, not wall-clock time. Pass zero for non-frame state updates.
    func render(state: GameState, projection: WorldProjection, appearance: GolferAppearance,
                reducedMotion: Bool, elapsed: Double, visualScale: CGFloat = 1) {
        let frame = animation.sample(state: state, reducedMotion: reducedMotion, elapsed: elapsed)
        let feetPoint = projection.point(for: frame.groundPosition)
        let selectedFacing = GolferFacing.forAim(state.aimDirection, fallback: facing ?? .east)
        let facingChanged = selectedFacing != facing
        let bodyPoint = projection.point(for: frame.groundPosition + selectedFacing.bodyDirection(forAim: state.aimDirection))
        let screenDirection = Vector2(x: bodyPoint.x - feetPoint.x, y: bodyPoint.y - feetPoint.y).normalized
        // Stand opposite the projected body direction, at a constant screen-space distance.
        // Both stance and sprite size compensate for SKCamera zoom.
        let safeScale = visualScale.isFinite && visualScale > 0 ? visualScale : 1
        node.setScale(safeScale)
        node.position = CGPoint(x: feetPoint.x - screenDirection.x * 20 * safeScale,
                                y: feetPoint.y - screenDirection.y * 20 * safeScale)
        node.alpha = frame.opacity
        sprite.position.y = frame.verticalOffset
        sprite.zRotation = frame.rotation
        sprite.yScale = frame.scaleY
        if lastPose != frame.pose || facingChanged {
            sprite.texture = texture(for: frame.pose, facing: selectedFacing)
            sprite.anchorPoint = selectedFacing.footAnchor(for: frame.pose)
            lastPose = frame.pose
        }
        facing = selectedFacing
        if lastAppearance != appearance || facingChanged { updateAppearance(appearance) }
        let nape = selectedFacing.napeAnchor(for: frame.pose), foot = selectedFacing.footAnchor(for: frame.pose)
        hair.position = CGPoint(x: (nape.x - foot.x) * 58, y: (nape.y - foot.y) * 58 + frame.verticalOffset)
        hair.zRotation = frame.rotation
        hair.yScale = frame.scaleY
    }

    /// Three sheets bound renderer-owned image memory as the player rotates through all eight facings.
    private func texture(for pose: GolferPose, facing: GolferFacing) -> SKTexture? {
        recentlyUsed.removeAll { $0 == facing }
        recentlyUsed.append(facing)
        if textureCache[facing] == nil {
            let sheet = sheetProvider(facing)
            sheet.filteringMode = .linear
            var cells: [GolferPose: SKTexture] = [:]
            for pose in GolferPose.allCases {
                let texture = SKTexture(rect: facing.textureRect(for: pose), in: sheet)
                texture.filteringMode = .linear
                cells[pose] = texture
            }
            textureCache[facing] = cells
        }
        while recentlyUsed.count > 3 {
            textureCache.removeValue(forKey: recentlyUsed.removeFirst())
        }
        return textureCache[facing]?[pose]
    }

    private static func loadSheet(_ facing: GolferFacing, bundle: Bundle) -> SKTexture {
        // Avoid imageNamed's process-wide image cache defeating the three-sheet LRU.
        func decode(_ name: String) -> SKTexture? {
            guard let url = bundle.url(forResource: name, withExtension: "png"),
                  let source = CGImageSourceCreateWithURL(url as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
            return SKTexture(cgImage: image)
        }
        if let sheet = decode(facing.sheetName) { return sheet }
        // A damaged export is a diagnosed asset error, never an unexplained invisible golfer.
        let message = "Could not decode bundled golfer sheet \(facing.sheetName).png"
        NSLog("%@", message)
        assertionFailure(message)
        if facing != .southEast, let fallback = decode(GolferFacing.southEast.sheetName) { return fallback }
        return SKTexture()
    }

    private func updateAppearance(_ appearance: GolferAppearance) {
        lastAppearance = appearance
        let outfits: [SIMD3<Float>] = [
            .init(0.14, 0.40, 0.24), .init(0.24, 0.45, 0.66),
            .init(0.72, 0.30, 0.22), .init(0.56, 0.38, 0.62)
        ]
        let skins: [SIMD3<Float>] = [
            .init(0.94, 0.59, 0.30), .init(0.96, 0.74, 0.57),
            .init(0.66, 0.38, 0.21), .init(0.39, 0.23, 0.15)
        ]
        let outfit = min(3, max(0, appearance.outfitPalette))
        let skin = min(3, max(0, appearance.skinPalette))
        paletteShader.uniforms = [
            SKUniform(name: "u_outfit", vectorFloat3: outfits[outfit]),
            SKUniform(name: "u_skin", vectorFloat3: skins[skin]),
            SKUniform(name: "u_outfitBlend", float: outfit == 0 ? 0 : 1),
            SKUniform(name: "u_skinBlend", float: skin == 0 ? 0 : 1)
        ]
        hair.removeAllChildren()
        let style = min(2, max(0, appearance.hairStyle))
        guard style != 0 else { return } // Original cap and cropped hair are the first silhouette.
        let color = SKColor(red: 0.22, green: 0.12, blue: 0.065, alpha: 1)
        let side = facing?.hairFallsRight == true ? 1.0 : -1.0
        hair.zPosition = facing?.showsBackOfHead == true ? 1 : 0
        if style == 1 {
            for index in 0..<3 {
                let curl = SKShapeNode(circleOfRadius: 2.3)
                curl.position = CGPoint(x: side * Double(index) * 1.2, y: -Double(index) * 2.0)
                curl.fillColor = color; curl.strokeColor = .clear
                hair.addChild(curl)
            }
        } else {
            let lock = SKShapeNode(ellipseOf: CGSize(width: 5.5, height: 12))
            lock.position = CGPoint(x: side, y: -5)
            lock.zRotation = side * 0.16
            lock.fillColor = color; lock.strokeColor = .clear
            hair.addChild(lock)
        }
    }
}
