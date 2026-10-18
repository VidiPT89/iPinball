import SpriteKit

final class BallNode: SKNode {

    /// The steel itself. The body rolls and spins, but the reflection on a
    /// polished ball stays where the lamps are, so the picture is turned back
    /// against the spin every frame instead of spinning with it.
    private let skin: SKSpriteNode
    /// The ball's own shadow, lying on the playfield. It lives in the scene
    /// rather than under the ball so it neither spins nor rides up the ramp.
    let shadow: SKSpriteNode
    private let radius: CGFloat

    private(set) var stuckSince: TimeInterval?
    private var lastPosition: CGPoint = .zero

    /// While a ramp is carrying the ball, physics is switched off.
    var isOnRamp = false
    var orbitEntry: (side: TableSide, time: TimeInterval)?

    /// How many times in a row the watchdog has had to free this ball, and
    /// when it last did. A ball that falls straight back into the same pocket
    /// gets a harder kick each time.
    private var freeStreak = 0
    private var lastFreedAt: TimeInterval = -.infinity

    init(radius: CGFloat) {
        self.radius = radius
        let diameter = radius * 2
        skin = SKSpriteNode(texture: TextureFactory.steelBall(diameter: diameter),
                            size: CGSize(width: diameter, height: diameter))
        shadow = SKSpriteNode(texture: TextureFactory.softShadow(diameter: diameter * 1.5),
                              size: CGSize(width: diameter * 1.5, height: diameter * 1.5))
        shadow.zPosition = TableDepth.dynamicShadow
        super.init()
        name = NodeName.ball
        zPosition = 60
        addChild(skin)

        let body = SKPhysicsBody(circleOfRadius: radius)
        body.mass = PhysicsTuning.ballMass
        body.restitution = PhysicsTuning.ballRestitution
        body.friction = PhysicsTuning.ballFriction
        body.linearDamping = PhysicsTuning.ballLinearDamping
        body.angularDamping = PhysicsTuning.ballAngularDamping
        body.allowsRotation = true
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = PhysicsCategory.ball
        body.collisionBitMask = PhysicsCategory.solid | PhysicsCategory.ball
        body.contactTestBitMask = PhysicsCategory.solid | PhysicsCategory.sensors
        physicsBody = body
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    var speed2D: CGFloat { physicsBody?.velocity.magnitude ?? 0 }

    /// Keeps the reflection still and lays the shadow down under the ball.
    /// A ball up on a ramp is well above the playfield, so its shadow falls
    /// further away and softer, which is what shows that it has left the table.
    func updateLighting() {
        skin.zRotation = -zRotation
        // Scene points per table width, recovered from the ball's own size.
        let scale = radius / TableLayout.ballRadius
        // The ball stands taller than a rail, so even on the playfield its
        // shadow reaches a little further out than the rails' do.
        let height: CGFloat = isOnRamp ? TableDepth.rampHeight : 1.8
        shadow.position = CGPoint(x: position.x + TableDepth.shadowOffset.dx * scale * height,
                                  y: position.y + TableDepth.shadowOffset.dy * scale * height)
        shadow.alpha = isOnRamp ? 0.45 : 0.8
        shadow.setScale(isOnRamp ? 1.25 : 1)
    }

    override func removeFromParent() {
        shadow.removeFromParent()
        super.removeFromParent()
    }

    /// Applies the per-frame speed clamp and keeps the stuck-ball watchdog fed.
    func stabilise(maxSpeed: CGFloat, radius: CGFloat, time: TimeInterval) {
        guard let body = physicsBody else { return }
        let speed = body.velocity.magnitude
        if speed > maxSpeed {
            body.velocity = body.velocity.normalized() * maxSpeed
        }

        if position.distance(to: lastPosition) > radius * PhysicsTuning.stuckDistanceRadii {
            lastPosition = position
            stuckSince = nil
        } else if stuckSince == nil {
            stuckSince = time
        }
    }

    func isStuck(at time: TimeInterval) -> Bool {
        guard let stuckSince else { return false }
        return time - stuckSince > PhysicsTuning.stuckTimeout
    }

    /// Records a watchdog kick and returns how hard the next one should be,
    /// as a multiple of the gentle first kick.
    func registerFree(at time: TimeInterval) -> CGFloat {
        let again = time - lastFreedAt < PhysicsTuning.stuckTimeout * 2.5
        freeStreak = again ? min(freeStreak + 1, 3) : 0
        lastFreedAt = time
        return CGFloat(1 + freeStreak)
    }

    func clearStuck() {
        stuckSince = nil
        lastPosition = position
    }

    func park(at point: CGPoint) {
        orbitEntry = nil
        position = point
        lastPosition = point
        stuckSince = nil
        physicsBody?.velocity = .zero
        physicsBody?.angularVelocity = 0
    }
}
