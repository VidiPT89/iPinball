import SpriteKit

/// A flipper on a pin joint. The joint limits do the work: pressing spins the
/// body until it hits the upper limit, releasing spins it back to the lower one.
final class FlipperNode: SKNode {

    let side: TableSide
    let isUpper: Bool
    let pivotInScene: CGPoint

    private let angleRange: CGFloat
    private let sign: CGFloat
    private let blade: SKShapeNode
    private let halo: SKShapeNode

    private(set) var isPressed = false

    init(config: TableLayout.Flipper, geometry: TableGeometry, palette: Palette) {
        side = config.side
        isUpper = config.isUpper
        pivotInScene = geometry.point(config.pivot)
        sign = config.side == .left ? 1 : -1

        let length = geometry.length(config.length)
        let thickness = geometry.length(config.thickness)
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

        blade.fillColor = palette.accent
        blade.strokeColor = palette.accentLight
        blade.lineWidth = max(1, thickness * 0.12)
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
        name = isUpper ? NodeName.flipperUpper
                       : (side == .left ? NodeName.flipperLeft : NodeName.flipperRight)
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
        physicsBody?.angularVelocity = sign * PhysicsTuning.flipperAngularSpeed
        halo.run(.customAction(withDuration: 0.001) { [weak self] node, _ in
            guard let self, let shape = node as? SKShapeNode else { return }
            shape.strokeColor = self.blade.strokeColor.withAlphaComponent(0.55)
        })
    }

    func release() {
        guard isPressed else { return }
        isPressed = false
        physicsBody?.angularVelocity = -sign * PhysicsTuning.flipperAngularSpeed * 0.7
        halo.strokeColor = halo.strokeColor.withAlphaComponent(0)
    }

    func repaint(with palette: Palette) {
        blade.fillColor = palette.accent
        blade.strokeColor = palette.accentLight
    }

    /// Cuts power to the flippers, as a real machine does on tilt.
    func disable() {
        release()
        physicsBody?.angularVelocity = 0
    }
}
