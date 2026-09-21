import SpriteKit

/// Every node the scene needs to reach again after construction.
struct TableParts {
    var flippers: [FlipperNode] = []
    var bumpers: [BumperNode] = []
    var dropTargets: [TargetNode] = []
    var standupTargets: [TargetNode] = []
    var rollovers: [RolloverNode] = []
    var saucers: [SaucerNode] = []
    var slingshots: [SlingshotNode] = []
    var spinner: SpinnerNode?
    var rampRails: [SKShapeNode] = []
    var rails: SKShapeNode?
    var magnetGlow: SKSpriteNode?
}

/// Turns `TableLayout` into SpriteKit nodes. The layout stays pure data, the
/// builder owns everything that knows about pixels.
struct TableBuilder {

    let geometry: TableGeometry
    let palette: Palette

    func build(into scene: SKScene) -> TableParts {
        var parts = TableParts()

        addFelt(to: scene)
        parts.rails = addWalls(to: scene)
        addPosts(to: scene)
        addDrain(to: scene)
        parts.magnetGlow = addMagnet(to: scene)
        parts.rampRails = addRamps(to: scene)
        addOrbitGates(to: scene)

        parts.slingshots = TableLayout.slingshots.map {
            let node = SlingshotNode(config: $0, geometry: geometry, palette: palette)
            scene.addChild(node)
            return node
        }

        parts.bumpers = TableLayout.bumpers.map {
            let node = BumperNode(config: $0, geometry: geometry, palette: palette)
            scene.addChild(node)
            return node
        }

        parts.dropTargets = TableLayout.dropTargets.map {
            let node = TargetNode(index: $0.index, kind: .drop, center: $0.center,
                                  angle: $0.angle, size: $0.size,
                                  geometry: geometry, palette: palette)
            scene.addChild(node)
            return node
        }

        parts.standupTargets = TableLayout.standupTargets.map {
            let node = TargetNode(index: $0.index, kind: .standup, center: $0.center,
                                  angle: $0.angle, size: $0.size,
                                  geometry: geometry, palette: palette)
            scene.addChild(node)
            return node
        }

        parts.rollovers = TableLayout.rollovers.map {
            let node = RolloverNode(config: $0, geometry: geometry, palette: palette)
            scene.addChild(node)
            return node
        }

        parts.saucers = TableLayout.saucers.map {
            let node = SaucerNode(config: $0, geometry: geometry, palette: palette)
            scene.addChild(node)
            return node
        }

        let spinner = SpinnerNode(config: TableLayout.spinner,
                                  geometry: geometry, palette: palette)
        scene.addChild(spinner)
        parts.spinner = spinner

        parts.flippers = TableLayout.flippers.map {
            let node = FlipperNode(config: $0, geometry: geometry, palette: palette)
            scene.addChild(node)
            return node
        }

        return parts
    }

    // MARK: - Pieces

    private func addFelt(to scene: SKScene) {
        let rect = CGRect(x: geometry.origin.x,
                          y: geometry.origin.y,
                          width: geometry.length(TableLayout.width),
                          height: geometry.length(TableLayout.height))
        let felt = SKShapeNode(rect: rect, cornerRadius: geometry.length(0.05))
        felt.fillColor = palette.tableFelt
        felt.strokeColor = palette.accent.withAlphaComponent(0.25)
        felt.lineWidth = 2
        felt.zPosition = -10
        scene.addChild(felt)

        // A soft warm wash behind the bumper nest, so the table is not flat.
        let wash = SKSpriteNode(texture: TextureFactory.radialGlow(
            diameter: geometry.length(1.3), color: palette.accent))
        wash.size = CGSize(width: geometry.length(1.3), height: geometry.length(1.3))
        wash.position = geometry.point(CGPoint(x: 0.5, y: 1.05))
        wash.alpha = 0.10
        wash.blendMode = .add
        wash.zPosition = -9
        scene.addChild(wash)
    }

    private func addWalls(to scene: SKScene) -> SKShapeNode {
        let combined = CGMutablePath()

        for wall in TableLayout.walls {
            let wallPath = geometry.path(through: wall.points, closed: wall.isClosed)
            combined.addPath(wallPath)

            let node = SKNode()
            let body = wall.isClosed
                ? SKPhysicsBody(edgeLoopFrom: wallPath)
                : SKPhysicsBody(edgeChainFrom: wallPath)
            body.isDynamic = false
            body.restitution = 0.22
            body.friction = 0.1
            body.categoryBitMask = PhysicsCategory.wall
            body.collisionBitMask = PhysicsCategory.ball
            node.physicsBody = body
            scene.addChild(node)
        }

        let rails = SKShapeNode(path: combined)
        rails.strokeColor = palette.accent.withAlphaComponent(0.75)
        rails.lineWidth = geometry.length(TableLayout.wallThickness)
        rails.lineCap = .round
        rails.lineJoin = .round
        rails.glowWidth = geometry.length(0.006)
        rails.fillColor = .clear
        rails.zPosition = 8
        scene.addChild(rails)
        return rails
    }

    private func addPosts(to scene: SKScene) {
        for post in TableLayout.posts {
            let radius = geometry.length(post.radius)
            let node = SKShapeNode(circleOfRadius: radius)
            node.position = geometry.point(post.center)
            node.fillColor = palette.accentDark
            node.strokeColor = palette.accentLight
            node.lineWidth = 1.2
            node.zPosition = 15

            let body = SKPhysicsBody(circleOfRadius: radius)
            body.isDynamic = false
            body.restitution = 0.55
            body.categoryBitMask = PhysicsCategory.wall
            body.collisionBitMask = PhysicsCategory.ball
            node.physicsBody = body
            scene.addChild(node)
        }
    }

    private func addDrain(to scene: SKScene) {
        let rect = geometry.rect(TableLayout.drainRect)
        let node = SKNode()
        node.position = CGPoint(x: rect.midX, y: rect.midY)
        let body = SKPhysicsBody(rectangleOf: rect.size)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.drain
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.ball
        node.physicsBody = body
        scene.addChild(node)
    }

    private func addMagnet(to scene: SKScene) -> SKSpriteNode {
        let diameter = geometry.length(TableLayout.magnetRadius * 2)
        let glow = SKSpriteNode(texture: TextureFactory.radialGlow(
            diameter: diameter, color: palette.accentLight))
        glow.size = CGSize(width: diameter, height: diameter)
        glow.position = geometry.point(TableLayout.magnetCenter)
        glow.alpha = 0
        glow.blendMode = .add
        glow.zPosition = 6
        scene.addChild(glow)
        return glow
    }

    private func addRamps(to scene: SKScene) -> [SKShapeNode] {
        var rails: [SKShapeNode] = []

        for ramp in TableLayout.ramps {
            let rail = SKShapeNode(path: geometry.smoothPath(through: ramp.path))
            rail.strokeColor = palette.accentLight.withAlphaComponent(0.55)
            rail.lineWidth = geometry.length(0.052)
            rail.lineCap = .round
            rail.fillColor = .clear
            rail.zPosition = 30
            scene.addChild(rail)

            let inner = SKShapeNode(path: geometry.smoothPath(through: ramp.path))
            inner.strokeColor = palette.tableFelt.withAlphaComponent(0.9)
            inner.lineWidth = geometry.length(0.036)
            inner.lineCap = .round
            inner.fillColor = .clear
            inner.zPosition = 31
            scene.addChild(inner)
            rails.append(inner)

            guard let entrance = ramp.path.first else { continue }
            let radius = geometry.length(ramp.entranceRadius)
            let mouth = SKShapeNode(circleOfRadius: radius)
            mouth.position = geometry.point(entrance)
            mouth.fillColor = .clear
            mouth.strokeColor = palette.accent
            mouth.lineWidth = 2
            mouth.glowWidth = 2
            mouth.zPosition = 32
            mouth.name = "ramp.\(ramp.side.rawValue)"

            let body = SKPhysicsBody(circleOfRadius: radius * 0.8)
            body.isDynamic = false
            body.categoryBitMask = PhysicsCategory.rampEntrance
            body.collisionBitMask = PhysicsCategory.none
            body.contactTestBitMask = PhysicsCategory.ball
            mouth.physicsBody = body
            scene.addChild(mouth)
        }
        return rails
    }

    private func addOrbitGates(to scene: SKScene) {
        for gate in TableLayout.orbitGates {
            let size = geometry.size(gate.size)
            let node = SKShapeNode(rectOf: size, cornerRadius: size.height / 2)
            node.position = geometry.point(gate.center)
            node.fillColor = palette.accent.withAlphaComponent(0.22)
            node.strokeColor = .clear
            node.zPosition = 9
            node.name = "orbit.\(gate.side.rawValue)"

            let body = SKPhysicsBody(rectangleOf: size)
            body.isDynamic = false
            body.categoryBitMask = PhysicsCategory.orbitGate
            body.collisionBitMask = PhysicsCategory.none
            body.contactTestBitMask = PhysicsCategory.ball
            node.physicsBody = body
            scene.addChild(node)
        }
    }
}
