import SpriteKit
import UIKit

final class OffsideRunScene: SKScene {
    private enum Lane: Int, CaseIterable {
        case left = -1
        case center = 0
        case right = 1
    }

    private enum ItemKind {
        case crown
        case shard
        case heart
        case log
        case arch
        case maskling
        case thorn
    }

    private final class RunItem {
        let kind: ItemKind
        let node: SKNode
        var lane: Lane
        var depth: CGFloat
        var active = true

        init(kind: ItemKind, node: SKNode, lane: Lane, depth: CGFloat) {
            self.kind = kind
            self.node = node
            self.lane = lane
            self.depth = depth
        }
    }

    private struct RoadStripe {
        let node: SKShapeNode
        var depth: CGFloat
    }

    private let world = SKNode()
    private let roadNode = SKNode()
    private let itemNode = SKNode()
    private let sceneryNode = SKNode()
    private let hudNode = SKNode()
    private let overlayNode = SKNode()

    private var roadShape = SKShapeNode()
    private var laneLines: [SKShapeNode] = []
    private var stripes: [RoadStripe] = []
    private var hillsBack = SKNode()
    private var hillsFront = SKNode()
    private var cloudLayer = SKNode()

    private var player = SKNode()
    private var playerBody = SKShapeNode()
    private var playerHat = SKShapeNode()
    private var playerSword = SKShapeNode()
    private var playerShadow = SKShapeNode()
    private var currentLane: Lane = .center
    private var targetLane: Lane = .center
    private var playerX: CGFloat = 0
    private var playerBaseY: CGFloat = 0
    private var jumpTime: CGFloat = 0
    private var slideTime: CGFloat = 0
    private var strikeTime: CGFloat = 0
    private var invincibleTime: CGFloat = 0

    private var items: [RunItem] = []
    private var spawnClock: CGFloat = 0
    private var coinClock: CGFloat = 0
    private var lastUpdate: TimeInterval = 0
    private var runSpeed: CGFloat = 0.24
    private var distance: CGFloat = 0
    private var crowns = 0
    private var shards = 0
    private var hearts = 3
    private var isGameOver = false

    private var startTouch: CGPoint?
    private var startTouchTime: TimeInterval = 0

    private let titleLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let heartsLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let crownsLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let shardsLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let distanceLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let hintLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let messageLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let restartLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")

    override func didMove(to view: SKView) {
        backgroundColor = UIColor(red: 0.58, green: 0.72, blue: 0.66, alpha: 1)
        view.isMultipleTouchEnabled = false
        view.preferredFramesPerSecond = 60
        anchorPoint = .zero

        addChild(world)
        world.addChild(sceneryNode)
        world.addChild(roadNode)
        world.addChild(itemNode)
        addChild(hudNode)
        addChild(overlayNode)

        buildScenery()
        buildRoad()
        buildPlayer()
        buildHud()
        buildOverlay()
        resetRun()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        layoutScene()
    }

    override func update(_ currentTime: TimeInterval) {
        if lastUpdate == 0 {
            lastUpdate = currentTime
            return
        }

        let dt = min(CGFloat(currentTime - lastUpdate), 1 / 30)
        lastUpdate = currentTime

        guard !isGameOver else {
            animateIdle(dt: dt)
            return
        }

        distance += dt * runSpeed * 480
        runSpeed = min(0.46, runSpeed + dt * 0.0024)
        spawnClock -= dt
        coinClock -= dt
        jumpTime = max(0, jumpTime - dt)
        slideTime = max(0, slideTime - dt)
        strikeTime = max(0, strikeTime - dt)
        invincibleTime = max(0, invincibleTime - dt)

        if spawnClock <= 0 {
            spawnHazard()
            spawnClock = CGFloat.random(in: 0.74...1.15) - min(0.28, distance / 6000)
        }

        if coinClock <= 0 {
            spawnRewardTrail()
            coinClock = CGFloat.random(in: 0.72...1.08)
        }

        updateRoad(dt: dt)
        updateItems(dt: dt)
        updatePlayer(dt: dt)
        updateScenery(dt: dt)
        updateHud()
    }

    private func resetRun() {
        items.forEach { $0.node.removeFromParent() }
        items.removeAll()
        crowns = 0
        shards = 0
        hearts = 3
        distance = 0
        runSpeed = 0.24
        spawnClock = 0.8
        coinClock = 0.4
        currentLane = .center
        targetLane = .center
        jumpTime = 0
        slideTime = 0
        strikeTime = 0
        invincibleTime = 0
        isGameOver = false
        overlayNode.isHidden = true
        player.isHidden = false
        hintLabel.text = "Swipe lanes, jump, slide, and tap to swing."
        updateHud()
        layoutScene()
    }

    private func buildScenery() {
        sceneryNode.removeAllChildren()

        let sky = SKSpriteNode(texture: gradientTexture(size: CGSize(width: 32, height: 64), top: UIColor(red: 0.58, green: 0.73, blue: 0.69, alpha: 1), bottom: UIColor(red: 0.86, green: 0.78, blue: 0.58, alpha: 1)))
        sky.name = "sky"
        sky.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        sky.zPosition = -100
        sceneryNode.addChild(sky)

        cloudLayer = SKNode()
        cloudLayer.zPosition = -80
        sceneryNode.addChild(cloudLayer)
        for index in 0..<8 {
            let cloud = makeCloud()
            cloud.position = CGPoint(x: CGFloat(index) * 130, y: CGFloat.random(in: 0...80))
            cloud.setScale(CGFloat.random(in: 0.8...1.4))
            cloud.alpha = 0.42
            cloudLayer.addChild(cloud)
        }

        hillsBack = makeHillLayer(color: UIColor(red: 0.42, green: 0.56, blue: 0.39, alpha: 1), amplitude: 42, baseline: 0.34)
        hillsBack.zPosition = -60
        sceneryNode.addChild(hillsBack)

        hillsFront = makeHillLayer(color: UIColor(red: 0.20, green: 0.39, blue: 0.38, alpha: 1), amplitude: 54, baseline: 0.22)
        hillsFront.zPosition = -50
        sceneryNode.addChild(hillsFront)

        for index in 0..<12 {
            let tree = makeTree()
            tree.position = CGPoint(x: CGFloat(index) * 95, y: 0)
            tree.zPosition = -35
            sceneryNode.addChild(tree)
        }
    }

    private func buildRoad() {
        roadNode.removeAllChildren()
        roadShape = SKShapeNode()
        roadShape.fillColor = UIColor(red: 0.40, green: 0.31, blue: 0.21, alpha: 1)
        roadShape.strokeColor = UIColor(red: 0.95, green: 0.89, blue: 0.66, alpha: 0.34)
        roadShape.lineWidth = 2
        roadShape.zPosition = -10
        roadNode.addChild(roadShape)

        laneLines = (0..<2).map { _ in
            let line = SKShapeNode()
            line.strokeColor = UIColor(red: 0.96, green: 0.89, blue: 0.64, alpha: 0.34)
            line.lineWidth = 2
            line.lineCap = .round
            line.zPosition = -8
            roadNode.addChild(line)
            return line
        }

        stripes = (0..<16).map { index in
            let stripe = SKShapeNode()
            stripe.fillColor = UIColor(red: 0.96, green: 0.89, blue: 0.64, alpha: 0.32)
            stripe.strokeColor = .clear
            stripe.zPosition = -7
            roadNode.addChild(stripe)
            return RoadStripe(node: stripe, depth: CGFloat(index) / 16)
        }
    }

    private func buildPlayer() {
        player.removeFromParent()
        player = SKNode()
        player.zPosition = 50

        playerShadow = SKShapeNode(ellipseOf: CGSize(width: 72, height: 20))
        playerShadow.fillColor = UIColor.black.withAlphaComponent(0.18)
        playerShadow.strokeColor = .clear
        playerShadow.position = CGPoint(x: 0, y: -58)
        player.addChild(playerShadow)

        let legs = SKShapeNode(rectOf: CGSize(width: 34, height: 24), cornerRadius: 8)
        legs.fillColor = UIColor(red: 0.12, green: 0.24, blue: 0.24, alpha: 1)
        legs.strokeColor = .clear
        legs.position = CGPoint(x: 0, y: -38)
        player.addChild(legs)

        playerBody = SKShapeNode(rectOf: CGSize(width: 50, height: 78), cornerRadius: 22)
        playerBody.fillColor = UIColor(red: 0.89, green: 0.31, blue: 0.22, alpha: 1)
        playerBody.strokeColor = UIColor(red: 0.12, green: 0.16, blue: 0.14, alpha: 1)
        playerBody.lineWidth = 3
        playerBody.position = CGPoint(x: 0, y: 0)
        player.addChild(playerBody)

        let scarf = SKShapeNode(rectOf: CGSize(width: 58, height: 12), cornerRadius: 6)
        scarf.fillColor = UIColor(red: 0.96, green: 0.82, blue: 0.34, alpha: 1)
        scarf.strokeColor = .clear
        scarf.position = CGPoint(x: 8, y: 22)
        scarf.zRotation = -0.12
        player.addChild(scarf)

        let face = SKShapeNode(ellipseOf: CGSize(width: 46, height: 42))
        face.fillColor = UIColor(red: 0.96, green: 0.86, blue: 0.63, alpha: 1)
        face.strokeColor = UIColor(red: 0.12, green: 0.16, blue: 0.14, alpha: 1)
        face.lineWidth = 3
        face.position = CGPoint(x: 0, y: 55)
        player.addChild(face)

        let eye = SKShapeNode(circleOfRadius: 3.5)
        eye.fillColor = UIColor(red: 0.10, green: 0.14, blue: 0.13, alpha: 1)
        eye.strokeColor = .clear
        eye.position = CGPoint(x: 10, y: 58)
        player.addChild(eye)

        playerHat = SKShapeNode(path: leafCapPath())
        playerHat.fillColor = UIColor(red: 0.27, green: 0.43, blue: 0.32, alpha: 1)
        playerHat.strokeColor = UIColor(red: 0.12, green: 0.16, blue: 0.14, alpha: 1)
        playerHat.lineWidth = 2
        playerHat.position = CGPoint(x: 0, y: 80)
        player.addChild(playerHat)

        playerSword = SKShapeNode(path: swordPath())
        playerSword.fillColor = UIColor(red: 0.92, green: 0.90, blue: 0.77, alpha: 1)
        playerSword.strokeColor = UIColor(red: 0.76, green: 0.58, blue: 0.24, alpha: 1)
        playerSword.lineWidth = 2
        playerSword.position = CGPoint(x: 42, y: 6)
        playerSword.zRotation = -0.42
        playerSword.isHidden = true
        player.addChild(playerSword)

        itemNode.addChild(player)
    }

    private func buildHud() {
        hudNode.removeAllChildren()

        titleLabel.text = "Offside Run"
        titleLabel.fontSize = 28
        titleLabel.fontColor = UIColor(red: 0.09, green: 0.14, blue: 0.13, alpha: 1)
        titleLabel.horizontalAlignmentMode = .left
        titleLabel.verticalAlignmentMode = .center
        titleLabel.zPosition = 100
        hudNode.addChild(titleLabel)

        heartsLabel.fontSize = 20
        heartsLabel.fontColor = UIColor(red: 0.90, green: 0.22, blue: 0.18, alpha: 1)
        heartsLabel.horizontalAlignmentMode = .left
        heartsLabel.zPosition = 100
        hudNode.addChild(heartsLabel)

        crownsLabel.fontSize = 18
        crownsLabel.fontColor = UIColor(red: 0.18, green: 0.17, blue: 0.12, alpha: 1)
        crownsLabel.horizontalAlignmentMode = .left
        crownsLabel.zPosition = 100
        hudNode.addChild(crownsLabel)

        shardsLabel.fontSize = 18
        shardsLabel.fontColor = UIColor(red: 0.18, green: 0.17, blue: 0.12, alpha: 1)
        shardsLabel.horizontalAlignmentMode = .left
        shardsLabel.zPosition = 100
        hudNode.addChild(shardsLabel)

        distanceLabel.fontSize = 16
        distanceLabel.fontColor = UIColor(red: 0.94, green: 0.89, blue: 0.72, alpha: 1)
        distanceLabel.horizontalAlignmentMode = .right
        distanceLabel.zPosition = 100
        hudNode.addChild(distanceLabel)

        hintLabel.fontSize = 14
        hintLabel.fontColor = UIColor(red: 0.94, green: 0.89, blue: 0.72, alpha: 0.95)
        hintLabel.horizontalAlignmentMode = .center
        hintLabel.zPosition = 100
        hudNode.addChild(hintLabel)
    }

    private func buildOverlay() {
        overlayNode.zPosition = 300
        overlayNode.isHidden = true

        let veil = SKShapeNode(rectOf: CGSize(width: 1, height: 1), cornerRadius: 0)
        veil.name = "veil"
        veil.fillColor = UIColor(red: 0.08, green: 0.12, blue: 0.11, alpha: 0.72)
        veil.strokeColor = .clear
        overlayNode.addChild(veil)

        messageLabel.fontSize = 36
        messageLabel.fontColor = UIColor(red: 0.96, green: 0.89, blue: 0.65, alpha: 1)
        messageLabel.verticalAlignmentMode = .center
        overlayNode.addChild(messageLabel)

        restartLabel.text = "Tap to run again"
        restartLabel.fontSize = 18
        restartLabel.fontColor = UIColor.white.withAlphaComponent(0.92)
        restartLabel.verticalAlignmentMode = .center
        overlayNode.addChild(restartLabel)
    }

    private func layoutScene() {
        guard size.width > 0, size.height > 0 else { return }

        childNode(withName: "//sky")?.position = CGPoint(x: size.width / 2, y: size.height / 2)
        childNode(withName: "//sky")?.setScale(max(size.width / 32, size.height / 64))

        playerBaseY = size.height * 0.19
        playerX = laneX(targetLane, depth: 1)
        player.position = CGPoint(x: playerX, y: playerBaseY)

        titleLabel.position = CGPoint(x: 22, y: size.height - 54)
        heartsLabel.position = CGPoint(x: 24, y: size.height - 92)
        crownsLabel.position = CGPoint(x: 24, y: size.height - 120)
        shardsLabel.position = CGPoint(x: 24, y: size.height - 148)
        distanceLabel.position = CGPoint(x: size.width - 22, y: size.height - 58)
        hintLabel.position = CGPoint(x: size.width / 2, y: 42)

        if let veil = overlayNode.childNode(withName: "veil") as? SKShapeNode {
            veil.path = CGPath(rect: CGRect(origin: .zero, size: size), transform: nil)
            veil.position = .zero
        }
        messageLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 34)
        restartLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 18)

        redrawHillLayer(hillsBack)
        redrawHillLayer(hillsFront)
        updateRoadGeometry()
    }

    private func updateRoad(dt: CGFloat) {
        for index in stripes.indices {
            stripes[index].depth += dt * runSpeed
            if stripes[index].depth > 1.05 {
                stripes[index].depth = 0.04
            }
            drawStripe(stripes[index])
        }
        updateRoadGeometry()
    }

    private func updateRoadGeometry() {
        let horizon = CGPoint(x: size.width / 2, y: size.height * 0.70)
        let leftNear = CGPoint(x: size.width * 0.08, y: 0)
        let rightNear = CGPoint(x: size.width * 0.92, y: 0)
        let path = CGMutablePath()
        path.move(to: leftNear)
        path.addLine(to: CGPoint(x: horizon.x - 42, y: horizon.y))
        path.addLine(to: CGPoint(x: horizon.x + 42, y: horizon.y))
        path.addLine(to: rightNear)
        path.closeSubpath()
        roadShape.path = path

        for (index, line) in laneLines.enumerated() {
            let laneCut = index == 0 ? -0.333 : 0.333
            let linePath = CGMutablePath()
            var first = true
            for step in 0...14 {
                let depth = CGFloat(step) / 14
                let y = screenY(depth)
                let x = size.width / 2 + laneCut * roadHalfWidth(depth)
                if first {
                    linePath.move(to: CGPoint(x: x, y: y))
                    first = false
                } else {
                    linePath.addLine(to: CGPoint(x: x, y: y))
                }
            }
            line.path = linePath
        }
    }

    private func drawStripe(_ stripe: RoadStripe) {
        let depth = stripe.depth
        let center = CGPoint(x: size.width / 2, y: screenY(depth))
        let w = roadHalfWidth(depth) * 0.38
        let h = max(3, 12 * scaleForDepth(depth))
        let path = CGMutablePath()
        path.addRoundedRect(in: CGRect(x: center.x - w / 2, y: center.y - h / 2, width: w, height: h), cornerWidth: h / 2, cornerHeight: h / 2)
        stripe.node.path = path
        stripe.node.alpha = 0.18 + depth * 0.28
        stripe.node.zPosition = -7 + depth
    }

    private func updatePlayer(dt: CGFloat) {
        let targetX = laneX(targetLane, depth: 1)
        playerX += (targetX - playerX) * min(1, dt * 13)
        if abs(playerX - targetX) < 2 {
            currentLane = targetLane
        }

        let jumpOffset: CGFloat
        if jumpTime > 0 {
            let progress = 1 - jumpTime / 0.72
            jumpOffset = sin(progress * .pi) * 132
        } else {
            jumpOffset = 0
        }

        let slideScale = slideTime > 0 ? 0.72 : 1
        player.position = CGPoint(x: playerX, y: playerBaseY + jumpOffset)
        player.setScale(slideScale)
        playerSword.isHidden = strikeTime <= 0
        playerSword.zRotation = strikeTime > 0 ? -0.9 + strikeTime * 5 : -0.42
        player.alpha = invincibleTime > 0 && Int(invincibleTime * 18) % 2 == 0 ? 0.42 : 1
        playerHat.zRotation = sin(distance * 0.03) * 0.05
        playerBody.position.y = sin(distance * 0.055) * 2
    }

    private func updateItems(dt: CGFloat) {
        for item in items where item.active {
            item.depth += dt * runSpeed
            if item.depth > 1.18 {
                item.active = false
                item.node.removeFromParent()
                continue
            }
            layout(item)
            if item.depth > 0.88 && item.depth < 1.08 && item.lane == currentLane {
                resolveCollision(item)
            }
        }
        items.removeAll { !$0.active }
    }

    private func resolveCollision(_ item: RunItem) {
        switch item.kind {
        case .crown:
            collect(item)
            crowns += 1
            burst(at: item.node.position, color: UIColor(red: 0.96, green: 0.72, blue: 0.24, alpha: 1))
        case .shard:
            collect(item)
            shards += 1
            burst(at: item.node.position, color: UIColor(red: 0.30, green: 0.52, blue: 0.82, alpha: 1))
        case .heart:
            collect(item)
            hearts = min(3, hearts + 1)
            burst(at: item.node.position, color: UIColor(red: 0.92, green: 0.22, blue: 0.22, alpha: 1))
        case .log:
            if jumpTime <= 0 {
                takeHit()
                item.active = false
                item.node.removeFromParent()
            }
        case .arch:
            if slideTime <= 0 {
                takeHit()
                item.active = false
                item.node.removeFromParent()
            }
        case .maskling, .thorn:
            if strikeTime > 0 {
                collect(item)
                burst(at: item.node.position, color: UIColor(red: 0.73, green: 0.42, blue: 0.78, alpha: 1))
            } else {
                takeHit()
                item.active = false
                item.node.removeFromParent()
            }
        }
    }

    private func collect(_ item: RunItem) {
        item.active = false
        item.node.run(.sequence([.scale(to: item.node.xScale * 1.4, duration: 0.08), .fadeOut(withDuration: 0.08), .removeFromParent()]))
    }

    private func takeHit() {
        guard invincibleTime <= 0 else { return }
        hearts -= 1
        invincibleTime = 1.25
        runSpeed = max(0.22, runSpeed - 0.04)
        shake()
        burst(at: player.position, color: UIColor(red: 0.90, green: 0.22, blue: 0.20, alpha: 1))
        if hearts <= 0 {
            finishRun(won: false)
        }
    }

    private func finishRun(won: Bool) {
        isGameOver = true
        messageLabel.text = won ? "Forest Gate Cleared" : "Caught by the Bramble"
        restartLabel.text = won ? "Tap to run again" : "Tap to try again"
        overlayNode.isHidden = false
    }

    private func spawnHazard() {
        let lane = Lane.allCases.randomElement() ?? .center
        let roll = Int.random(in: 0...100)
        let kind: ItemKind
        if roll < 28 {
            kind = .log
        } else if roll < 52 {
            kind = .arch
        } else if roll < 78 {
            kind = .maskling
        } else {
            kind = .thorn
        }
        spawn(kind, lane: lane, depth: -0.03)
    }

    private func spawnRewardTrail() {
        let lane = Lane.allCases.randomElement() ?? .center
        let count = Int.random(in: 3...6)
        let specialRoll = Int.random(in: 0...100)
        for index in 0..<count {
            spawn(.crown, lane: lane, depth: -0.08 - CGFloat(index) * 0.075)
        }
        if specialRoll > 76 && shards < 4 {
            spawn(.shard, lane: lane, depth: -0.12 - CGFloat(count) * 0.075)
        } else if specialRoll < 8 && hearts < 3 {
            spawn(.heart, lane: lane, depth: -0.12 - CGFloat(count) * 0.075)
        }
    }

    private func spawn(_ kind: ItemKind, lane: Lane, depth: CGFloat) {
        let node = makeItemNode(kind)
        let item = RunItem(kind: kind, node: node, lane: lane, depth: depth)
        itemNode.addChild(node)
        items.append(item)
        layout(item)
    }

    private func layout(_ item: RunItem) {
        let depth = item.depth
        let scale = scaleForDepth(depth)
        item.node.position = CGPoint(x: laneX(item.lane, depth: depth), y: screenY(depth))
        item.node.setScale(scale)
        item.node.zPosition = 10 + depth * 100
        item.node.alpha = depth < 0 ? 0 : min(1, 0.25 + depth * 1.3)
        item.node.yScale = item.node.xScale
        if item.kind == .crown || item.kind == .shard || item.kind == .heart {
            item.node.position.y += sin((distance * 0.06) + depth * 12) * 5 * scale
            item.node.zRotation += 0.04
        }
    }

    private func makeItemNode(_ kind: ItemKind) -> SKNode {
        switch kind {
        case .crown:
            let group = SKNode()
            let glow = SKShapeNode(circleOfRadius: 18)
            glow.fillColor = UIColor(red: 0.96, green: 0.72, blue: 0.24, alpha: 0.20)
            glow.strokeColor = .clear
            group.addChild(glow)
            let coin = SKShapeNode(circleOfRadius: 12)
            coin.fillColor = UIColor(red: 0.96, green: 0.72, blue: 0.24, alpha: 1)
            coin.strokeColor = UIColor.white.withAlphaComponent(0.84)
            coin.lineWidth = 3
            group.addChild(coin)
            return group
        case .shard:
            let shard = SKShapeNode(path: diamondPath(width: 28, height: 38))
            shard.fillColor = UIColor(red: 0.30, green: 0.52, blue: 0.82, alpha: 1)
            shard.strokeColor = UIColor.white.withAlphaComponent(0.86)
            shard.lineWidth = 3
            return shard
        case .heart:
            let heart = SKShapeNode(path: heartPath(size: 32))
            heart.fillColor = UIColor(red: 0.92, green: 0.20, blue: 0.20, alpha: 1)
            heart.strokeColor = UIColor.white.withAlphaComponent(0.84)
            heart.lineWidth = 3
            return heart
        case .log:
            let group = SKNode()
            let log = SKShapeNode(rectOf: CGSize(width: 92, height: 34), cornerRadius: 15)
            log.fillColor = UIColor(red: 0.43, green: 0.29, blue: 0.16, alpha: 1)
            log.strokeColor = UIColor(red: 0.18, green: 0.13, blue: 0.08, alpha: 1)
            log.lineWidth = 3
            group.addChild(log)
            for x in [-28, 0, 28] {
                let mark = SKShapeNode(rectOf: CGSize(width: 14, height: 4), cornerRadius: 2)
                mark.fillColor = UIColor(red: 0.86, green: 0.74, blue: 0.52, alpha: 0.38)
                mark.strokeColor = .clear
                mark.position = CGPoint(x: x, y: 3)
                group.addChild(mark)
            }
            return group
        case .arch:
            let group = SKNode()
            let left = SKShapeNode(rectOf: CGSize(width: 18, height: 98), cornerRadius: 8)
            let right = left.copy() as! SKShapeNode
            left.fillColor = UIColor(red: 0.42, green: 0.34, blue: 0.25, alpha: 1)
            right.fillColor = left.fillColor
            left.strokeColor = .clear
            right.strokeColor = .clear
            left.position = CGPoint(x: -34, y: 20)
            right.position = CGPoint(x: 34, y: 20)
            let top = SKShapeNode(rectOf: CGSize(width: 88, height: 20), cornerRadius: 10)
            top.fillColor = UIColor(red: 0.42, green: 0.34, blue: 0.25, alpha: 1)
            top.strokeColor = .clear
            top.position = CGPoint(x: 0, y: 72)
            group.addChild(left)
            group.addChild(right)
            group.addChild(top)
            return group
        case .maskling:
            let group = SKNode()
            let body = SKShapeNode(ellipseOf: CGSize(width: 52, height: 58))
            body.fillColor = UIColor(red: 0.36, green: 0.26, blue: 0.45, alpha: 1)
            body.strokeColor = UIColor(red: 0.16, green: 0.13, blue: 0.18, alpha: 1)
            body.lineWidth = 3
            group.addChild(body)
            let face = SKShapeNode(ellipseOf: CGSize(width: 34, height: 28))
            face.fillColor = UIColor(red: 0.96, green: 0.86, blue: 0.63, alpha: 1)
            face.strokeColor = .clear
            face.position = CGPoint(x: 0, y: 4)
            group.addChild(face)
            for x in [-8, 8] {
                let eye = SKShapeNode(circleOfRadius: 3)
                eye.fillColor = UIColor(red: 0.08, green: 0.12, blue: 0.10, alpha: 1)
                eye.strokeColor = .clear
                eye.position = CGPoint(x: x, y: 7)
                group.addChild(eye)
            }
            let horn = SKShapeNode(path: leafCapPath())
            horn.fillColor = UIColor(red: 0.75, green: 0.64, blue: 0.40, alpha: 1)
            horn.strokeColor = .clear
            horn.setScale(0.34)
            horn.position = CGPoint(x: 0, y: 32)
            group.addChild(horn)
            return group
        case .thorn:
            let group = SKNode()
            for index in 0..<4 {
                let thorn = SKShapeNode(path: trianglePath(width: 28, height: 62))
                thorn.fillColor = UIColor(red: 0.28, green: 0.43, blue: 0.24, alpha: 1)
                thorn.strokeColor = UIColor(red: 0.12, green: 0.20, blue: 0.11, alpha: 1)
                thorn.lineWidth = 2
                thorn.position = CGPoint(x: CGFloat(index - 2) * 18 + 9, y: 8)
                thorn.zRotation = CGFloat(index - 1) * 0.08
                group.addChild(thorn)
            }
            return group
        }
    }

    private func changeLane(_ direction: Int) {
        let nextRaw = max(-1, min(1, targetLane.rawValue + direction))
        targetLane = Lane(rawValue: nextRaw) ?? targetLane
    }

    private func jump() {
        guard jumpTime <= 0.08 else { return }
        jumpTime = 0.72
        slideTime = 0
    }

    private func slide() {
        guard slideTime <= 0.08 else { return }
        slideTime = 0.56
        jumpTime = 0
    }

    private func strike() {
        strikeTime = 0.28
        player.run(.sequence([.scale(to: 1.08, duration: 0.06), .scale(to: 1, duration: 0.10)]))
    }

    private func screenY(_ depth: CGFloat) -> CGFloat {
        let t = max(0, min(1, depth))
        let horizon = size.height * 0.70
        let near = size.height * 0.13
        return horizon + (near - horizon) * pow(t, 1.42)
    }

    private func scaleForDepth(_ depth: CGFloat) -> CGFloat {
        let t = max(0, min(1, depth))
        return 0.22 + pow(t, 1.7) * 1.25
    }

    private func roadHalfWidth(_ depth: CGFloat) -> CGFloat {
        let t = max(0, min(1, depth))
        return size.width * (0.11 + pow(t, 1.2) * 0.39)
    }

    private func laneX(_ lane: Lane, depth: CGFloat) -> CGFloat {
        size.width / 2 + CGFloat(lane.rawValue) * roadHalfWidth(depth) * 0.52
    }

    private func updateScenery(dt: CGFloat) {
        cloudLayer.position.x -= dt * runSpeed * 18
        if cloudLayer.position.x < -130 {
            cloudLayer.position.x = 0
        }
        hillsBack.position.x = -truncatingRemainder(distance * 0.08, by: 120)
        hillsFront.position.x = -truncatingRemainder(distance * 0.14, by: 120)
    }

    private func animateIdle(dt: CGFloat) {
        playerHat.zRotation = sin(CGFloat(CACurrentMediaTime()) * 2) * 0.05
    }

    private func updateHud() {
        heartsLabel.text = "Hearts " + String(repeating: "♥", count: max(0, hearts)) + String(repeating: "♡", count: max(0, 3 - hearts))
        crownsLabel.text = "Crowns \(crowns)"
        shardsLabel.text = "Rune shards \(min(shards, 4))/4"
        distanceLabel.text = "\(Int(distance)) m"
        if shards >= 4 && distance > 900 {
            finishRun(won: true)
        }
    }

    private func shake() {
        let dx: CGFloat = 10
        world.run(.sequence([
            .moveBy(x: -dx, y: 0, duration: 0.035),
            .moveBy(x: dx * 2, y: 0, duration: 0.055),
            .moveBy(x: -dx, y: 0, duration: 0.035),
        ]))
    }

    private func burst(at point: CGPoint, color: UIColor) {
        for _ in 0..<12 {
            let dot = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...4))
            dot.fillColor = color
            dot.strokeColor = .clear
            dot.position = point
            dot.zPosition = 220
            addChild(dot)
            let angle = CGFloat.random(in: 0...(2 * .pi))
            let distance = CGFloat.random(in: 28...72)
            dot.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.36),
                    .fadeOut(withDuration: 0.36),
                    .scale(to: 0.2, duration: 0.36),
                ]),
                .removeFromParent(),
            ]))
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        if isGameOver {
            resetRun()
            return
        }
        startTouch = touch.location(in: self)
        startTouchTime = touch.timestamp
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !isGameOver, let start = startTouch, let touch = touches.first else { return }
        let end = touch.location(in: self)
        let dx = end.x - start.x
        let dy = end.y - start.y
        let absX = abs(dx)
        let absY = abs(dy)

        if max(absX, absY) < 28 {
            strike()
        } else if absX > absY {
            changeLane(dx > 0 ? 1 : -1)
        } else if dy > 0 {
            jump()
        } else {
            slide()
        }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            switch press.key?.keyCode {
            case .keyboardLeftArrow, .keyboardA:
                changeLane(-1)
            case .keyboardRightArrow, .keyboardD:
                changeLane(1)
            case .keyboardUpArrow, .keyboardW, .keyboardSpacebar:
                jump()
            case .keyboardDownArrow, .keyboardS:
                slide()
            case .keyboardJ, .keyboardK:
                strike()
            default:
                super.pressesBegan(presses, with: event)
            }
        }
    }

    private func gradientTexture(size: CGSize, top: UIColor, bottom: UIColor) -> SKTexture {
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cgContext = context.cgContext
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let gradient = CGGradient(colorsSpace: colorSpace, colors: [top.cgColor, bottom.cgColor] as CFArray, locations: [0, 1])!
            cgContext.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: size.height), options: [])
        }
        return SKTexture(image: image)
    }

    private func makeCloud() -> SKNode {
        let node = SKNode()
        for (index, radius) in [28, 38, 30, 22].enumerated() {
            let puff = SKShapeNode(circleOfRadius: CGFloat(radius))
            puff.fillColor = UIColor(red: 0.96, green: 0.94, blue: 0.82, alpha: 0.72)
            puff.strokeColor = .clear
            puff.position = CGPoint(x: CGFloat(index) * 30, y: CGFloat(index % 2) * 10)
            node.addChild(puff)
        }
        return node
    }

    private func makeHillLayer(color: UIColor, amplitude: CGFloat, baseline: CGFloat) -> SKNode {
        let node = SKNode()
        let shape = SKShapeNode()
        shape.fillColor = color
        shape.strokeColor = .clear
        node.addChild(shape)
        shape.name = "hillShape"
        shape.userData = NSMutableDictionary(dictionary: ["amplitude": amplitude, "baseline": baseline])
        return node
    }

    private func redrawHillLayer(_ node: SKNode) {
        guard let shape = node.childNode(withName: "hillShape") as? SKShapeNode else { return }
        let amplitude = shape.userData?["amplitude"] as? CGFloat ?? 42
        let baseline = shape.userData?["baseline"] as? CGFloat ?? 0.3
        let width = size.width + 480
        let baseY = size.height * baseline
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -240, y: -80))
        for step in 0...80 {
            let x = -240 + CGFloat(step) / 80 * width
            let y = baseY
                + sin((x + amplitude * 3) * 0.012) * amplitude
                + sin(x * 0.031) * amplitude * 0.22
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: size.width + 240, y: -80))
        path.closeSubpath()
        shape.path = path
    }

    private func makeTree() -> SKNode {
        let node = SKNode()
        let trunk = SKShapeNode(rectOf: CGSize(width: 14, height: 70), cornerRadius: 4)
        trunk.fillColor = UIColor(red: 0.44, green: 0.30, blue: 0.18, alpha: 1)
        trunk.strokeColor = .clear
        trunk.position = CGPoint(x: 0, y: 35)
        node.addChild(trunk)
        for (index, size) in [70, 58, 46].enumerated() {
            let leaves = SKShapeNode(path: trianglePath(width: CGFloat(size), height: CGFloat(size)))
            leaves.fillColor = UIColor(red: 0.26, green: 0.43, blue: 0.28, alpha: 1)
            leaves.strokeColor = .clear
            leaves.position = CGPoint(x: 0, y: 74 + CGFloat(index * 24))
            node.addChild(leaves)
        }
        return node
    }

    private func leafCapPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -28, y: -4))
        path.addQuadCurve(to: CGPoint(x: 30, y: -2), control: CGPoint(x: 0, y: 24))
        path.addQuadCurve(to: CGPoint(x: -28, y: -4), control: CGPoint(x: -2, y: -18))
        path.closeSubpath()
        return path
    }

    private func swordPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -5, y: -18))
        path.addLine(to: CGPoint(x: 5, y: -18))
        path.addLine(to: CGPoint(x: 8, y: 34))
        path.addLine(to: CGPoint(x: 0, y: 48))
        path.addLine(to: CGPoint(x: -8, y: 34))
        path.closeSubpath()
        return path
    }

    private func trianglePath(width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: height / 2))
        path.addLine(to: CGPoint(x: -width / 2, y: -height / 2))
        path.addLine(to: CGPoint(x: width / 2, y: -height / 2))
        path.closeSubpath()
        return path
    }

    private func diamondPath(width: CGFloat, height: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: height / 2))
        path.addLine(to: CGPoint(x: width / 2, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -height / 2))
        path.addLine(to: CGPoint(x: -width / 2, y: 0))
        path.closeSubpath()
        return path
    }

    private func heartPath(size: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let s = size / 32
        path.move(to: CGPoint(x: 0, y: -12 * s))
        path.addCurve(to: CGPoint(x: -16 * s, y: 6 * s), control1: CGPoint(x: -14 * s, y: -2 * s), control2: CGPoint(x: -20 * s, y: 4 * s))
        path.addCurve(to: CGPoint(x: 0, y: 16 * s), control1: CGPoint(x: -13 * s, y: 21 * s), control2: CGPoint(x: -2 * s, y: 18 * s))
        path.addCurve(to: CGPoint(x: 16 * s, y: 6 * s), control1: CGPoint(x: 2 * s, y: 18 * s), control2: CGPoint(x: 13 * s, y: 21 * s))
        path.addCurve(to: CGPoint(x: 0, y: -12 * s), control1: CGPoint(x: 20 * s, y: 4 * s), control2: CGPoint(x: 14 * s, y: -2 * s))
        path.closeSubpath()
        return path
    }

    private func truncatingRemainder(_ value: CGFloat, by divisor: CGFloat) -> CGFloat {
        value - floor(value / divisor) * divisor
    }
}
