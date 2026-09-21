import SpriteKit

/// Everything the table does that is purely for the eyes, plus the small
/// amount of ball choreography that has to follow a rules decision.
extension PinballScene {

    // MARK: - Reacting to rules

    func react(to effect: GameEffect) {
        switch effect {
        case .scored(let points, let label):
            popScore(points, label: label)

        case .dropTargetDown(let index):
            parts.dropTargets.first { $0.index == index }?.drop(reduceMotion: reduceMotion)

        case .dropBankReset:
            // Staggered so the bank pops back up like a real machine.
            for (offset, target) in parts.dropTargets.enumerated() {
                target.run(.sequence([
                    .wait(forDuration: 0.30 + Double(offset) * 0.05),
                    .run { [weak self] in
                        target.raise(reduceMotion: self?.reduceMotion ?? false)
                    },
                ]))
            }
            sweepLights()

        case .laneLit(let index):
            parts.rollovers.first { $0.index == index }?.setLit(true, palette: palette)

        case .laneSetCompleted:
            parts.rollovers.forEach { $0.setLit(false, palette: palette) }
            sweepLights()

        case .jackpotLit:
            parts.standupTargets.forEach { $0.setLit(true) }
            pulseRails(times: 6)
            activateMagnet()

        case .jackpotCollected, .superJackpotCollected:
            whiteFlash()
            shakeCamera(intensity: 1.0)
            slowMotion()

        case .multiballStarted(let count):
            startMultiball(count: count)

        case .missionStarted:
            pulseRails(times: 3)

        case .missionCompleted:
            whiteFlash()
            shakeCamera(intensity: 0.7)

        case .wizardModeStarted:
            pulseRails(times: 10)
            slowMotion()

        case .tilted:
            parts.flippers.forEach { $0.disable() }
            shakeCamera(intensity: 1.2)
            run(.sequence([.wait(forDuration: 1.4), .run { [weak self] in
                self?.finishTilt()
            }]))

        case .tiltWarning:
            shakeCamera(intensity: 0.5)

        case .ballSaved:
            run(.sequence([.wait(forDuration: 0.35),
                           .run { [weak self] in self?.serveBall() }]))

        case .ballLost:
            run(.sequence([.wait(forDuration: 0.7),
                           .run { [weak self] in self?.serveBall() }]))

        case .gameOver:
            endGame()

        case .comboChanged, .playerMultiplierChanged, .missionProgressed,
             .missionFailed, .multiballEnded, .ballSaveArmed, .extraBallAwarded,
             .bonusAwarded:
            break
        }
    }

    private func finishTilt() {
        // Every ball comes off the table, including the other multiball ones,
        // so what is on screen matches what the session thinks is in play.
        balls.forEach { $0.removeFromParent() }
        balls.removeAll()
        ballsOnRamp.removeAll()
        heldSaucers.removeAll()

        for effect in session.resolveTilt(at: sceneTime) {
            handle(effect)
        }
    }

    private func endGame() {
        balls.forEach { $0.removeFromParent() }
        balls.removeAll()
        ballsOnRamp.removeAll()
        heldSaucers.removeAll()
    }

    private func startMultiball(count: Int) {
        // One ball is already live; the rest drop in from the bumper nest.
        let extras = max(0, count - max(1, balls.count))
        for index in 0..<extras {
            run(.sequence([
                .wait(forDuration: 0.18 * Double(index)),
                .run { [weak self] in
                    guard let self else { return }
                    let spawn = CGPoint(x: 0.5 + CGFloat(index - 1) * 0.06, y: 1.12)
                    let ball = self.spawnBall(at: spawn)
                    ball.physicsBody?.velocity = CGVector(
                        angle: -.pi / 2 + CGFloat.random(in: -0.4...0.4),
                        magnitude: self.geometry.length(0.6))
                    self.flash(at: ball.position, color: self.palette.accentLight,
                               radius: self.geometry.length(0.12))
                },
            ]))
        }
        whiteFlash()
        shakeCamera(intensity: 0.8)
    }

    // MARK: - Ball trail

    func dropTrail(at point: CGPoint, speed: CGFloat, maxSpeed: CGFloat) {
        let intensity = min(1, speed / max(maxSpeed, 1))
        guard intensity > 0.12 else { return }

        let radius = geometry.length(TableLayout.ballRadius) * (0.45 + 0.35 * intensity)
        let dot = SKShapeNode(circleOfRadius: radius)
        dot.position = point
        dot.fillColor = palette.accentLight.withAlphaComponent(0.5 * intensity)
        dot.strokeColor = .clear
        dot.blendMode = .add
        dot.zPosition = 55
        addChild(dot)
        dot.run(.sequence([
            .group([.fadeOut(withDuration: 0.28), .scale(to: 0.2, duration: 0.28)]),
            .removeFromParent(),
        ]))
    }

    // MARK: - Impact flourishes

    func flash(at point: CGPoint, color: PlatformColor, radius: CGFloat) {
        guard !reduceMotion else { return }
        let glow = SKSpriteNode(texture: TextureFactory.radialGlow(
            diameter: radius * 2, color: color))
        glow.size = CGSize(width: radius * 2, height: radius * 2)
        glow.position = point
        glow.blendMode = .add
        glow.zPosition = 70
        addChild(glow)
        glow.run(.sequence([
            .group([.scale(to: 1.7, duration: Motion.shockwave),
                    .fadeOut(withDuration: Motion.shockwave)]),
            .removeFromParent(),
        ]))
    }

    func shockwave(at point: CGPoint, color: PlatformColor, radius: CGFloat) {
        guard !reduceMotion else { return }
        let ring = SKShapeNode(circleOfRadius: radius * 0.4)
        ring.position = point
        ring.strokeColor = color
        ring.lineWidth = geometry.length(0.006)
        ring.glowWidth = geometry.length(0.004)
        ring.fillColor = .clear
        ring.zPosition = 68
        addChild(ring)
        ring.run(.sequence([
            .group([.scale(to: 2.6, duration: Motion.shockwave),
                    .fadeOut(withDuration: Motion.shockwave)]),
            .removeFromParent(),
        ]))
    }

    func drainSparks(at point: CGPoint) {
        guard !reduceMotion else { return }
        for _ in 0..<10 {
            let spark = SKShapeNode(circleOfRadius: geometry.length(0.005))
            spark.position = point
            spark.fillColor = palette.danger
            spark.strokeColor = .clear
            spark.blendMode = .add
            spark.zPosition = 72
            addChild(spark)

            let angle = CGFloat.random(in: (.pi * 0.15)...(.pi * 0.85))
            let distance = geometry.length(CGFloat.random(in: 0.05...0.16))
            spark.run(.sequence([
                .group([
                    .move(by: CGVector(angle: angle, magnitude: distance), duration: 0.45),
                    .fadeOut(withDuration: 0.45),
                ]),
                .removeFromParent(),
            ]))
        }
    }

    /// The floating number that rises off the point of impact.
    private func popScore(_ points: Int, label: ScoreLabel) {
        guard !reduceMotion, points >= ScoreValue.standupTarget else { return }
        guard let ball = balls.first(where: { !$0.isOnRamp }) ?? balls.first else { return }

        let text = SKLabelNode(text: points.grouped)
        text.fontName = "AvenirNextCondensed-Heavy"
        text.fontSize = geometry.length(points >= ScoreValue.jackpot ? 0.075 : 0.05)
        text.fontColor = points >= ScoreValue.jackpot ? palette.accentLight : palette.textPrimary
        text.position = CGPoint(x: ball.position.x,
                                y: ball.position.y + geometry.length(0.04))
        text.zPosition = 90
        text.setScale(0.6)
        addChild(text)
        text.run(.sequence([
            .group([
                .scale(to: 1.0, duration: 0.12),
                .moveBy(x: 0, y: geometry.length(0.10), duration: Motion.floatingScore),
                .sequence([.wait(forDuration: Motion.floatingScore * 0.5),
                           .fadeOut(withDuration: Motion.floatingScore * 0.5)]),
            ]),
            .removeFromParent(),
        ]))
    }

    // MARK: - Whole-table flourishes

    func shakeCamera(intensity: CGFloat) {
        guard !reduceMotion, let camera else { return }
        let home = CGPoint(x: size.width / 2, y: size.height / 2)
        let amount = geometry.length(0.012) * intensity
        var steps: [SKAction] = []
        for _ in 0..<5 {
            steps.append(.move(to: CGPoint(x: home.x + .random(in: -amount...amount),
                                           y: home.y + .random(in: -amount...amount)),
                               duration: Motion.screenShake / 5))
        }
        steps.append(.move(to: home, duration: Motion.screenShake / 5))
        camera.removeAllActions()
        camera.run(.sequence(steps))
    }

    /// Time dials back for a moment so a jackpot lands instead of flashing past.
    func slowMotion() {
        guard !reduceMotion else { return }
        physicsWorld.speed = 0.35
        run(.sequence([
            .wait(forDuration: Motion.slowMotion),
            .run { [weak self] in
                guard let self, !self.isPaused else { return }
                self.physicsWorld.speed = 1
            },
        ]))
    }

    func whiteFlash() {
        guard !reduceMotion else { return }
        let sheet = SKSpriteNode(color: palette.accentLight,
                                 size: CGSize(width: size.width * 1.2,
                                              height: size.height * 1.2))
        sheet.position = CGPoint(x: size.width / 2, y: size.height / 2)
        sheet.alpha = 0
        sheet.blendMode = .add
        sheet.zPosition = 95
        addChild(sheet)
        sheet.run(.sequence([
            .fadeAlpha(to: 0.28, duration: Motion.jackpotFlash),
            .fadeOut(withDuration: Motion.jackpotFlash * 2.5),
            .removeFromParent(),
        ]))
    }

    /// Runs the rail glow up and down, the way a real machine flashes its
    /// inserts when something big happens.
    func pulseRails(times: Int) {
        guard let rails = parts.rails else { return }
        rails.removeAllActions()
        let base = geometry.length(0.006)
        rails.run(.sequence([
            .repeat(.sequence([
                .customAction(withDuration: 0.12) { node, _ in
                    (node as? SKShapeNode)?.glowWidth = base * 4
                },
                .customAction(withDuration: 0.12) { node, _ in
                    (node as? SKShapeNode)?.glowWidth = base
                },
            ]), count: max(1, times)),
            .customAction(withDuration: 0.01) { node, _ in
                (node as? SKShapeNode)?.glowWidth = base
            },
        ]))
    }

    private func sweepLights() {
        guard !reduceMotion else { return }
        for (index, rollover) in parts.rollovers.enumerated() {
            rollover.run(.sequence([
                .wait(forDuration: Double(index) * 0.06),
                .scale(to: 1.35, duration: 0.10),
                .scale(to: 1.0, duration: 0.14),
            ]))
        }
    }

    // MARK: - Theme

    /// Repaints the live table when the player flips the theme mid-game,
    /// instead of rebuilding the scene and losing the ball.
    func repaint(with newPalette: Palette) {
        palette = newPalette
        TextureFactory.purge()
        backgroundColor = newPalette.background
        parts.flippers.forEach { $0.repaint(with: newPalette) }
        parts.bumpers.forEach { $0.repaint(with: newPalette) }
        parts.dropTargets.forEach { $0.repaint(with: newPalette) }
        parts.standupTargets.forEach { $0.repaint(with: newPalette) }
        parts.saucers.forEach { $0.repaint(with: newPalette) }
        parts.slingshots.forEach { $0.repaint(with: newPalette) }
        parts.spinner?.repaint(with: newPalette)
        parts.rails?.strokeColor = newPalette.accent.withAlphaComponent(0.75)
        for rollover in parts.rollovers {
            rollover.setLit(rollover.isLit, palette: newPalette)
        }
    }
}
