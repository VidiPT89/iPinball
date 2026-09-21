import Foundation

/// Which side of the table an element belongs to.
enum TableSide: String, Codable, Hashable {
    case left
    case right
}

/// Everything the physics scene can report back to the rules engine.
/// The scene never decides what something is worth; it only says what happened.
enum TableEvent: Equatable {
    case popBumper(index: Int)
    case slingshot(side: TableSide)
    case standupTarget(index: Int)
    case dropTarget(index: Int)
    case dropBankCleared
    case spinnerRotation
    case rampCompleted(side: TableSide)
    case orbitCompleted(side: TableSide)
    case rolloverLane(index: Int)
    case saucerEntered(side: TableSide)
    case litJackpotHit
    case ballDrained
    case ballLaunched
    case nudged
}

/// Anything the rules engine wants the scene, HUD, audio and haptics to react to.
enum GameEffect: Equatable {
    case scored(points: Int, label: ScoreLabel)
    case comboChanged(multiplier: Int)
    case playerMultiplierChanged(value: Int)
    case laneLit(index: Int)
    case laneSetCompleted
    case dropTargetDown(index: Int)
    case dropBankReset
    case missionStarted(id: String)
    case missionProgressed(id: String, current: Int, target: Int)
    case missionCompleted(id: String, reward: Int)
    case missionFailed(id: String)
    case multiballStarted(balls: Int)
    case multiballEnded
    case jackpotLit
    case jackpotCollected(points: Int)
    case superJackpotCollected(points: Int)
    case wizardModeStarted
    case ballSaveArmed(duration: TimeInterval)
    case ballSaved
    case ballLost(ballsRemaining: Int)
    case extraBallAwarded
    case bonusAwarded(points: Int)
    case tilted
    case tiltWarning
    case gameOver(score: Int, isHighScore: Bool)
}

/// Short identifier for the floating text the scene pops at the impact point.
enum ScoreLabel: String, Equatable {
    case bumper, slingshot, target, dropTarget, bankClear
    case spinner, ramp, orbit, lane, laneSet
    case jackpot, superJackpot, mission, bonus, combo
}

/// Lifecycle of a single game.
enum GamePhase: Equatable {
    case idle
    case ballReady
    case playing
    case ballDraining
    case tilted
    case gameOver
}

/// The four top rollover lanes spell P-I-N-B.
enum LaneLetter: Int, CaseIterable {
    case p = 0, i = 1, n = 2, b = 3

    var symbol: String {
        switch self {
        case .p: return "P"
        case .i: return "I"
        case .n: return "N"
        case .b: return "B"
        }
    }
}

/// Point values. Kept as data so the tests read like the design document.
enum ScoreValue {
    static let popBumper = 500
    static let slingshot = 250
    static let standupTarget = 1_000
    static let dropTarget = 2_500
    static let dropBankCleared = 25_000
    static let spinnerRotation = 300
    static let ramp = 10_000
    static let orbit = 15_000
    static let laneSetCompleted = 50_000
    static let jackpot = 100_000
    static let superJackpot = 500_000

    static let maxComboMultiplier = 8
    static let maxPlayerMultiplier = 5

    static let bonusPerDroppedTarget = 1_000
    static let bonusPerLoop = 2_000

    static let extraBallScoreThreshold = 1_000_000
    static let extraBallMissionCount = 3
    static let extraBallBankClears = 3
}
