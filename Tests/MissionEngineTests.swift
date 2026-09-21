import XCTest
@testable import iPinball

final class MissionEngineTests: XCTestCase {

    private var engine: MissionEngine!

    override func setUp() {
        super.setUp()
        engine = MissionEngine()
    }

    func testTheCatalogIsOrderedAndEndsWithTheWizardMission() {
        let orders = MissionEngine.catalog.map(\.order)
        XCTAssertEqual(orders, orders.sorted())
        XCTAssertEqual(MissionEngine.catalog.filter(\.isWizard).count, 1)
        XCTAssertTrue(MissionEngine.catalog.last?.isWizard == true)
    }

    func testMissionIDsAreUnique() {
        let ids = MissionEngine.catalog.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
    }

    func testFirstMissionStartsAndOnlyOneRunsAtATime() {
        let started = engine.startNextMission(at: 0)
        XCTAssertEqual(started?.id, "warmUp")
        XCTAssertNil(engine.startNextMission(at: 1),
                     "a second saucer shot must not stack another mission")
    }

    func testProgressReportsUntilTheTargetIsReached() {
        engine.startNextMission(at: 0)          // warmUp, 5 bumpers

        for hit in 1..<5 {
            let effects = engine.handle(.popBumper(index: 0), at: Double(hit))
            XCTAssertEqual(effects, [.missionProgressed(id: "warmUp",
                                                        current: hit, target: 5)])
        }

        let final = engine.handle(.popBumper(index: 0), at: 5)
        XCTAssertEqual(final, [.missionCompleted(id: "warmUp", reward: 150_000)])
        XCTAssertNil(engine.active)
        XCTAssertTrue(engine.completed.contains("warmUp"))
    }

    func testUnrelatedEventsDoNotAdvanceAMission() {
        engine.startNextMission(at: 0)          // warmUp counts bumpers only
        XCTAssertTrue(engine.handle(.rampCompleted(side: .left), at: 1).isEmpty)
        XCTAssertEqual(engine.progress, 0)
    }

    func testTimedMissionFailsWhenTheClockRunsOut() {
        engine.startNextMission(at: 0)          // warmUp has a 20 s limit
        XCTAssertNil(engine.advance(to: 19))
        XCTAssertEqual(engine.advance(to: 21), .missionFailed(id: "warmUp"))
        XCTAssertNil(engine.active)
    }

    func testRemainingTimeCountsDownAndNeverGoesNegative() {
        engine.startNextMission(at: 10)
        _ = engine.advance(to: 15)
        XCTAssertEqual(engine.remainingTime ?? 0, 15, accuracy: 0.001)
    }

    func testDrainOnlyCancelsTheMissionsThatSaySo() {
        // warmUp survives a drain.
        engine.startNextMission(at: 0)
        XCTAssertNil(engine.handleBallDrained())
        XCTAssertNotNil(engine.active)

        // targetFrenzy does not.
        completeMissions(upTo: "targetFrenzy")
        engine.startNextMission(at: 0)
        XCTAssertEqual(engine.active?.id, "targetFrenzy")
        XCTAssertEqual(engine.handleBallDrained(), .missionFailed(id: "targetFrenzy"))
        XCTAssertNil(engine.active)
    }

    func testAFailedMissionCanBeStartedAgain() {
        engine.startNextMission(at: 0)
        _ = engine.advance(to: 100)
        XCTAssertEqual(engine.startNextMission(at: 101)?.id, "warmUp")
    }

    func testWizardModeOnlyUnlocksAfterEveryOtherMission() {
        for mission in MissionEngine.catalog where !mission.isWizard {
            XCTAssertFalse(engine.isWizardUnlocked)
            complete(mission)
        }
        XCTAssertTrue(engine.isWizardUnlocked)
        XCTAssertEqual(engine.nextMission?.id, "finalShot")
    }

    func testNothingIsLeftAfterTheWizardMission() {
        for mission in MissionEngine.catalog {
            complete(mission)
        }
        XCTAssertNil(engine.nextMission)
        XCTAssertNil(engine.startNextMission(at: 0))
    }

    func testFinalShotAcceptsEveryMajorShot() {
        for mission in MissionEngine.catalog where !mission.isWizard {
            complete(mission)
        }
        engine.startNextMission(at: 0)
        XCTAssertEqual(engine.active?.id, "finalShot")

        let shots: [TableEvent] = [
            .dropTarget(index: 0), .standupTarget(index: 0),
            .rampCompleted(side: .left), .orbitCompleted(side: .right), .litJackpotHit,
        ]
        for (index, shot) in shots.enumerated() {
            _ = engine.handle(shot, at: Double(index))
        }
        XCTAssertEqual(engine.progress, shots.count)
    }

    func testResetClearsProgressAndHistory() {
        engine.startNextMission(at: 0)
        _ = engine.handle(.popBumper(index: 0), at: 1)
        engine.reset()

        XCTAssertNil(engine.active)
        XCTAssertEqual(engine.progress, 0)
        XCTAssertTrue(engine.completed.isEmpty)
    }

    // MARK: - Helpers

    private func complete(_ mission: Mission) {
        engine.startNextMission(at: 0)
        guard engine.active?.id == mission.id else {
            XCTFail("expected \(mission.id) to be next, got \(engine.active?.id ?? "nil")")
            return
        }
        for _ in 0..<mission.target {
            _ = engine.handle(event(for: mission), at: 0)
        }
        XCTAssertTrue(engine.completed.contains(mission.id))
    }

    private func completeMissions(upTo id: String) {
        for mission in MissionEngine.catalog {
            guard mission.id != id else { return }
            complete(mission)
        }
    }

    private func event(for mission: Mission) -> TableEvent {
        switch mission.id {
        case "warmUp":       return .popBumper(index: 0)
        case "rampRush":     return .rampCompleted(side: .left)
        case "targetFrenzy": return .dropTarget(index: 0)
        case "orbitLoop":    return .orbitCompleted(side: .left)
        case "lock3":        return .saucerEntered(side: .left)
        case "jackpotHunt":  return .litJackpotHit
        default:             return .litJackpotHit
        }
    }
}
