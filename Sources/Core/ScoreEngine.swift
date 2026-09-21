import Foundation

/// Owns the score, the two multipliers and the P-I-N-B lane set.
///
/// Multipliers always compose in this order, which is what the tests assert:
/// `base × combo × player × 2 (while multiball is running)`.
final class ScoreEngine {

    private(set) var score = 0
    private(set) var playerMultiplier = 1
    private(set) var comboMultiplier = 1

    private(set) var litLanes: Set<Int> = []
    private(set) var laneSetsCompleted = 0
    private(set) var dropTargetsDownThisBall = 0
    private(set) var loopsThisBall = 0
    private(set) var bankClears = 0

    var isMultiballActive = false

    private var lastComboTime: TimeInterval = -.greatestFiniteMagnitude
    private var now: TimeInterval = 0

    // MARK: - Clock

    /// The engine is driven by an injected clock so the tests never sleep.
    func advance(to time: TimeInterval) {
        now = time
        if comboMultiplier > 1, now - lastComboTime > PhysicsTuning.comboWindow {
            comboMultiplier = 1
        }
    }

    var isComboActive: Bool {
        comboMultiplier > 1 && now - lastComboTime <= PhysicsTuning.comboWindow
    }

    // MARK: - Scoring

    @discardableResult
    func award(_ base: Int, label: ScoreLabel) -> Int {
        let total = base * comboMultiplier * playerMultiplier * (isMultiballActive ? 2 : 1)
        score += total
        return total
    }

    /// Ramps and orbits chain into each other inside the combo window.
    func registerComboShot() {
        if now - lastComboTime <= PhysicsTuning.comboWindow {
            comboMultiplier = min(comboMultiplier + 1, ScoreValue.maxComboMultiplier)
        } else {
            comboMultiplier = 2
        }
        lastComboTime = now
    }

    func raisePlayerMultiplier() {
        playerMultiplier = min(playerMultiplier + 1, ScoreValue.maxPlayerMultiplier)
    }

    // MARK: - Lanes

    /// Returns `true` when this rollover completed the P-I-N-B set.
    func lightLane(_ index: Int) -> Bool {
        guard (0..<LaneLetter.allCases.count).contains(index) else { return false }
        litLanes.insert(index)
        guard litLanes.count == LaneLetter.allCases.count else { return false }
        litLanes.removeAll()
        laneSetsCompleted += 1
        raisePlayerMultiplier()
        return true
    }

    // MARK: - Counters used by the end-of-ball bonus

    func registerDropTarget() { dropTargetsDownThisBall += 1 }
    func registerBankClear() { bankClears += 1; raisePlayerMultiplier() }
    func registerLoop() { loopsThisBall += 1 }

    func endOfBallBonus() -> Int {
        let raw = dropTargetsDownThisBall * ScoreValue.bonusPerDroppedTarget
            + loopsThisBall * ScoreValue.bonusPerLoop
        return raw * playerMultiplier
    }

    func resetBallCounters() {
        dropTargetsDownThisBall = 0
        loopsThisBall = 0
        comboMultiplier = 1
        litLanes.removeAll()
    }

    func addRaw(_ points: Int) {
        score += points
    }

    func reset() {
        score = 0
        playerMultiplier = 1
        comboMultiplier = 1
        litLanes.removeAll()
        laneSetsCompleted = 0
        bankClears = 0
        isMultiballActive = false
        resetBallCounters()
    }
}
