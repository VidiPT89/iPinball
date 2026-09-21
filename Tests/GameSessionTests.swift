import XCTest
@testable import iPinball

final class GameSessionTests: XCTestCase {

    private var session: GameSession!

    override func setUp() {
        super.setUp()
        session = GameSession()
        _ = session.startGame(ballCount: 3, at: 0)
    }

    // MARK: - Lifecycle

    func testANewGameStartsWithTheBallWaiting() {
        XCTAssertEqual(session.phase, .ballReady)
        XCTAssertEqual(session.currentBall, 1)
        XCTAssertEqual(session.score.score, 0)
        XCTAssertFalse(session.isMultiball)
    }

    func testLaunchingArmsTheBallSave() {
        let effects = session.launchBall(at: 0)
        XCTAssertEqual(effects, [.ballSaveArmed(duration: PhysicsTuning.ballSaveDuration)])
        XCTAssertEqual(session.phase, .playing)
        XCTAssertTrue(session.isBallSaveActive)
    }

    func testEventsBeforeTheBallIsLiveStillScore() {
        _ = session.launchBall(at: 0)
        _ = session.handle(.popBumper(index: 0), at: 1)
        XCTAssertEqual(session.score.score, ScoreValue.popBumper)
    }

    // MARK: - Ball save

    func testDrainingInsideTheSaveWindowReturnsTheBall() {
        _ = session.launchBall(at: 0)
        let effects = session.handle(.ballDrained, at: 1)

        XCTAssertEqual(effects, [.ballSaved])
        XCTAssertEqual(session.currentBall, 1, "a saved ball is not a spent ball")
        XCTAssertEqual(session.phase, .ballReady)
    }

    func testDrainingAfterTheSaveWindowCostsTheBall() {
        _ = session.launchBall(at: 0)
        let effects = session.handle(.ballDrained,
                                     at: PhysicsTuning.ballSaveDuration + 1)

        XCTAssertTrue(effects.contains(.ballLost(ballsRemaining: 1)))
        XCTAssertEqual(session.currentBall, 2)
    }

    func testTheSaveIsSpentAndDoesNotCoverASecondDrain() {
        _ = session.launchBall(at: 0)
        _ = session.handle(.ballDrained, at: 1)
        _ = session.launchBall(at: 2)
        // Re-launching arms a fresh save, so push past it.
        let effects = session.handle(.ballDrained,
                                     at: 2 + PhysicsTuning.ballSaveDuration + 1)
        XCTAssertFalse(effects.contains(.ballSaved))
        XCTAssertEqual(session.currentBall, 2)
    }

    // MARK: - Scoring paths

    func testDropTargetsOnlyCountOnceUntilTheBankResets() {
        _ = session.launchBall(at: 0)
        _ = session.handle(.dropTarget(index: 0), at: 1)
        let repeated = session.handle(.dropTarget(index: 0), at: 2)

        XCTAssertTrue(repeated.isEmpty)
        XCTAssertEqual(session.dropTargetsDown, [0])
    }

    func testClearingTheWholeBankResetsItAndRaisesTheMultiplier() {
        _ = session.launchBall(at: 0)
        for index in 0..<TableLayout.dropTargets.count {
            _ = session.handle(.dropTarget(index: index), at: Double(index))
        }
        XCTAssertTrue(session.dropTargetsDown.isEmpty, "the bank pops back up")
        XCTAssertEqual(session.score.playerMultiplier, 2)
        XCTAssertEqual(session.score.bankClears, 1)
    }

    func testRampsAndOrbitsChainIntoACombo() {
        _ = session.launchBall(at: 0)
        _ = session.handle(.rampCompleted(side: .left), at: 1)
        _ = session.handle(.orbitCompleted(side: .right), at: 2)

        XCTAssertEqual(session.score.comboMultiplier, 3)
    }

    func testTheComboDropsWhenTheShotsAreTooFarApart() {
        _ = session.launchBall(at: 0)
        _ = session.handle(.rampCompleted(side: .left), at: 1)
        _ = session.handle(.rampCompleted(side: .left),
                           at: 1 + PhysicsTuning.comboWindow + 1)

        XCTAssertEqual(session.score.comboMultiplier, 2, "the chain started over")
    }

    func testCompletingTheLaneSet() {
        _ = session.launchBall(at: 0)
        for index in 0..<4 {
            _ = session.handle(.rolloverLane(index: index), at: Double(index))
        }
        XCTAssertEqual(session.score.playerMultiplier, 2)
        XCTAssertTrue(session.litLanes.isEmpty)
    }

    func testAJackpotScoresNothingUntilItIsLit() {
        _ = session.launchBall(at: 0)
        let effects = session.handle(.litJackpotHit, at: 1)
        XCTAssertFalse(effects.contains { if case .jackpotCollected = $0 { return true }
                                          else { return false } })
        XCTAssertEqual(session.score.score, 0)
    }

    // MARK: - Tilt

    func testThreeNudgesInsideTheWindowTilt() {
        _ = session.launchBall(at: 0)
        XCTAssertTrue(session.handle(.nudged, at: 0.1).isEmpty)
        XCTAssertEqual(session.handle(.nudged, at: 0.5), [.tiltWarning])
        XCTAssertEqual(session.handle(.nudged, at: 0.9), [.tilted])
        XCTAssertTrue(session.isTilted)
    }

    func testNudgesSpacedOutDoNotTilt() {
        _ = session.launchBall(at: 0)
        for step in 0..<6 {
            let effects = session.handle(.nudged,
                                         at: Double(step) * (PhysicsTuning.nudgeWindow + 0.5))
            XCTAssertFalse(effects.contains(.tilted))
        }
        XCTAssertFalse(session.isTilted)
    }

    func testATiltedTableScoresNothing() {
        _ = session.launchBall(at: 0)
        for step in 0..<3 { _ = session.handle(.nudged, at: Double(step) * 0.2) }

        _ = session.handle(.popBumper(index: 0), at: 2)
        XCTAssertEqual(session.score.score, 0)
    }

    func testResolvingATiltCostsTheBallAndSkipsTheBonus() {
        _ = session.launchBall(at: 0)
        _ = session.handle(.dropTarget(index: 0), at: 0.05)
        for step in 0..<3 { _ = session.handle(.nudged, at: Double(step) * 0.2) }

        let scoreBeforeTilt = session.score.score
        let effects = session.resolveTilt(at: 3)

        XCTAssertFalse(effects.contains { if case .bonusAwarded = $0 { return true }
                                          else { return false } })
        XCTAssertEqual(session.score.score, scoreBeforeTilt)
        XCTAssertEqual(session.currentBall, 2)
    }

    // MARK: - Multiball

    func testDrainingDuringMultiballOnlyRemovesThatBall() {
        _ = session.launchBall(at: 0)
        startMultiball()
        XCTAssertTrue(session.isMultiball)

        _ = session.handle(.ballDrained, at: 30)
        XCTAssertEqual(session.currentBall, 1, "no ball is spent while others are in play")
        XCTAssertTrue(session.isMultiball)

        let effects = session.handle(.ballDrained, at: 31)
        XCTAssertEqual(effects, [.multiballEnded])
        XCTAssertFalse(session.isMultiball)
    }

    func testMultiballDoublesTheScore() {
        _ = session.launchBall(at: 0)
        startMultiball()

        let before = session.score.score
        _ = session.handle(.popBumper(index: 0), at: 30)
        let gained = session.score.score - before

        XCTAssertEqual(gained % ScoreValue.popBumper, 0)
        XCTAssertGreaterThanOrEqual(gained, ScoreValue.popBumper * 2)
    }

    // MARK: - End of game

    func testTheGameEndsAfterTheLastBall() {
        for ball in 1...3 {
            _ = session.launchBall(at: Double(ball) * 100)
            let effects = session.handle(
                .ballDrained, at: Double(ball) * 100 + PhysicsTuning.ballSaveDuration + 1)

            if ball < 3 {
                XCTAssertFalse(effects.contains { if case .gameOver = $0 { return true }
                                                  else { return false } })
            } else {
                XCTAssertTrue(effects.contains { if case .gameOver = $0 { return true }
                                                 else { return false } })
                XCTAssertEqual(session.phase, .gameOver)
            }
        }
    }

    func testAnExtraBallIsPlayedBeforeTheGameEnds() {
        _ = session.launchBall(at: 0)
        session.score.addRaw(ScoreValue.extraBallScoreThreshold)
        let awarded = session.handle(.popBumper(index: 0), at: 1)
        XCTAssertTrue(awarded.contains(.extraBallAwarded))

        // Burn all three balls; the extra one keeps the game alive.
        for ball in 1...3 {
            _ = session.launchBall(at: Double(ball) * 100)
            _ = session.handle(.ballDrained,
                               at: Double(ball) * 100 + PhysicsTuning.ballSaveDuration + 1)
        }
        XCTAssertNotEqual(session.phase, .gameOver)
    }

    func testTheEndOfBallBonusIsPaidOut() {
        _ = session.launchBall(at: 0)
        _ = session.handle(.dropTarget(index: 0), at: 1)
        _ = session.handle(.rampCompleted(side: .left), at: 2)

        let effects = session.handle(.ballDrained,
                                     at: PhysicsTuning.ballSaveDuration + 1)
        XCTAssertTrue(effects.contains { if case .bonusAwarded = $0 { return true }
                                         else { return false } })
    }

    func testNoEffectsArriveOnceTheGameIsOver() {
        for ball in 1...3 {
            _ = session.launchBall(at: Double(ball) * 100)
            _ = session.handle(.ballDrained,
                               at: Double(ball) * 100 + PhysicsTuning.ballSaveDuration + 1)
        }
        XCTAssertEqual(session.phase, .gameOver)
        XCTAssertTrue(session.handle(.ballDrained, at: 999).isEmpty)
    }

    // MARK: - Helpers

    /// Walks the mission chain up to and including Lock 3, which is what puts
    /// three balls on the table.
    private func startMultiball() {
        var time = 1.0
        while session.missions.completed.count < 5 {
            _ = session.handle(.saucerEntered(side: .left), at: time)
            guard let active = session.missions.active else { break }
            for _ in 0..<active.target {
                time += 0.1
                _ = session.handle(eventFor(active), at: time)
            }
            time += 1
        }
    }

    private func eventFor(_ mission: Mission) -> TableEvent {
        switch mission.id {
        case "warmUp":       return .popBumper(index: 0)
        case "rampRush":     return .rampCompleted(side: .left)
        case "targetFrenzy": return .dropTarget(index: Int.random(in: 0..<5))
        case "orbitLoop":    return .orbitCompleted(side: .left)
        case "lock3":        return .saucerEntered(side: .left)
        default:             return .litJackpotHit
        }
    }
}
