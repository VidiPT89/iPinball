import XCTest
@testable import iPinball

final class ScoreEngineTests: XCTestCase {

    private var engine: ScoreEngine!

    override func setUp() {
        super.setUp()
        engine = ScoreEngine()
        engine.advance(to: 0)
    }

    func testBaseAwardWithNoMultipliers() {
        let total = engine.award(ScoreValue.popBumper, label: .bumper)
        XCTAssertEqual(total, ScoreValue.popBumper)
        XCTAssertEqual(engine.score, ScoreValue.popBumper)
    }

    func testMultipliersComposeInOrder() {
        engine.registerComboShot()             // combo 2
        engine.raisePlayerMultiplier()         // player 2
        engine.isMultiballActive = true        // ×2

        let total = engine.award(1_000, label: .ramp)
        XCTAssertEqual(total, 1_000 * 2 * 2 * 2)
    }

    func testComboBuildsWithinTheWindowAndCapsOut() {
        for _ in 0..<20 {
            engine.registerComboShot()
        }
        XCTAssertEqual(engine.comboMultiplier, ScoreValue.maxComboMultiplier)
    }

    func testComboExpiresAfterTheWindow() {
        engine.registerComboShot()
        XCTAssertEqual(engine.comboMultiplier, 2)

        engine.advance(to: PhysicsTuning.comboWindow + 0.1)
        XCTAssertEqual(engine.comboMultiplier, 1)
        XCTAssertFalse(engine.isComboActive)
    }

    func testComboRestartsRatherThanContinuingAfterExpiry() {
        engine.registerComboShot()
        engine.registerComboShot()
        XCTAssertEqual(engine.comboMultiplier, 3)

        engine.advance(to: PhysicsTuning.comboWindow + 1)
        engine.registerComboShot()
        XCTAssertEqual(engine.comboMultiplier, 2)
    }

    func testPlayerMultiplierCapsOut() {
        for _ in 0..<20 {
            engine.raisePlayerMultiplier()
        }
        XCTAssertEqual(engine.playerMultiplier, ScoreValue.maxPlayerMultiplier)
    }

    func testCompletingTheLaneSetRaisesThePlayerMultiplier() {
        XCTAssertFalse(engine.lightLane(0))
        XCTAssertFalse(engine.lightLane(1))
        XCTAssertFalse(engine.lightLane(2))
        XCTAssertTrue(engine.lightLane(3))

        XCTAssertEqual(engine.playerMultiplier, 2)
        XCTAssertEqual(engine.laneSetsCompleted, 1)
        XCTAssertTrue(engine.litLanes.isEmpty, "the set resets so it can be lit again")
    }

    func testRelightingTheSameLaneDoesNotCompleteTheSet() {
        for _ in 0..<6 {
            XCTAssertFalse(engine.lightLane(0))
        }
        XCTAssertEqual(engine.playerMultiplier, 1)
    }

    func testOutOfRangeLaneIsIgnored() {
        XCTAssertFalse(engine.lightLane(99))
        XCTAssertTrue(engine.litLanes.isEmpty)
    }

    func testEndOfBallBonusScalesWithThePlayerMultiplier() {
        engine.registerDropTarget()
        engine.registerDropTarget()
        engine.registerLoop()
        engine.raisePlayerMultiplier()          // ×2

        let expected = (2 * ScoreValue.bonusPerDroppedTarget
                        + 1 * ScoreValue.bonusPerLoop) * 2
        XCTAssertEqual(engine.endOfBallBonus(), expected)
    }

    func testResettingBallCountersKeepsTheScoreAndPlayerMultiplier() {
        engine.award(5_000, label: .ramp)
        engine.raisePlayerMultiplier()
        engine.registerDropTarget()
        engine.registerComboShot()

        engine.resetBallCounters()

        XCTAssertEqual(engine.score, 5_000)
        XCTAssertEqual(engine.playerMultiplier, 2)
        XCTAssertEqual(engine.comboMultiplier, 1)
        XCTAssertEqual(engine.endOfBallBonus(), 0)
    }

    func testBankClearRaisesThePlayerMultiplier() {
        engine.registerBankClear()
        XCTAssertEqual(engine.playerMultiplier, 2)
        XCTAssertEqual(engine.bankClears, 1)
    }

    func testFullResetClearsEverything() {
        engine.award(9_999, label: .jackpot)
        engine.raisePlayerMultiplier()
        engine.registerBankClear()
        engine.isMultiballActive = true

        engine.reset()

        XCTAssertEqual(engine.score, 0)
        XCTAssertEqual(engine.playerMultiplier, 1)
        XCTAssertEqual(engine.comboMultiplier, 1)
        XCTAssertEqual(engine.bankClears, 0)
        XCTAssertFalse(engine.isMultiballActive)
    }
}
