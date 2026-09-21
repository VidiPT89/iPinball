import XCTest
@testable import iPinball

/// Everything the game-over screen stands on: reaching the end of a game,
/// working out whether it made the table, writing it down, and the text the
/// share button hands over.
final class GameOverFlowTests: XCTestCase {

    private var settings: AppSettings!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "iPinballTests.\(UUID().uuidString)"
        settings = AppSettings(store: GameStore(defaults: UserDefaults(suiteName: suiteName)!))
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    // MARK: - Reaching the end

    func testAThreeBallGameEndsAndReportsTheScoreItFinishedOn() {
        let session = GameSession()
        _ = session.startGame(ballCount: 3, at: 0)

        var finalScore: Int?
        for ball in 1...3 {
            let base = Double(ball) * 100
            _ = session.launchBall(at: base)
            _ = session.handle(.popBumper(index: 0), at: base + 1)

            let effects = session.handle(.ballDrained,
                                         at: base + PhysicsTuning.ballSaveDuration + 1)
            for effect in effects {
                if case .gameOver(let score) = effect { finalScore = score }
            }
        }

        XCTAssertEqual(session.phase, .gameOver)
        XCTAssertEqual(finalScore, session.score.score)
        XCTAssertEqual(finalScore, ScoreValue.popBumper * 3)
    }

    func testAFiveBallGameTakesFiveBalls() {
        let session = GameSession()
        _ = session.startGame(ballCount: 5, at: 0)

        for ball in 1...4 {
            let base = Double(ball) * 100
            _ = session.launchBall(at: base)
            _ = session.handle(.ballDrained, at: base + PhysicsTuning.ballSaveDuration + 1)
            XCTAssertNotEqual(session.phase, .gameOver, "ended early on ball \(ball)")
        }
        _ = session.launchBall(at: 500)
        _ = session.handle(.ballDrained, at: 500 + PhysicsTuning.ballSaveDuration + 1)
        XCTAssertEqual(session.phase, .gameOver)
    }

    // MARK: - Does it make the table

    func testTheFirstScoreOfAnyGameTakesFirstPlace() {
        XCTAssertEqual(settings.rank(for: 1_000), 0)
    }

    func testAScorelessGameNeverMakesTheTable() {
        XCTAssertNil(settings.rank(for: 0))
    }

    func testRankReflectsWhatIsAlreadyThere() {
        for score in [500_000, 300_000, 100_000] {
            settings.recordGame(score: score, initials: "DAM", missionsCompleted: 1,
                                ballsPlayed: 3, jackpots: 0, bestCombo: 1, duration: 60)
        }
        XCTAssertEqual(settings.rank(for: 400_000), 1, "second best")
        XCTAssertEqual(settings.rank(for: 600_000), 0, "a new best")
        XCTAssertEqual(settings.rank(for: 50_000), 3, "last, but still on the table")
    }

    // MARK: - Writing it down

    func testSavingWithInitialsAddsAnEntryAndCountsTheGame() {
        settings.recordGame(score: 250_000, initials: "DAM", missionsCompleted: 2,
                            ballsPlayed: 3, jackpots: 4, bestCombo: 6, duration: 180)

        XCTAssertEqual(settings.saved.highScores.count, 1)
        XCTAssertEqual(settings.saved.highScores.first?.initials, "DAM")
        XCTAssertEqual(settings.bestScore, 250_000)

        let lifetime = settings.saved.lifetime
        XCTAssertEqual(lifetime.gamesPlayed, 1)
        XCTAssertEqual(lifetime.ballsPlayed, 3)
        XCTAssertEqual(lifetime.jackpots, 4)
        XCTAssertEqual(lifetime.bestCombo, 6)
        XCTAssertEqual(lifetime.totalScore, 250_000)
    }

    func testLeavingTheInitialsBlankStillCountsTheGameButAddsNoEntry() {
        settings.recordGame(score: 90_000, initials: nil, missionsCompleted: 0,
                            ballsPlayed: 3, jackpots: 0, bestCombo: 2, duration: 90)

        XCTAssertTrue(settings.saved.highScores.isEmpty)
        XCTAssertEqual(settings.saved.lifetime.gamesPlayed, 1)
        XCTAssertEqual(settings.saved.lifetime.totalScore, 90_000)
    }

    func testTheGameIsOnlyEverWrittenDownOnce() {
        // The screen saves on Play Again, on Menu and on disappear, all guarded
        // by one flag; this proves a second call would be visible if it leaked.
        settings.recordGame(score: 10_000, initials: "AAA", missionsCompleted: 0,
                            ballsPlayed: 1, jackpots: 0, bestCombo: 1, duration: 10)
        settings.recordGame(score: 10_000, initials: "AAA", missionsCompleted: 0,
                            ballsPlayed: 1, jackpots: 0, bestCombo: 1, duration: 10)
        XCTAssertEqual(settings.saved.lifetime.gamesPlayed, 2,
                       "the store itself does not deduplicate — the view must")
    }

    func testRecordsSurviveARelaunch() {
        settings.recordGame(score: 123_456, initials: "VID", missionsCompleted: 3,
                            ballsPlayed: 3, jackpots: 1, bestCombo: 4, duration: 200)
        settings.language = .pt
        settings.theme = .dark
        settings.ballCount = 5

        let reopened = AppSettings(
            store: GameStore(defaults: UserDefaults(suiteName: suiteName)!))

        XCTAssertEqual(reopened.bestScore, 123_456)
        XCTAssertEqual(reopened.saved.highScores.first?.initials, "VID")
        XCTAssertEqual(reopened.language, .pt)
        XCTAssertEqual(reopened.theme, .dark)
        XCTAssertEqual(reopened.ballCount, 5)
    }

    func testClearingRecordsLeavesTheSettingsAlone() {
        settings.recordGame(score: 5_000, initials: "DAM", missionsCompleted: 0,
                            ballsPlayed: 1, jackpots: 0, bestCombo: 1, duration: 10)
        settings.language = .pt
        settings.clearRecords()

        XCTAssertTrue(settings.saved.highScores.isEmpty)
        XCTAssertEqual(settings.saved.lifetime, LifetimeStats())
        XCTAssertEqual(settings.language, .pt, "preferences are not records")
    }

    // MARK: - What the share button hands over

    func testTheShareTextCarriesTheScoreInBothLanguages() {
        settings.language = .pt
        let pt = settings.t("gameover.shareText", 1_234.grouped)
        XCTAssertTrue(pt.contains(1_234.grouped), pt)
        XCTAssertFalse(pt.contains("%"), "the placeholder was left unfilled: \(pt)")

        settings.language = .en
        let en = settings.t("gameover.shareText", 1_234.grouped)
        XCTAssertTrue(en.contains(1_234.grouped), en)
        XCTAssertFalse(en.contains("%"), "the placeholder was left unfilled: \(en)")
        XCTAssertNotEqual(pt, en)
    }

    func testAnUnknownKeyComesBackAsItselfRatherThanEmpty() {
        XCTAssertEqual(settings.t("nope.not.a.key"), "nope.not.a.key")
    }

    func testSwitchingLanguageChangesWhatTheScreensRead() {
        settings.language = .pt
        let pt = settings.t("gameover.title")
        settings.toggleLanguage()
        XCTAssertEqual(settings.language, .en)
        XCTAssertNotEqual(settings.t("gameover.title"), pt)
    }
}
