import XCTest
@testable import iPinball

/// The rules that make the table play like a 90s machine: the skill shot, the
/// lane change on the flipper buttons, SHOOT AGAIN and the bonus count.
final class ArcadeRulesTests: XCTestCase {

    private var session: GameSession!

    override func setUp() {
        super.setUp()
        session = GameSession()
        _ = session.startGame(ballCount: 3, at: 0)
    }

    private func skillShotPoints(in effects: [GameEffect]) -> Int? {
        for effect in effects {
            if case .skillShotCollected(let points) = effect { return points }
        }
        return nil
    }

    // MARK: - Skill shot

    func testTheSkillShotWalksAcrossTheLanesWhileTheBallWaits() {
        var seen: Set<Int> = []
        for step in 0..<8 {
            _ = session.advance(to: Double(step) * PhysicsTuning.skillShotStep + 0.01)
            if let lane = session.skillShotLane { seen.insert(lane) }
        }
        XCTAssertEqual(seen, Set(0..<LaneLetter.allCases.count))
    }

    func testTheSkillShotFreezesOnLaunch() {
        let launchTime = PhysicsTuning.skillShotStep * 2 + 0.01
        _ = session.launchBall(at: launchTime)
        let lane = session.skillShotLane
        XCTAssertEqual(lane, GameSession.skillShotLane(at: launchTime))

        _ = session.advance(to: launchTime + PhysicsTuning.skillShotStep * 3)
        XCTAssertEqual(session.skillShotLane, lane, "it stops walking once the ball is away")
    }

    func testRollingThroughTheLitLanePaysTheSkillShot() throws {
        _ = session.launchBall(at: 0)
        let lane = try XCTUnwrap(session.skillShotLane)

        let effects = session.handle(.rolloverLane(index: lane), at: 1)

        XCTAssertEqual(skillShotPoints(in: effects), ScoreValue.skillShot)
        XCTAssertNil(session.skillShotLane)
        XCTAssertGreaterThanOrEqual(session.score.score, ScoreValue.skillShot)
    }

    func testTheWrongLaneSpendsTheSkillShot() throws {
        _ = session.launchBall(at: 0)
        let lane = try XCTUnwrap(session.skillShotLane)
        let wrong = (lane + 1) % LaneLetter.allCases.count

        XCTAssertNil(skillShotPoints(in: session.handle(.rolloverLane(index: wrong), at: 1)))
        XCTAssertNil(session.skillShotLane)
        XCTAssertNil(skillShotPoints(in: session.handle(.rolloverLane(index: lane), at: 1.2)),
                     "one attempt per plunge")
    }

    func testTheSkillShotRunsOut() throws {
        _ = session.launchBall(at: 0)
        let lane = try XCTUnwrap(session.skillShotLane)
        _ = session.advance(to: PhysicsTuning.skillShotWindow + 0.1)

        XCTAssertNil(session.skillShotLane)
        XCTAssertNil(skillShotPoints(in: session.handle(.rolloverLane(index: lane),
                                                        at: PhysicsTuning.skillShotWindow + 0.2)))
    }

    func testASavedBallGetsANewSkillShot() {
        _ = session.launchBall(at: 0)
        _ = session.handle(.rolloverLane(index: 0), at: 0.5)
        _ = session.handle(.ballDrained, at: 1)
        XCTAssertEqual(session.phase, .ballReady)

        _ = session.advance(to: 1.5)
        XCTAssertNotNil(session.skillShotLane)
    }

    func testATiltedTableOffersNoSkillShot() {
        _ = session.launchBall(at: 0)
        for step in 0..<3 { _ = session.handle(.nudged, at: 0.1 + Double(step) * 0.1) }
        _ = session.advance(to: 0.5)
        XCTAssertNil(session.skillShotLane)
    }

    // MARK: - Lane change

    func testTheFlippersMoveTheLitLanes() {
        _ = session.launchBall(at: 0)
        _ = session.advance(to: PhysicsTuning.skillShotWindow + 1)
        _ = session.handle(.rolloverLane(index: 0), at: PhysicsTuning.skillShotWindow + 1)

        XCTAssertEqual(session.rotateLanes(towards: .right), [.lanesRotated(lit: [1])])
        XCTAssertEqual(session.litLanes, [1])
        XCTAssertEqual(session.score.litLanes, [1], "both copies of the lamps agree")

        XCTAssertEqual(session.rotateLanes(towards: .left), [.lanesRotated(lit: [0])])
        XCTAssertEqual(session.rotateLanes(towards: .left), [.lanesRotated(lit: [3])],
                       "it wraps round the end")
    }

    func testAMovedLampCanStillCompleteTheSet() {
        _ = session.launchBall(at: 0)
        _ = session.advance(to: PhysicsTuning.skillShotWindow + 1)
        let time = PhysicsTuning.skillShotWindow + 1
        for lane in 0..<3 { _ = session.handle(.rolloverLane(index: lane), at: time) }
        _ = session.rotateLanes(towards: .right)   // lit: 1, 2, 3

        let effects = session.handle(.rolloverLane(index: 0), at: time + 1)
        XCTAssertTrue(effects.contains(.laneSetCompleted))
        XCTAssertEqual(session.score.playerMultiplier, 2)
    }

    func testNothingMovesWithNoLampsLitOrBeforeTheLaunch() {
        XCTAssertEqual(session.rotateLanes(towards: .left), [], "ball still in the shooter lane")
        _ = session.launchBall(at: 0)
        XCTAssertEqual(session.rotateLanes(towards: .left), [])
    }

    // MARK: - Ball save

    func testTheBallSaveIsGivenOncePerBall() {
        _ = session.launchBall(at: 0)
        XCTAssertEqual(session.handle(.ballDrained, at: 2), [.ballSaved])

        XCTAssertEqual(session.launchBall(at: 3), [], "no second save on the re-plunge")
        XCTAssertFalse(session.isBallSaveActive)
        let effects = session.handle(.ballDrained, at: 4)
        XCTAssertFalse(effects.contains(.ballSaved))
        XCTAssertEqual(session.currentBall, 2)

        XCTAssertEqual(session.launchBall(at: 10),
                       [.ballSaveArmed(duration: PhysicsTuning.ballSaveDuration)],
                       "the next ball gets its own save")
    }

    // MARK: - Shoot again and the bonus

    func testPlayingAnExtraBallLightsShootAgain() {
        _ = session.launchBall(at: 0)
        session.score.addRaw(ScoreValue.extraBallScoreThreshold)
        _ = session.handle(.popBumper(index: 0), at: 1)

        let effects = session.handle(.ballDrained, at: PhysicsTuning.ballSaveDuration + 1)
        XCTAssertTrue(effects.contains(.shootAgain))
        XCTAssertEqual(session.currentBall, 1, "the same ball number is played again")
    }

    func testTheBonusIsReportedLineByLine() throws {
        _ = session.launchBall(at: 0)
        _ = session.handle(.dropTarget(index: 0), at: 1)
        _ = session.handle(.dropTarget(index: 1), at: 1.1)
        _ = session.handle(.rampCompleted(side: .left), at: 2)

        let effects = session.handle(.ballDrained, at: PhysicsTuning.ballSaveDuration + 1)
        let report = try XCTUnwrap(effects.compactMap { effect -> BonusReport? in
            if case .bonusAwarded(let report) = effect { return report }
            return nil
        }.first)

        XCTAssertEqual(report.targets, 2)
        XCTAssertEqual(report.loops, 1)
        XCTAssertEqual(report.multiplier, 1)
        XCTAssertEqual(report.total, 2 * ScoreValue.bonusPerDroppedTarget + ScoreValue.bonusPerLoop)
    }

    func testTheBonusCountLastsLongerForABiggerBonus() {
        let small = BonusReport(targets: 1, loops: 0, multiplier: 1)
        let big = BonusReport(targets: 4, loops: 3, multiplier: 3)
        XCTAssertGreaterThan(Motion.bonusCountdown(for: big), Motion.bonusCountdown(for: small))
        XCTAssertLessThan(Motion.bonusCountdown(for: big), 5, "the next ball must not drag")
    }

    // MARK: - Saucers

    func testTheSaucersFlashWhileAMissionIsWaitingToStart() {
        XCTAssertFalse(session.isSaucerLit, "nothing flashes before the launch")
        _ = session.launchBall(at: 0)
        XCTAssertTrue(session.isSaucerLit)

        _ = session.handle(.saucerEntered(side: .left), at: 1)
        XCTAssertNotNil(session.missions.active)
        XCTAssertFalse(session.isSaucerLit, "a running mission is played elsewhere")
    }

    func testTheSaucersFlashDuringLockThree() {
        _ = session.launchBall(at: 0)
        var time: TimeInterval = 1
        // Play the chain up to Lock 3, which is scored at the saucers.
        for _ in 0..<MissionEngine.catalog.count {
            guard let next = session.missions.nextMission, next.id != "lock3" else { break }
            _ = session.handle(.saucerEntered(side: .left), at: time)
            for hit in 0..<next.target {
                time += 0.1
                _ = session.handle(event(for: next.id, hit: hit), at: time)
            }
            time += 1
        }
        _ = session.handle(.saucerEntered(side: .left), at: time)

        XCTAssertEqual(session.missions.active?.id, "lock3")
        XCTAssertTrue(session.isSaucerLit)
    }

    /// A distinct hit each time: a drop target that is already down scores
    /// nothing, so repeating one would never finish Target Frenzy.
    private func event(for mission: String, hit: Int) -> TableEvent {
        switch mission {
        case "warmUp":       return .popBumper(index: 0)
        case "rampRush":     return .rampCompleted(side: .left)
        case "targetFrenzy": return .dropTarget(index: hit % TableLayout.dropTargets.count)
        default:             return .orbitCompleted(side: .left)
        }
    }
}
