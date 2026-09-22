import SpriteKit

/// Translates physics contacts into `TableEvent`s. This file decides *what
/// happened*; `GameSession` decides what it is worth and `+Effects` decides
/// what it looks like.
extension PinballScene: SKPhysicsContactDelegate {

    func didBegin(_ contact: SKPhysicsContact) {
        guard let (ball, other) = resolve(contact) else { return }
        guard !ball.isOnRamp else { return }

        switch other.categoryBitMask {
        case PhysicsCategory.bumper:
            hitBumper(ball, node: other.node)
        case PhysicsCategory.slingshot:
            hitSlingshot(ball, node: other.node)
        case PhysicsCategory.target:
            hitTarget(ball, node: other.node)
        case PhysicsCategory.rollover:
            hitRollover(other.node)
        case PhysicsCategory.spinner:
            hitSpinner(ball)
        case PhysicsCategory.saucer:
            enterSaucer(ball, node: other.node)
        case PhysicsCategory.rampEntrance:
            enterRamp(ball, node: other.node)
        case PhysicsCategory.orbitGate:
            passOrbitGate(ball, node: other.node)
        case PhysicsCategory.drain:
            drain(ball)
        default:
            break
        }
    }

    /// Returns the ball and the thing it touched, whichever order they arrived in.
    private func resolve(_ contact: SKPhysicsContact) -> (BallNode, SKPhysicsBody)? {
        if let ball = contact.bodyA.node as? BallNode { return (ball, contact.bodyB) }
        if let ball = contact.bodyB.node as? BallNode { return (ball, contact.bodyA) }
        return nil
    }

    // MARK: - Solid things that kick back

    private func hitBumper(_ ball: BallNode, node: SKNode?) {
        guard let bumper = node as? BumperNode else { return }
        bumper.pulse(reduceMotion: reduceMotion)
        kick(ball, awayFrom: bumper.position,
             speed: geometry.length(PhysicsTuning.bumperKickSpeed))
        shockwave(at: bumper.position, color: palette.accentLight,
                  radius: geometry.length(0.16))
        dispatch(.popBumper(index: bumper.index))
    }

    private func hitSlingshot(_ ball: BallNode, node: SKNode?) {
        guard let sling = node as? SlingshotNode else { return }
        sling.fire(palette: palette, reduceMotion: reduceMotion)
        // Slingshots throw the ball up and inwards, never straight back down.
        let inwards: CGFloat = sling.side == .left ? 1 : -1
        let angle = atan2(CGFloat(0.85), inwards * 0.55)
        ball.physicsBody?.velocity = CGVector(
            angle: angle, magnitude: geometry.length(PhysicsTuning.slingshotKickSpeed))
        dispatch(.slingshot(side: sling.side))
    }

    private func hitTarget(_ ball: BallNode, node: SKNode?) {
        guard let target = node as? TargetNode else { return }
        switch target.kind {
        case .drop:
            guard !target.isDown else { return }
            target.drop(reduceMotion: reduceMotion)
            flash(at: target.position, color: palette.accentLight,
                  radius: geometry.length(0.07))
            dispatch(.dropTarget(index: target.index))
        case .standup:
            target.flash(reduceMotion: reduceMotion)
            kick(ball, awayFrom: target.position,
                 speed: geometry.length(PhysicsTuning.slingshotKickSpeed * 0.7))
            if session.isJackpotLit {
                dispatch(.litJackpotHit)
            }
            dispatch(.standupTarget(index: target.index))
        }
    }

    // MARK: - Sensors

    private func hitRollover(_ node: SKNode?) {
        guard let rollover = node as? RolloverNode, !rollover.isLit else { return }
        rollover.setLit(true, palette: palette)
        dispatch(.rolloverLane(index: rollover.index))
    }

    private func hitSpinner(_ ball: BallNode) {
        guard let spinner = parts.spinner else { return }
        let rotations = spinner.spin(speed: ball.speed2D,
                                     reference: geometry.length(PhysicsTuning.maxBallSpeed))
        for _ in 0..<rotations {
            dispatch(.spinnerRotation)
        }
    }

    private func enterSaucer(_ ball: BallNode, node: SKNode?) {
        guard let saucer = node as? SaucerNode else { return }
        let id = ObjectIdentifier(ball)
        guard !heldSaucers.contains(id) else { return }
        guard sceneTime >= saucerReadyAt[saucer.side, default: 0] else { return }
        heldSaucers.insert(id)

        saucer.pulse()
        ball.park(at: saucer.position)
        ball.physicsBody?.isDynamic = false
        dispatch(.saucerEntered(side: saucer.side))

        // Hold the ball for a beat so the mission banner has time to read,
        // then spit it back out along the saucer's own exit angle.
        run(.sequence([
            .wait(forDuration: PhysicsTuning.saucerHoldDuration),
            .run { [weak self, weak ball, weak saucer] in
                guard let self, let ball, let saucer,
                      self.balls.contains(where: { $0 === ball }) else { return }
                ball.physicsBody?.isDynamic = true
                ball.physicsBody?.velocity = CGVector(
                    angle: saucer.ejectAngle,
                    magnitude: self.geometry.length(PhysicsTuning.saucerEjectSpeed))
                self.heldSaucers.remove(ObjectIdentifier(ball))
                self.saucerReadyAt[saucer.side] =
                    self.sceneTime + PhysicsTuning.saucerCooldown
            },
        ]))
    }

    /// Ramps are scripted, not simulated: a real habitrail is a 3D wireframe
    /// and a 2D solver cannot hold a ball on one. Physics is switched off for
    /// the trip and the ball is flown along the rail instead.
    private func enterRamp(_ ball: BallNode, node: SKNode?) {
        guard let name = node?.name, name.hasPrefix("ramp.") else { return }
        let sideKey = String(name.dropFirst("ramp.".count))
        guard let side = TableSide(rawValue: sideKey),
              let ramp = TableLayout.ramps.first(where: { $0.side == side }) else { return }

        let id = ObjectIdentifier(ball)
        guard !ballsOnRamp.contains(id) else { return }
        // A slow ball rolls past the mouth instead of making the climb.
        guard ball.speed2D > geometry.length(PhysicsTuning.rampExitSpeed * 0.45) else { return }

        ballsOnRamp.insert(id)
        ball.isOnRamp = true
        ball.physicsBody?.isDynamic = false
        ball.zPosition = 80

        let travel = SKAction.follow(geometry.smoothPath(through: ramp.path),
                                     asOffset: false, orientToPath: false,
                                     duration: PhysicsTuning.rampTravelDuration)
        travel.timingMode = .easeInEaseOut

        ball.run(.sequence([
            .group([travel, .scale(to: 1.12, duration: PhysicsTuning.rampTravelDuration)]),
            .scale(to: 1.0, duration: 0.08),
            .run { [weak self, weak ball] in
                guard let self, let ball else { return }
                ball.isOnRamp = false
                ball.zPosition = 60
                ball.physicsBody?.isDynamic = true
                ball.physicsBody?.velocity = CGVector(
                    angle: ramp.exitAngle,
                    magnitude: self.geometry.length(PhysicsTuning.rampExitSpeed))
                ball.clearStuck()
                self.ballsOnRamp.remove(ObjectIdentifier(ball))
                self.dispatch(.rampCompleted(side: side))
            },
        ]))
    }

    /// An orbit only counts when the ball enters one gate and leaves by the
    /// other, which is what separates a full loop from a rattle at the entry.
    private func passOrbitGate(_ ball: BallNode, node: SKNode?) {
        guard let name = node?.name, name.hasPrefix("orbit.") else { return }
        let sideKey = String(name.dropFirst("orbit.".count))
        guard let side = TableSide(rawValue: sideKey) else { return }

        if let entry = orbitEntry, entry.side != side,
           sceneTime - entry.time < PhysicsTuning.comboWindow {
            orbitEntry = nil
            dispatch(.orbitCompleted(side: side))
        } else {
            orbitEntry = (side, sceneTime)
        }
    }

    // MARK: - Drain

    private func drain(_ ball: BallNode) {
        guard balls.contains(where: { $0 === ball }) else { return }
        removeBall(ball)
        drainSparks(at: CGPoint(x: ball.position.x,
                                y: geometry.point(CGPoint(x: 0, y: 0.02)).y))
        dispatch(.ballDrained)
    }

    // MARK: - Helpers

    private func kick(_ ball: BallNode, awayFrom centre: CGPoint, speed: CGFloat) {
        var delta = CGVector(dx: ball.position.x - centre.x,
                             dy: ball.position.y - centre.y)
        if delta.magnitude < 0.001 {
            delta = CGVector(dx: CGFloat.random(in: -1...1), dy: 1)
        }
        ball.physicsBody?.velocity = delta.normalized() * speed
    }
}
