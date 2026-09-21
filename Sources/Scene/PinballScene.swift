import SpriteKit

/// The playfield. It owns the physics, forwards what happened to `GameSession`
/// and renders whatever the rules engine decides.
final class PinballScene: SKScene {

    // MARK: Injected

    weak var model: GameModel?
    var audio: AudioEngine?
    var haptics: HapticsEngine?
    var palette: Palette = .dark
    var reduceMotion = false
    var autoPlunge = false
    var ballCount = 3

    // MARK: State

    let session = GameSession()
    private(set) var parts = TableParts()
    private(set) var geometry = TableGeometry(sceneSize: CGSize(width: 390, height: 720))

    var balls: [BallNode] = []
    private var anchorBody = SKPhysicsBody()
    private var plunger: SKShapeNode?
    private var ballSaveRing: SKShapeNode?
    private var launchArrow: SKShapeNode?

    private(set) var sceneTime: TimeInterval = 0
    private var firstFrameTime: TimeInterval?
    private var lastHUDPush: TimeInterval = 0

    var plungerCharge: CGFloat = 0
    var orbitEntry: (side: TableSide, time: TimeInterval)?
    var ballsOnRamp: Set<ObjectIdentifier> = []
    var heldSaucers: Set<ObjectIdentifier> = []
    private var magnetActiveUntil: TimeInterval = 0

    var shooterLaneRect: CGRect {
        CGRect(x: 0.90, y: 0.10, width: 0.10, height: 1.10)
    }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = palette.background
        scaleMode = .resizeFill
        physicsWorld.gravity = PhysicsTuning.gravity
        physicsWorld.contactDelegate = self

        let camera = SKCameraNode()
        camera.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(camera)
        self.camera = camera

        rebuildTable()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard isNodeBuilt, oldSize != size else { return }
        camera?.position = CGPoint(x: size.width / 2, y: size.height / 2)
        rebuildTable()
    }

    private var isNodeBuilt = false
    /// Set when the container asks for a game before the table exists.
    private var startWhenReady = false

    /// The strip the HUD occupies, as a fraction of the scene height.
    private var hudInset: CGFloat { min(size.height * 0.16, 170) }

    private func rebuildTable() {
        children.filter { $0 !== camera }.forEach { $0.removeFromParent() }
        physicsWorld.removeAllJoints()
        balls.removeAll()

        geometry = TableGeometry(sceneSize: size, topInset: hudInset)
        let builder = TableBuilder(geometry: geometry, palette: palette)
        parts = builder.build(into: self)

        anchorBody = SKPhysicsBody(circleOfRadius: 1)
        anchorBody.isDynamic = false
        let anchor = SKNode()
        anchor.physicsBody = anchorBody
        addChild(anchor)

        for flipper in parts.flippers {
            flipper.attach(to: anchorBody, in: physicsWorld)
        }

        addPlunger()
        addBallSaveRing()
        isNodeBuilt = true

        // A rebuild wipes every node, so whatever was on the table has to be
        // put back: either the game that was waiting to start, or the ball
        // that a window resize just took away.
        if startWhenReady {
            startWhenReady = false
            startGame()
        } else if session.phase != .idle && session.phase != .gameOver {
            serveBall()
        }
    }

    private func addPlunger() {
        let width = geometry.length(0.055)
        let height = geometry.length(0.085)
        let node = SKShapeNode(rectOf: CGSize(width: width, height: height),
                               cornerRadius: width / 2)
        node.position = geometry.point(CGPoint(x: TableLayout.shooterLaneCenterX,
                                               y: TableLayout.shooterLaneBottomY))
        node.fillColor = palette.accentDark
        node.strokeColor = palette.accentLight
        node.lineWidth = 1.5
        node.zPosition = 22
        addChild(node)
        plunger = node

        let arrow = SKShapeNode(rectOf: CGSize(width: geometry.length(0.006),
                                               height: geometry.length(0.18)),
                                cornerRadius: geometry.length(0.003))
        arrow.position = geometry.point(CGPoint(x: TableLayout.shooterLaneCenterX,
                                                y: TableLayout.shooterLaneBottomY + 0.18))
        arrow.fillColor = palette.accent.withAlphaComponent(0.35)
        arrow.strokeColor = .clear
        arrow.zPosition = 21
        addChild(arrow)
        launchArrow = arrow
    }

    private func addBallSaveRing() {
        let radius = geometry.length(0.11)
        let ring = SKShapeNode(circleOfRadius: radius)
        ring.position = geometry.point(CGPoint(x: 0.5, y: 0.03))
        ring.strokeColor = palette.success
        ring.lineWidth = geometry.length(0.010)
        ring.glowWidth = geometry.length(0.006)
        ring.fillColor = .clear
        ring.alpha = 0
        ring.zPosition = 7
        addChild(ring)
        ballSaveRing = ring
    }

    // MARK: - Game control

    func startGame() {
        // `didMove` may not have run yet when the container asks for a game.
        guard isNodeBuilt else {
            startWhenReady = true
            return
        }
        _ = session.startGame(ballCount: ballCount, at: sceneTime)
        model?.resetForNewGame(ballCount: ballCount)
        resetTableElements()
        serveBall()
    }

    private func resetTableElements() {
        parts.dropTargets.forEach { $0.raise(reduceMotion: reduceMotion) }
        parts.rollovers.forEach { $0.setLit(false, palette: palette) }
        parts.standupTargets.forEach { $0.setLit(true) }
    }

    func serveBall() {
        balls.forEach { $0.removeFromParent() }
        balls.removeAll()
        ballsOnRamp.removeAll()
        heldSaucers.removeAll()

        let ball = spawnBall(at: TableLayout.ballStart)
        ball.physicsBody?.isDynamic = false
        plungerCharge = 0
        model?.showLaunchHint = true
        model?.ball = session.currentBall
        updatePlungerVisual()

        if autoPlunge {
            run(.sequence([.wait(forDuration: 0.8), .run { [weak self] in
                self?.plungerCharge = 0.72
                self?.firePlunger()
            }]))
        }
    }

    @discardableResult
    func spawnBall(at layoutPoint: CGPoint) -> BallNode {
        let radius = geometry.length(TableLayout.ballRadius)
        let ball = BallNode(radius: radius)
        ball.park(at: geometry.point(layoutPoint))
        addChild(ball)
        balls.append(ball)
        return ball
    }

    func removeBall(_ ball: BallNode) {
        ballsOnRamp.remove(ObjectIdentifier(ball))
        heldSaucers.remove(ObjectIdentifier(ball))
        balls.removeAll { $0 === ball }
        ball.removeFromParent()
    }

    // MARK: - Input from the container view

    func pressFlipper(side: TableSide, upper: Bool = false) {
        guard !session.isTilted, session.phase == .playing || session.phase == .ballReady else {
            return
        }
        for flipper in parts.flippers where flipper.side == side && flipper.isUpper == upper {
            flipper.press()
        }
        audio?.play(.flipper)
        haptics?.tap(.light)
    }

    func releaseFlipper(side: TableSide, upper: Bool = false) {
        for flipper in parts.flippers where flipper.side == side && flipper.isUpper == upper {
            flipper.release()
        }
    }

    func chargePlunger(to fraction: CGFloat) {
        guard session.phase == .ballReady else { return }
        plungerCharge = max(0, min(1, fraction))
        updatePlungerVisual()
        audio?.plungerCharge(plungerCharge)
    }

    func firePlunger() {
        guard session.phase == .ballReady, let ball = balls.first else { return }
        let charge = max(0.18, plungerCharge)
        ball.physicsBody?.isDynamic = true
        let speed = geometry.length(
            PhysicsTuning.plungerMinSpeed
            + (PhysicsTuning.plungerMaxSpeed - PhysicsTuning.plungerMinSpeed) * charge)
        ball.physicsBody?.velocity = CGVector(dx: 0, dy: speed)
        plungerCharge = 0
        updatePlungerVisual()
        model?.showLaunchHint = false
        audio?.play(.plunger)
        haptics?.tap(.medium)
        dispatch(.ballLaunched)
    }

    private func updatePlungerVisual() {
        guard let plunger else { return }
        let travel = geometry.length(0.075) * plungerCharge
        plunger.position = geometry.point(CGPoint(x: TableLayout.shooterLaneCenterX,
                                                  y: TableLayout.shooterLaneBottomY))
        plunger.position.y -= travel
        launchArrow?.alpha = session.phase == .ballReady ? 0.35 + plungerCharge * 0.5 : 0
    }

    func nudge(direction: CGFloat) {
        guard session.phase == .playing, !session.isTilted else { return }
        let speed = geometry.length(PhysicsTuning.nudgeSpeed)
        for ball in balls where !ball.isOnRamp {
            ball.physicsBody?.velocity.dx += speed * direction
            ball.physicsBody?.velocity.dy += speed * 0.25
        }
        if !reduceMotion {
            shakeCamera(intensity: 0.4)
        }
        audio?.play(.nudge)
        dispatch(.nudged)
    }

    func setPaused(_ paused: Bool) {
        isPaused = paused
        physicsWorld.speed = paused ? 0 : 1
    }

    // MARK: - Frame loop

    override func update(_ currentTime: TimeInterval) {
        if firstFrameTime == nil { firstFrameTime = currentTime }
        sceneTime = currentTime - (firstFrameTime ?? currentTime)

        guard !isPaused else { return }

        for effect in session.advance(to: sceneTime) {
            handle(effect)
        }

        let maxSpeed = geometry.length(PhysicsTuning.maxBallSpeed)
        let radius = geometry.length(TableLayout.ballRadius)

        for ball in balls where !ball.isOnRamp {
            ball.stabilise(maxSpeed: maxSpeed, radius: radius, time: sceneTime)
            if ball.isStuck(at: sceneTime) {
                freeStuckBall(ball)
            }
            if ball.shouldDropTrail(at: sceneTime, interval: 0.03), !reduceMotion {
                dropTrail(at: ball.position, speed: ball.speed2D, maxSpeed: maxSpeed)
            }
            applyMagnet(to: ball)
        }

        updateBallSaveRing()
        pushHUD()
    }

    override func didSimulatePhysics() {
        guard !isPaused else { return }
        // A ball that somehow ended up outside the table is recovered rather
        // than lost, so the player never sees a ball simply vanish.
        for ball in balls where !ball.isOnRamp {
            let local = CGPoint(x: (ball.position.x - geometry.origin.x) / geometry.scale,
                                y: (ball.position.y - geometry.origin.y) / geometry.scale)
            if local.x < -0.1 || local.x > 1.1 || local.y > TableLayout.height + 0.1 {
                ball.park(at: geometry.point(TableLayout.ballStart))
            }
        }
    }

    private func freeStuckBall(_ ball: BallNode) {
        let angle = CGFloat.random(in: (.pi * 0.2)...(.pi * 0.8))
        ball.physicsBody?.velocity = CGVector(
            angle: angle, magnitude: geometry.length(PhysicsTuning.stuckKickSpeed))
        ball.clearStuck()
        flash(at: ball.position, color: palette.accentLight, radius: geometry.length(0.08))
    }

    private func applyMagnet(to ball: BallNode) {
        guard sceneTime < magnetActiveUntil else {
            parts.magnetGlow?.alpha = max(0, (parts.magnetGlow?.alpha ?? 0) - 0.04)
            return
        }
        parts.magnetGlow?.alpha = min(0.55, (parts.magnetGlow?.alpha ?? 0) + 0.06)
        let centre = geometry.point(TableLayout.magnetCenter)
        let delta = CGVector(dx: centre.x - ball.position.x, dy: centre.y - ball.position.y)
        guard delta.magnitude < geometry.length(TableLayout.magnetRadius * 2) else { return }
        let pull = delta.normalized() * geometry.length(PhysicsTuning.magnetPull) * 0.06
        ball.physicsBody?.velocity.dx += pull.dx
        ball.physicsBody?.velocity.dy += pull.dy
    }

    func activateMagnet() {
        magnetActiveUntil = sceneTime + PhysicsTuning.magnetHoldDuration
    }

    private func updateBallSaveRing() {
        guard let ring = ballSaveRing else { return }
        guard let remaining = session.ballSaveRemaining, remaining > 0 else {
            if ring.alpha > 0 { ring.alpha = max(0, ring.alpha - 0.05) }
            return
        }
        let total = session.isMultiball ? PhysicsTuning.multiballSaveDuration
                                        : PhysicsTuning.ballSaveDuration
        let progress = CGFloat(remaining / total)
        ring.alpha = 0.35 + 0.45 * progress
        ring.setScale(0.35 + 0.65 * progress)
    }

    private func pushHUD() {
        guard sceneTime - lastHUDPush > 0.08, let model else { return }
        lastHUDPush = sceneTime
        model.ballSaveRemaining = session.ballSaveRemaining
        model.missionRemaining = session.missions.remainingTime
        if model.score != session.score.score {
            model.score = session.score.score
        }
    }

    // MARK: - Rules bridge

    func dispatch(_ event: TableEvent) {
        for effect in session.handle(event, at: sceneTime) {
            handle(effect)
        }
    }

    func handle(_ effect: GameEffect) {
        model?.apply(effect, session: session)
        audio?.play(for: effect)
        haptics?.play(for: effect)
        react(to: effect)
    }
}
