import SpriteKit

// MARK: - Pop bumper

final class BumperNode: SKNode {

    let index: Int
    private let cap: SKSpriteNode
    private let glow: SKSpriteNode
    private let ring: SKShapeNode
    private let radius: CGFloat

    init(config: TableLayout.Bumper, geometry: TableGeometry, palette: Palette) {
        index = config.index
        radius = geometry.length(config.radius)

        cap = SKSpriteNode(texture: TextureFactory.bumperCap(
            diameter: radius * 2, color: palette.accentLight))
        cap.size = CGSize(width: radius * 2, height: radius * 2)

        glow = SKSpriteNode(texture: TextureFactory.radialGlow(
            diameter: radius * 4, color: palette.accentLight))
        glow.size = CGSize(width: radius * 4, height: radius * 4)
        glow.alpha = 0.22
        glow.blendMode = .add
        glow.zPosition = -1

        ring = SKShapeNode(circleOfRadius: radius * 1.22)
        ring.strokeColor = palette.accent.withAlphaComponent(0.55)
        ring.lineWidth = max(1.2, radius * 0.10)
        ring.fillColor = .clear
        ring.zPosition = -0.5

        super.init()
        position = geometry.point(config.center)
        zPosition = 20
        addChild(glow)
        addChild(ring)
        addChild(cap)

        let body = SKPhysicsBody(circleOfRadius: radius)
        body.isDynamic = false
        body.restitution = 0.2
        body.categoryBitMask = PhysicsCategory.bumper
        body.collisionBitMask = PhysicsCategory.ball
        body.contactTestBitMask = PhysicsCategory.ball
        physicsBody = body
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func pulse(reduceMotion: Bool) {
        glow.removeAllActions()
        glow.run(.sequence([
            .fadeAlpha(to: 0.85, duration: 0.04),
            .fadeAlpha(to: 0.22, duration: Motion.bumperPulse * 2),
        ]))
        guard !reduceMotion else { return }
        cap.removeAllActions()
        cap.run(.sequence([
            .scale(to: 1.18, duration: Motion.bumperPulse / 2),
            .scale(to: 1.0, duration: Motion.bumperPulse / 2),
        ]))
    }

    func repaint(with palette: Palette) {
        cap.texture = TextureFactory.bumperCap(diameter: radius * 2,
                                               color: palette.accentLight)
        ring.strokeColor = palette.accent.withAlphaComponent(0.55)
    }
}

// MARK: - Targets

final class TargetNode: SKShapeNode {

    enum Kind { case drop, standup }

    let index: Int
    let kind: Kind
    private(set) var isDown = false
    private var litColor: PlatformColor
    private var dimColor: PlatformColor

    init(index: Int, kind: Kind, center: CGPoint, angle: CGFloat,
         size: CGSize, geometry: TableGeometry, palette: Palette) {
        self.index = index
        self.kind = kind
        litColor = kind == .drop ? palette.accentLight : palette.accent
        dimColor = palette.tableRail

        let sceneSize = geometry.size(size)
        let rect = CGRect(x: -sceneSize.width / 2, y: -sceneSize.height / 2,
                          width: sceneSize.width, height: sceneSize.height)
        super.init()
        path = CGPath(roundedRect: rect,
                      cornerWidth: sceneSize.height / 2,
                      cornerHeight: sceneSize.height / 2,
                      transform: nil)
        position = geometry.point(center)
        zRotation = angle
        zPosition = 18
        fillColor = litColor
        strokeColor = palette.accentLight.withAlphaComponent(0.8)
        lineWidth = 1.2
        glowWidth = 0

        let body = SKPhysicsBody(rectangleOf: sceneSize)
        body.isDynamic = false
        body.restitution = 0.35
        body.categoryBitMask = PhysicsCategory.target
        body.collisionBitMask = PhysicsCategory.ball
        body.contactTestBitMask = PhysicsCategory.ball
        physicsBody = body
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func drop(reduceMotion: Bool) {
        guard kind == .drop, !isDown else { return }
        isDown = true
        physicsBody?.categoryBitMask = PhysicsCategory.none
        physicsBody?.collisionBitMask = PhysicsCategory.none
        physicsBody?.contactTestBitMask = PhysicsCategory.none
        let duration = reduceMotion ? 0.01 : 0.14
        run(.group([.fadeAlpha(to: 0.18, duration: duration),
                    .scaleY(to: 0.25, duration: duration)]))
    }

    func raise(reduceMotion: Bool) {
        guard kind == .drop, isDown else { return }
        isDown = false
        physicsBody?.categoryBitMask = PhysicsCategory.target
        physicsBody?.collisionBitMask = PhysicsCategory.ball
        physicsBody?.contactTestBitMask = PhysicsCategory.ball
        let duration = reduceMotion ? 0.01 : 0.2
        run(.group([.fadeAlpha(to: 1, duration: duration),
                    .scaleY(to: 1, duration: duration)]))
    }

    func flash(reduceMotion: Bool) {
        guard !reduceMotion else { return }
        run(.sequence([.scale(to: 1.15, duration: 0.07),
                       .scale(to: 1.0, duration: 0.1)]))
    }

    func setLit(_ lit: Bool) {
        fillColor = lit ? litColor : dimColor
    }

    func repaint(with palette: Palette) {
        litColor = kind == .drop ? palette.accentLight : palette.accent
        dimColor = palette.tableRail
        fillColor = litColor
        strokeColor = palette.accentLight.withAlphaComponent(0.8)
    }
}

// MARK: - Rollover lane lamp

final class RolloverNode: SKNode {

    let index: Int
    private let lamp: SKShapeNode
    private let letter: SKLabelNode
    private(set) var isLit = false

    init(config: TableLayout.Rollover, geometry: TableGeometry, palette: Palette) {
        index = config.index
        let radius = geometry.length(config.radius)
        lamp = SKShapeNode(circleOfRadius: radius)
        letter = SKLabelNode(text: LaneLetter(rawValue: config.index)?.symbol ?? "")

        super.init()
        position = geometry.point(config.center)
        zPosition = 12

        lamp.fillColor = palette.tableRail
        lamp.strokeColor = palette.accent.withAlphaComponent(0.45)
        lamp.lineWidth = 1.4
        addChild(lamp)

        letter.fontName = "AvenirNextCondensed-Bold"
        letter.fontSize = radius * 1.25
        letter.fontColor = palette.textDim
        letter.verticalAlignmentMode = .center
        letter.horizontalAlignmentMode = .center
        addChild(letter)

        let body = SKPhysicsBody(circleOfRadius: radius)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.rollover
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.ball
        physicsBody = body
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func setLit(_ lit: Bool, palette: Palette) {
        isLit = lit
        lamp.fillColor = lit ? palette.accent : palette.tableRail
        lamp.glowWidth = lit ? lamp.frame.width * 0.12 : 0
        letter.fontColor = lit ? .hex(0x14100A) : palette.textDim
    }
}

// MARK: - Saucer

final class SaucerNode: SKNode {

    let side: TableSide
    let ejectAngle: CGFloat
    private let ring: SKShapeNode

    init(config: TableLayout.Saucer, geometry: TableGeometry, palette: Palette) {
        side = config.side
        ejectAngle = config.ejectAngle
        let radius = geometry.length(config.radius)
        ring = SKShapeNode(circleOfRadius: radius)

        super.init()
        position = geometry.point(config.center)
        zPosition = 10

        ring.fillColor = .hex(0x05050A)
        ring.strokeColor = palette.accent
        ring.lineWidth = max(1.5, radius * 0.16)
        ring.glowWidth = radius * 0.25
        addChild(ring)

        let body = SKPhysicsBody(circleOfRadius: radius * 0.7)
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.saucer
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.ball
        physicsBody = body
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func pulse() {
        ring.run(.sequence([.scale(to: 1.2, duration: 0.12),
                            .scale(to: 1.0, duration: 0.18)]))
    }

    func repaint(with palette: Palette) {
        ring.strokeColor = palette.accent
    }
}

// MARK: - Spinner

final class SpinnerNode: SKNode {

    private let blade: SKShapeNode

    init(config: TableLayout.Spinner, geometry: TableGeometry, palette: Palette) {
        let length = geometry.length(config.length)
        let rect = CGRect(x: -length / 2, y: -length * 0.10,
                          width: length, height: length * 0.20)
        blade = SKShapeNode(rect: rect, cornerRadius: length * 0.05)

        super.init()
        position = geometry.point(config.center)
        zRotation = config.angle
        zPosition = 14

        blade.fillColor = palette.accentLight
        blade.strokeColor = palette.accentDark
        blade.lineWidth = 1
        addChild(blade)

        let body = SKPhysicsBody(rectangleOf: CGSize(width: length, height: length * 0.4))
        body.isDynamic = false
        body.categoryBitMask = PhysicsCategory.spinner
        body.collisionBitMask = PhysicsCategory.none
        body.contactTestBitMask = PhysicsCategory.ball
        physicsBody = body
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Returns how many rotations to score for this pass.
    func spin(speed: CGFloat, reference: CGFloat) -> Int {
        let rotations = max(1, Int((speed / max(reference, 1)) * 6))
        guard !blade.hasActions() else { return rotations }
        blade.run(.repeat(.sequence([
            .scaleX(to: -1, duration: 0.07),
            .scaleX(to: 1, duration: 0.07),
        ]), count: rotations))
        return rotations
    }

    func repaint(with palette: Palette) {
        blade.fillColor = palette.accentLight
        blade.strokeColor = palette.accentDark
    }
}

// MARK: - Slingshot

final class SlingshotNode: SKShapeNode {

    let side: TableSide

    init(config: TableLayout.Slingshot, geometry: TableGeometry, palette: Palette) {
        side = config.side
        super.init()

        let scenePath = geometry.path(through: config.vertices, closed: true)
        path = scenePath
        fillColor = palette.tableRail
        strokeColor = palette.accent
        lineWidth = 2
        glowWidth = 1.5
        zPosition = 16

        let body = SKPhysicsBody(polygonFrom: scenePath)
        body.isDynamic = false
        body.restitution = 0.2
        body.categoryBitMask = PhysicsCategory.slingshot
        body.collisionBitMask = PhysicsCategory.ball
        body.contactTestBitMask = PhysicsCategory.ball
        physicsBody = body
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func fire(palette: Palette, reduceMotion: Bool) {
        removeAllActions()
        run(.sequence([
            .run { [weak self] in self?.fillColor = palette.accent },
            .wait(forDuration: reduceMotion ? 0.05 : 0.09),
            .run { [weak self] in self?.fillColor = palette.tableRail },
        ]))
    }

    func repaint(with palette: Palette) {
        fillColor = palette.tableRail
        strokeColor = palette.accent
    }
}
