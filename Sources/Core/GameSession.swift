import Foundation

/// The referee. It owns the phase of the game, the balls, the ball save, the
/// tilt and every decision about what an event is worth. Nothing here knows
/// that SpriteKit exists.
final class GameSession {

    let score = ScoreEngine()
    let missions = MissionEngine()

    private(set) var phase: GamePhase = .idle
    private(set) var ballCount = 3
    private(set) var currentBall = 1
    private(set) var ballsInPlay = 0
    private(set) var extraBalls = 0
    private(set) var ballSaveEndsAt: TimeInterval?
    private(set) var dropTargetsDown: Set<Int> = []
    /// The lit P-I-N-B lanes. The score engine owns them, since completing
    /// the set is what raises its multiplier.
    var litLanes: Set<Int> { score.litLanes }
    /// The rollover lane worth a skill shot, while one is on offer. It walks
    /// across the lanes while the ball sits in the shooter lane and freezes on
    /// launch; the plunge has to drop the ball through that lane to collect.
    private(set) var skillShotLane: Int?
    private var skillShotExpiresAt: TimeInterval?

    private var nudgeTimestamps: [TimeInterval] = []
    /// A ball gets one save. Without this the save re-armed on every
    /// re-plunge, and a player who drained inside eight seconds each time
    /// could never lose the ball at all.
    private var ballSaveSpent = false
    private var now: TimeInterval = 0
    private var extraBallGivenForScore = false
    private var extraBallGivenForMissions = false
    private var extraBallGivenForBanks = false

    var isMultiball: Bool { ballsInPlay > 1 }
    var isTilted: Bool { phase == .tilted }

    /// Derived rather than stored. As a flag it used to be switched off when
    /// multiball ended or the ball drained, which could strand Jackpot Hunt
    /// with no lit shot left and make the rest of the mission chain — and the
    /// wizard mode behind it — unreachable for the rest of the game.
    var isJackpotLit: Bool {
        isMultiball || missions.active?.id == "jackpotHunt"
    }

    /// The saucers flash while a shot into one would do something: start the
    /// next mission, or count towards Lock 3. It is the only way the table has
    /// of telling a new player where missions begin.
    var isSaucerLit: Bool {
        guard phase == .playing else { return false }
        if let active = missions.active { return active.startsMultiball }
        return missions.nextMission != nil
    }

    var ballSaveRemaining: TimeInterval? {
        guard let end = ballSaveEndsAt else { return nil }
        return max(0, end - now)
    }

    var isBallSaveActive: Bool { (ballSaveRemaining ?? 0) > 0 }

    // MARK: - Lifecycle

    func startGame(ballCount: Int, at time: TimeInterval) -> [GameEffect] {
        self.ballCount = max(1, ballCount)
        currentBall = 1
        ballsInPlay = 0
        extraBalls = 0
        dropTargetsDown.removeAll()
        nudgeTimestamps.removeAll()
        skillShotExpiresAt = nil
        skillShotLane = Self.skillShotLane(at: time)
        ballSaveSpent = false
        ballSaveEndsAt = nil
        extraBallGivenForScore = false
        extraBallGivenForMissions = false
        extraBallGivenForBanks = false
        score.reset()
        missions.reset()
        now = time
        phase = .ballReady
        return []
    }

    func launchBall(at time: TimeInterval) -> [GameEffect] {
        now = time
        guard phase == .ballReady else { return [] }
        phase = .playing
        ballsInPlay = 1
        skillShotLane = Self.skillShotLane(at: time)
        skillShotExpiresAt = time + PhysicsTuning.skillShotWindow
        guard !ballSaveSpent else {
            ballSaveEndsAt = nil
            return []
        }
        ballSaveEndsAt = time + PhysicsTuning.ballSaveDuration
        return [.ballSaveArmed(duration: PhysicsTuning.ballSaveDuration)]
    }

    /// Drives the clocks. Call once per frame with the scene's current time.
    func advance(to time: TimeInterval) -> [GameEffect] {
        now = time
        score.advance(to: time)
        advanceSkillShot(to: time)
        var effects: [GameEffect] = []
        if let failure = missions.advance(to: time) {
            effects.append(failure)
        }
        return effects
    }

    // MARK: - Events

    func handle(_ event: TableEvent, at time: TimeInterval) -> [GameEffect] {
        now = time
        score.advance(to: time)

        if phase == .tilted {
            // While tilted only the drain still matters.
            if case .ballDrained = event { return drain() }
            return []
        }

        if case .ballLaunched = event { return launchBall(at: time) }
        guard phase == .playing else { return [] }
        advanceSkillShot(to: time)
        var effects: [GameEffect] = []

        switch event {
        case .popBumper:
            effects.append(awarded(ScoreValue.popBumper, .bumper))

        case .slingshot:
            effects.append(awarded(ScoreValue.slingshot, .slingshot))

        case .standupTarget:
            effects.append(awarded(ScoreValue.standupTarget, .target))

        case .dropTarget(let index):
            guard TableLayout.dropTargets.indices.contains(index),
                  !dropTargetsDown.contains(index) else { return [] }
            dropTargetsDown.insert(index)
            score.registerDropTarget()
            effects.append(.dropTargetDown(index: index))
            effects.append(awarded(ScoreValue.dropTarget, .dropTarget))
            if dropTargetsDown.count >= TableLayout.dropTargets.count {
                effects.append(contentsOf: clearBank())
            }

        case .spinnerRotation:
            effects.append(awarded(ScoreValue.spinnerRotation, .spinner))

        case .rampCompleted:
            score.registerComboShot()
            score.registerLoop()
            effects.append(awarded(ScoreValue.ramp, .ramp))
            effects.append(.comboChanged(multiplier: score.comboMultiplier))

        case .orbitCompleted:
            score.registerComboShot()
            score.registerLoop()
            effects.append(awarded(ScoreValue.orbit, .orbit))
            effects.append(.comboChanged(multiplier: score.comboMultiplier))

        case .rolloverLane(let index):
            guard (0..<LaneLetter.allCases.count).contains(index) else { return [] }
            effects.append(contentsOf: collectSkillShot(through: index))
            guard !litLanes.contains(index) else { break }
            effects.append(.laneLit(index: index))
            if score.lightLane(index) {
                effects.append(.laneSetCompleted)
                effects.append(awarded(ScoreValue.laneSetCompleted, .laneSet))
                effects.append(.playerMultiplierChanged(value: score.playerMultiplier))
            }

        case .saucerEntered:
            effects.append(contentsOf: handleSaucer())

        case .litJackpotHit:
            guard isJackpotLit else { break }
            let isSuper = missions.completed.contains("jackpotHunt")
            let base = isSuper ? ScoreValue.superJackpot : ScoreValue.jackpot
            let total = score.award(base)
            effects.append(isSuper ? .superJackpotCollected(points: total)
                                   : .jackpotCollected(points: total))

        case .ballLaunched:
            return launchBall(at: time)

        case .nudged:
            return handleNudge(at: time)

        case .ballDrained:
            return drain()
        }

        effects.append(contentsOf: missions.handle(event, at: time))
        effects.append(contentsOf: applyMissionOutcomes(in: effects))
        effects.append(contentsOf: checkExtraBall())
        return effects
    }

    // MARK: - Skill shot and lane change

    /// Which lane the skill shot sits on at a given moment while it is still
    /// walking. Derived from the clock so it needs no timer of its own.
    static func skillShotLane(at time: TimeInterval) -> Int {
        let step = Int(max(0, time) / PhysicsTuning.skillShotStep)
        return step % LaneLetter.allCases.count
    }

    private func advanceSkillShot(to time: TimeInterval) {
        switch phase {
        case .ballReady:
            skillShotLane = Self.skillShotLane(at: time)
        case .playing:
            if let expiry = skillShotExpiresAt, time > expiry {
                skillShotLane = nil
                skillShotExpiresAt = nil
            }
        default:
            skillShotLane = nil
            skillShotExpiresAt = nil
        }
    }

    /// The first lane the plunge reaches settles the skill shot either way.
    private func collectSkillShot(through index: Int) -> [GameEffect] {
        guard phase == .playing, let lane = skillShotLane else { return [] }
        skillShotLane = nil
        skillShotExpiresAt = nil
        guard lane == index else { return [] }
        score.isMultiballActive = isMultiball
        return [.skillShotCollected(points: score.award(ScoreValue.skillShot))]
    }

    /// Lane change: each flipper press moves the lit lanes one place towards
    /// that flipper's side. Nothing moves when there is nothing to steer.
    func rotateLanes(towards side: TableSide) -> [GameEffect] {
        guard phase == .playing, !litLanes.isEmpty,
              litLanes.count < LaneLetter.allCases.count else { return [] }
        score.rotateLanes(by: side == .left ? -1 : 1)
        return [.lanesRotated(lit: litLanes)]
    }

    // MARK: - Pieces

    private func awarded(_ base: Int, _ label: ScoreLabel) -> GameEffect {
        score.isMultiballActive = isMultiball
        return .scored(points: score.award(base), label: label)
    }

    private func clearBank() -> [GameEffect] {
        dropTargetsDown.removeAll()
        score.registerBankClear()
        return [
            .dropBankReset,
            awarded(ScoreValue.dropBankCleared, .bankClear),
            .playerMultiplierChanged(value: score.playerMultiplier),
        ]
    }

    private func handleSaucer() -> [GameEffect] {
        var effects: [GameEffect] = []
        if let started = missions.startNextMission(at: now) {
            effects.append(.missionStarted(id: started.id))
            if isJackpotLit {
                effects.append(.jackpotLit)
            }
            if started.isWizard {
                effects.append(.wizardModeStarted)
            }
        }
        return effects
    }

    /// Turns mission completions into their rewards. Kept separate so the
    /// reward rules live in one readable place.
    private func applyMissionOutcomes(in effects: [GameEffect]) -> [GameEffect] {
        var extra: [GameEffect] = []
        for effect in effects {
            guard case .missionCompleted(let id, let reward) = effect,
                  let mission = MissionEngine.mission(withID: id) else { continue }

            if reward > 0 {
                score.addRaw(reward * score.playerMultiplier)
            }
            if mission.grantsMultiplier {
                score.raisePlayerMultiplier()
                extra.append(.playerMultiplierChanged(value: score.playerMultiplier))
            }
            if mission.startsMultiball {
                extra.append(contentsOf: startMultiball())
            }
            if mission.isWizard {
                extra.append(contentsOf: grantExtraBall())
            }
        }
        return extra
    }

    private func startMultiball() -> [GameEffect] {
        ballsInPlay = 3
        score.isMultiballActive = true
        ballSaveEndsAt = now + PhysicsTuning.multiballSaveDuration
        return [
            .multiballStarted(balls: 3),
            .jackpotLit,
            .ballSaveArmed(duration: PhysicsTuning.multiballSaveDuration),
        ]
    }

    private func handleNudge(at time: TimeInterval) -> [GameEffect] {
        nudgeTimestamps.append(time)
        nudgeTimestamps.removeAll { time - $0 > PhysicsTuning.nudgeWindow }

        if nudgeTimestamps.count >= PhysicsTuning.nudgesBeforeTilt {
            phase = .tilted
            nudgeTimestamps.removeAll()
            return [.tilted]
        }
        if nudgeTimestamps.count == PhysicsTuning.nudgesBeforeTilt - 1 {
            return [.tiltWarning]
        }
        return []
    }

    private func checkExtraBall() -> [GameEffect] {
        var effects: [GameEffect] = []
        if !extraBallGivenForScore, score.score >= ScoreValue.extraBallScoreThreshold {
            extraBallGivenForScore = true
            effects.append(contentsOf: grantExtraBall())
        }
        if !extraBallGivenForMissions,
           missions.completed.count >= ScoreValue.extraBallMissionCount {
            extraBallGivenForMissions = true
            effects.append(contentsOf: grantExtraBall())
        }
        if !extraBallGivenForBanks, score.bankClears >= ScoreValue.extraBallBankClears {
            extraBallGivenForBanks = true
            effects.append(contentsOf: grantExtraBall())
        }
        return effects
    }

    private func grantExtraBall() -> [GameEffect] {
        extraBalls += 1
        return [.extraBallAwarded]
    }

    // MARK: - Draining

    private func drain() -> [GameEffect] {
        guard phase != .gameOver else { return [] }

        if ballsInPlay > 1 {
            if phase != .tilted, isBallSaveActive {
                return [.multiballBallSaved]
            }
            ballsInPlay -= 1
            if ballsInPlay == 1 {
                score.isMultiballActive = false
                return [.multiballEnded]
            }
            return []
        }

        if phase != .tilted, isBallSaveActive {
            ballSaveEndsAt = nil
            ballSaveSpent = true
            ballsInPlay = 0
            phase = .ballReady
            return [.ballSaved]
        }

        ballsInPlay = 0
        var effects: [GameEffect] = []
        if let missionFailure = missions.handleBallDrained() {
            effects.append(missionFailure)
        }

        let bonus = score.bonusReport()
        if bonus.total > 0, phase != .tilted {
            score.addRaw(bonus.total)
            effects.append(.bonusAwarded(bonus))
            effects.append(contentsOf: checkExtraBall())
        }

        score.resetBallCounters()
        dropTargetsDown.removeAll()
        score.isMultiballActive = false
        ballSaveEndsAt = nil
        ballSaveSpent = false
        nudgeTimestamps.removeAll()

        if extraBalls > 0 {
            extraBalls -= 1
            phase = .ballReady
            effects.append(.ballLost(ballsRemaining: ballsRemaining))
            effects.append(.shootAgain)
            return effects
        }

        if currentBall >= ballCount {
            phase = .gameOver
            effects.append(.gameOver(score: score.score))
            return effects
        }

        currentBall += 1
        phase = .ballReady
        effects.append(.ballLost(ballsRemaining: ballsRemaining))
        return effects
    }

    var ballsRemaining: Int {
        max(0, ballCount - currentBall) + extraBalls
    }

    // MARK: - Manual control

    /// Recovering from a tilt simply drains the ball, as on a real machine.
    ///
    /// The phase deliberately stays `.tilted` through the drain: that is what
    /// makes it skip the ball save and the bonus. A tilt always costs a ball,
    /// however much of the save was still running.
    ///
    /// Multiball is collapsed first. Without that, `drain` would only take one
    /// ball off the count and return nothing, leaving the table stuck in
    /// `.tilted` with dead flippers and balls still rolling.
    func resolveTilt(at time: TimeInterval) -> [GameEffect] {
        now = time
        guard phase == .tilted else { return [] }
        let wasMultiball = isMultiball
        ballsInPlay = 1
        score.isMultiballActive = false
        return (wasMultiball ? [.multiballEnded] : []) + drain()
    }
}
