import SpriteKit

final class BallNode: SKSpriteNode {

    private var lastTrailDrop: TimeInterval = 0
    private(set) var stuckSince: TimeInterval?
    private var lastPosition: CGPoint = .zero

    /// While a ramp is carrying the ball, physics is switched off.
    var isOnRamp = false

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
        body.collisionBitMask = PhysicsCategory.solid
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

    func clearStuck() {
        stuckSince = nil
        lastPosition = position
    }

    func shouldDropTrail(at time: TimeInterval, interval: TimeInterval) -> Bool {
        guard time - lastTrailDrop >= interval else { return false }
        lastTrailDrop = time
        return true
    }

    func park(at point: CGPoint) {
        position = point
        lastPosition = point
        stuckSince = nil
        physicsBody?.velocity = .zero
        physicsBody?.angularVelocity = 0
    }
}
