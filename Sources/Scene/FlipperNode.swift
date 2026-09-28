import SpriteKit

/// A flipper on a pin joint. The joint limits stop the blade at either end of
/// its swing, and `drive()` pushes it towards the end the button asks for on
/// every frame.
final class FlipperNode: SKNode {

    let side: TableSide
    let pivotInScene: CGPoint
    /// How far from the pivot a ball can be and still be resting on the blade.
    let reach: CGFloat

    private let angleRange: CGFloat
    private let sign: CGFloat
    private let blade: SKShapeNode
    private let halo: SKShapeNode

    private(set) var isPressed = false

    init(config: TableLayout.Flipper, geometry: TableGeometry, palette: Palette) {
        side = config.side
        pivotInScene = geometry.point(config.pivot)
        sign = config.side == .left ? 1 : -1

        let length = geometry.length(config.length)
        let thickness = geometry.length(config.thickness)
        reach = length + thickness
        let path = FlipperNode.bladePath(length: length, thickness: thickness, sign: sign)

        blade = SKShapeNode(path: path)
        halo = SKShapeNode(path: path)
        angleRange = PhysicsTuning.flipperActiveAngle - PhysicsTuning.flipperRestAngle

        super.init()

        position = pivotInScene
        zRotation = sign * PhysicsTuning.flipperRestAngle
        zPosition = 40

        halo.fillColor = .clear
        halo.strokeColor = palette.accent.withAlphaComponent(0.0)
        halo.lineWidth = thickness * 0.55
        halo.glowWidth = thickness * 0.5
        halo.zPosition = -1
        addChild(halo)

        // A white bat with a coloured rubber ring round it, the flipper every
        // table of the era shipped with.
        blade.fillColor = CabinetColors.flipperBody
        blade.strokeColor = palette.accent
        blade.lineWidth = max(1.5, thickness * 0.22)
        addChild(blade)

        let body = SKPhysicsBody(polygonFrom: path)
        body.isDynamic = true
        body.affectedByGravity = false
        body.allowsRotation = true
        body.mass = 0.9
        body.restitution = PhysicsTuning.flipperRestitution
        body.friction = PhysicsTuning.flipperFriction
        body.angularDamping = 0.6
        body.categoryBitMask = PhysicsCategory.flipper
        body.collisionBitMask = PhysicsCategory.ball
        body.contactTestBitMask = PhysicsCategory.ball
        physicsBody = body
        name = side == .left ? NodeName.flipperLeft : NodeName.flipperRight
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    /// Tapered capsule, wide at the pivot and narrow at the tip.
    private static func bladePath(length: CGFloat, thickness: CGFloat,
                                  sign: CGFloat) -> CGPath {
        let base = thickness / 2
        let tip = thickness * 0.34
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: base))
        path.addLine(to: CGPoint(x: length, y: tip))
        path.addArc(center: CGPoint(x: length, y: 0), radius: tip,
                    startAngle: .pi / 2, endAngle: -.pi / 2, clockwise: true)
        path.addLine(to: CGPoint(x: 0, y: -base))
        path.addArc(center: .zero, radius: base,
                    startAngle: -.pi / 2, endAngle: .pi / 2, clockwise: true)
        path.closeSubpath()

        guard sign < 0 else { return path }
        var mirror = CGAffineTransform(scaleX: -1, y: 1)
        return path.copy(using: &mirror) ?? path
    }

    func attach(to anchorBody: SKPhysicsBody, in world: SKPhysicsWorld) {
        guard let body = physicsBody else { return }
        let joint = SKPhysicsJointPin.joint(withBodyA: anchorBody, bodyB: body,
                                            anchor: pivotInScene)
        joint.shouldEnableLimits = true
        if sign > 0 {
            joint.lowerAngleLimit = 0
            joint.upperAngleLimit = angleRange
        } else {
            joint.lowerAngleLimit = -angleRange
            joint.upperAngleLimit = 0
        }
        joint.frictionTorque = 0.0
        world.add(joint)
    }

    func press() {
        guard !isPressed else { return }
        isPressed = true
        drive()
        halo.strokeColor = blade.strokeColor.withAlphaComponent(0.55)
    }

    func release() {
        guard isPressed else { return }
        isPressed = false
        drive()
        halo.strokeColor = halo.strokeColor.withAlphaComponent(0)
    }

    /// Pushes the blade towards where the button says it should be. Called on
    /// every frame, not just when the button changes: a single push on press
    /// was all the flipper used to get, so a ball resting on a held flipper
    /// pressed it back down, and a ball on top of a released one could stop it
    /// getting back to rest. The ball then sat on a flipper that no longer did
    /// what the button said.
    func drive() {
        guard let body = physicsBody else { return }
        // 0 at rest, `angleRange` fully raised, whichever side this is.
        let travel = (zRotation - sign * PhysicsTuning.flipperRestAngle) * sign
        let target: CGFloat = isPressed ? angleRange : 0
        let limit = PhysicsTuning.flipperAngularSpeed * (isPressed ? 1 : 0.7)
        let speed = max(-limit, min(limit, (target - travel) * PhysicsTuning.flipperHoldGain))
        body.angularVelocity = sign * speed
    }

    /// Whether a ball centred at `point` is lying on this flipper while it is
    /// held up — a cradle, which the player is allowed to keep for as long as
    /// they like.
    func isCradling(_ point: CGPoint) -> Bool {
        isPressed && point.distance(to: pivotInScene) < reach
    }

    func repaint(with palette: Palette) {
        blade.strokeColor = palette.accent
    }

    /// Cuts power to the flippers, as a real machine does on tilt.
    func disable() {
        release()
        physicsBody?.angularVelocity = 0
    }
}
