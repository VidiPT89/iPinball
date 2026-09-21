import Observation
import SwiftUI

/// What the HUD shows. The scene pushes into it, SwiftUI reads from it, and
/// nothing flows the other way except explicit commands.
@Observable
final class GameModel {

    struct Banner: Equatable {
        let key: String
        let style: Style
        let id: UUID

        enum Style { case neutral, good, great, bad }

        init(key: String, style: Style) {
            self.key = key
            self.style = style
            self.id = UUID()
        }
    }

    var score = 0
    var ball = 1
    var ballCount = 3
    var playerMultiplier = 1
    var comboMultiplier = 1
    var litLanes: Set<Int> = []

    var missionID: String?
    var missionCurrent = 0
    var missionTarget = 0
    var missionRemaining: TimeInterval?

    var ballSaveRemaining: TimeInterval?
    var isMultiball = false
    var isTilted = false
    var showLaunchHint = true

    var isPaused = false
    var isGameOver = false
    var finalScore = 0
    var highScoreRank: Int?

    var banner: Banner?

    // Stats gathered for the lifetime record.
    var jackpotCount = 0
    var bestCombo = 1
    var ballsPlayed = 0
    var missionsCompleted = 0
    var startedAt = Date()

    func resetForNewGame(ballCount: Int) {
        score = 0
        ball = 1
        self.ballCount = ballCount
        playerMultiplier = 1
        comboMultiplier = 1
        litLanes = []
        missionID = nil
        missionCurrent = 0
        missionTarget = 0
        missionRemaining = nil
        ballSaveRemaining = nil
        isMultiball = false
        isTilted = false
        showLaunchHint = true
        isPaused = false
        isGameOver = false
        finalScore = 0
        highScoreRank = nil
        banner = nil
        jackpotCount = 0
        bestCombo = 1
        ballsPlayed = 0
        missionsCompleted = 0
        startedAt = Date()
    }

    func show(_ key: String, style: Banner.Style) {
        banner = Banner(key: key, style: style)
    }

    /// Folds one rules-engine effect into the HUD state.
    func apply(_ effect: GameEffect, session: GameSession) {
        switch effect {
        case .scored:
            score = session.score.score

        case .comboChanged(let multiplier):
            comboMultiplier = multiplier
            bestCombo = max(bestCombo, multiplier)

        case .playerMultiplierChanged(let value):
            playerMultiplier = value

        case .laneLit(let index):
            litLanes.insert(index)

        case .laneSetCompleted:
            litLanes.removeAll()

        case .missionStarted(let id):
            missionID = id
            missionCurrent = 0
            missionTarget = MissionEngine.mission(withID: id)?.target ?? 0

        case .missionProgressed(_, let current, let target):
            missionCurrent = current
            missionTarget = target

        case .missionCompleted:
            missionID = nil
            missionRemaining = nil
            missionsCompleted += 1
            score = session.score.score
            show("hud.missionComplete", style: .great)

        case .missionFailed:
            missionID = nil
            missionRemaining = nil
            show("hud.missionFailed", style: .bad)

        case .multiballStarted:
            isMultiball = true
            show("hud.multiball", style: .great)

        case .multiballEnded:
            isMultiball = false

        case .jackpotCollected:
            jackpotCount += 1
            score = session.score.score
            show("hud.jackpot", style: .great)

        case .superJackpotCollected:
            jackpotCount += 1
            score = session.score.score
            show("hud.superJackpot", style: .great)

        case .wizardModeStarted:
            show("hud.wizard", style: .great)

        case .ballSaved:
            show("hud.ballSaved", style: .good)

        case .extraBallAwarded:
            show("hud.extraBall", style: .good)

        case .bonusAwarded:
            score = session.score.score
            show("hud.bonus", style: .good)

        case .tilted:
            isTilted = true
            show("hud.tilt", style: .bad)

        case .tiltWarning:
            show("hud.tiltWarning", style: .bad)

        case .ballLost:
            ballsPlayed += 1
            ball = session.currentBall
            isTilted = false
            litLanes.removeAll()
            comboMultiplier = 1
            if session.currentBall == session.ballCount {
                show("hud.lastBall", style: .neutral)
            }

        case .gameOver(let finalScore, _):
            ballsPlayed += 1
            self.finalScore = finalScore
            score = finalScore
            isGameOver = true

        case .ballSaveArmed, .jackpotLit, .dropTargetDown, .dropBankReset:
            break
        }
    }
}
