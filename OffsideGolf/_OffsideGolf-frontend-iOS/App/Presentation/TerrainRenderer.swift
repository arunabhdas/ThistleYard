import SpriteKit
import OffsideGolfCore

@MainActor
final class TerrainRenderer {
    let node = SKNode()
    private let art = ArtLibrary()
    private var foliage: [(SKSpriteNode, Vector2)] = []
    private var water: [SKShapeNode] = []
    private var phase = 0.0
    private let flagNode = SKNode()
    #if DEBUG
    func showDebugGeometry(hole: HoleDefinition,projection: WorldProjection) {
        for region in hole.regions {
            let path = CGMutablePath()
            for (index,point) in region.polygon.enumerated() {
                if index == 0 { path.move(to: projection.point(for: point)) }
                else { path.addLine(to: projection.point(for: point)) }
            }
            path.closeSubpath()
            let line = SKShapeNode(path: path);line.strokeColor = .magenta;line.lineWidth = 1;line.zPosition = 30;node.addChild(line)
            let center = region.polygon.reduce(Vector2.zero,+) * (1 / Double(region.polygon.count))
            let label = SKLabelNode(text: region.terrain.rawValue);label.fontSize = 8;label.fontColor = .black
            label.position = projection.point(for: center);label.zPosition = 31;node.addChild(label)
        }
        for tree in hole.trees {
            for radius in [tree.trunkRadius,tree.canopyRadius] {
                let circle = SKShapeNode(circleOfRadius: radius*projection.scale);circle.strokeColor = .magenta
                circle.position = projection.point(for: tree.position);circle.zPosition = 30;node.addChild(circle)
            }
        }
    }
    #endif

    func rebuild(hole: HoleDefinition, projection: WorldProjection, slopeGuide: Bool = true) {
        node.removeAllChildren(); foliage.removeAll(); water.removeAll()
        let b = hole.bounds
        polygon([.init(x: 0,y: 0),.init(x: b.width,y: 0),.init(x: b.width,y: b.height),.init(x: 0,y: b.height)],
                projection: projection, material: .rough)
        polygon(hole.fairway, projection: projection, material: .fairway)
        let greenPoints = (0..<48).map { i in
            let angle = Double(i) * .pi / 24
            return hole.green.center + Vector2(x: cos(angle) * hole.green.radiusX, y: sin(angle) * hole.green.radiusY)
        }
        polygon(greenPoints, projection: projection, material: .green)
        for region in hole.regions.sorted(by: { $0.terrain.precedence < $1.terrain.precedence }) {
            polygon(region.polygon, projection: projection, material: region.terrain)
        }
        if slopeGuide, hole.greenSlope.length > 0.0001 {
            for x in -1...1 {
                for y in -1...1 {
                    let p = hole.green.center + Vector2(x: Double(x) * 5, y: Double(y) * 5)
                    let downhill = hole.slope(at: p).normalized * -2
                    let a = projection.point(for: p), c = projection.point(for: p + downhill)
                    let path = CGMutablePath(); path.move(to: a); path.addLine(to: c)
                    let marker = SKShapeNode(path: path)
                    marker.strokeColor = .init(red: 0.15, green: 0.35, blue: 0.24, alpha: 0.38)
                    marker.lineWidth = 1; node.addChild(marker)
                    let tip = SKShapeNode(circleOfRadius: 1.1); tip.fillColor = marker.strokeColor
                    tip.strokeColor = .clear; tip.position = c; node.addChild(tip)
                }
            }
        }
        for decoration in hole.decorations {
            addSprite(decoration.asset, at: decoration.position, width: (decoration.asset == "tree" || decoration.asset == "pine" ? 15 : 27) * decoration.scale,
                      projection: projection, fades: decoration.asset == "tree" || decoration.asset == "pine")
        }
        for tree in hole.trees {
            addSprite(tree.canopyTop > 9 ? "pine" : "tree", at: tree.position, width: tree.canopyRadius * 3,
                      projection: projection, fades: true)
        }
        flag(at: projection.point(for: hole.pin))
    }
    func animate(elapsed: Double, ball: Vector2, reducedMotion: Bool, visualScale: CGFloat = 1) {
        phase += elapsed
        flagNode.setScale(visualScale)
        for (sprite, position) in foliage {
            sprite.alpha = position.distance(to: ball) < 12 ? 0.32 : 1
            sprite.zRotation = reducedMotion ? 0 : sin(phase * 0.6 + position.x) * 0.008
        }
        for shape in water { shape.alpha = reducedMotion ? 1 : 0.96 + sin(phase * 0.7) * 0.04 }
    }
    private func addSprite(_ name: String, at position: Vector2, width: Double, projection: WorldProjection, fades: Bool) {
        guard let texture = art.environmentTexture(name) else { return }
        let sprite = SKSpriteNode(texture: texture)
        sprite.size = CGSize(width: width * projection.scale, height: width * projection.scale)
        sprite.anchorPoint = CGPoint(x: 0.5,y: 0.14)
        sprite.position = projection.point(for: position)
        sprite.zPosition = 2 + (2_000 - position.y) * 0.001
        node.addChild(sprite)
        if fades { foliage.append((sprite,position)) }
    }
    private func polygon(_ points: [Vector2], projection: WorldProjection, material: TerrainMaterial) {
        guard let first = points.first else { return }
        let path = CGMutablePath(); path.move(to: projection.point(for: first))
        for point in points.dropFirst() { path.addLine(to: projection.point(for: point)) }
        path.closeSubpath()
        let shape = SKShapeNode(path: path)
        switch material {
        case .tee, .fairway: shape.fillTexture = art.groundTexture(0); shape.fillColor = .white
        case .green: shape.fillColor = .init(red: 0.74,green: 0.84,blue: 0.45,alpha: 1)
        case .rough, .deepRough, .outOfBounds:
            shape.fillTexture = art.groundTexture(1); shape.fillColor = material == .deepRough ? .init(white: 0.7,alpha: 1) : .white
        case .bunker: shape.fillTexture = art.groundTexture(2); shape.fillColor = .white
        case .water: shape.fillTexture = art.groundTexture(3); shape.fillColor = .white; water.append(shape)
        }
        shape.strokeColor = material == .water ? .init(red: 0.85,green: 0.91,blue: 0.79,alpha: 1) : .init(white: 1,alpha: material == .bunker ? 0.45 : 0.12)
        shape.lineWidth = material == .water || material == .bunker ? 2 : 0.8
        // At course scale, painted blades are texture rather than metre-tall objects.
        // A soft color wash keeps the lie boundaries readable without obvious tiling.
        let washColor: SKColor?
        switch material {
        case .tee, .fairway: washColor = .init(red: 0.58,green: 0.73,blue: 0.37,alpha: 0.64)
        case .rough, .outOfBounds: washColor = .init(red: 0.31,green: 0.48,blue: 0.32,alpha: 0.74)
        case .deepRough: washColor = .init(red: 0.22,green: 0.36,blue: 0.25,alpha: 0.74)
        default: washColor = nil
        }
        if let washColor {
            let wash = SKShapeNode(path: path)
            wash.fillColor = washColor; wash.strokeColor = .clear
            shape.addChild(wash)
        }
        node.addChild(shape)
    }
    private func flag(at pin: CGPoint) {
        flagNode.removeAllChildren()
        flagNode.position = pin
        flagNode.zPosition = 6
        node.addChild(flagNode)
        let pin = CGPoint.zero
        let cup = SKShapeNode(ellipseOf: CGSize(width: 5,height: 3))
        cup.fillColor = .init(red: 0.08,green: 0.22,blue: 0.17,alpha: 1); cup.strokeColor = .clear
        cup.position = pin; cup.zPosition = 6; flagNode.addChild(cup)
        let path = CGMutablePath(); path.move(to: pin); path.addLine(to: CGPoint(x: pin.x,y: pin.y+18))
        let pole = SKShapeNode(path: path); pole.strokeColor = .white; pole.lineWidth = 1.3; pole.zPosition = 6
        flagNode.addChild(pole)
        let flagPath = CGMutablePath();flagPath.move(to: CGPoint(x: pin.x,y: pin.y+18))
        flagPath.addLine(to: CGPoint(x: pin.x+12,y: pin.y+15));flagPath.addLine(to: CGPoint(x: pin.x,y: pin.y+11));flagPath.closeSubpath()
        let flag = SKShapeNode(path: flagPath);flag.fillColor = .init(red: 0.77,green: 0.32,blue: 0.21,alpha: 1)
        flag.strokeColor = .clear;flag.zPosition = 6;flagNode.addChild(flag)
    }
}
