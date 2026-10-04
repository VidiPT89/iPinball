import SpriteKit

final class BallNode: SKSpriteNode {

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
        let diameter = radius * 2
        let texture = TextureFactory.steelBall(diameter: diameter)
        super.init(texture: texture, color: .clear,
                   size: CGSize(width: diameter, height: diameter))
        name = NodeName.ball
        zPosition = 60

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
