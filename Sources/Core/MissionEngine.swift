import Foundation

struct Mission: Equatable, Identifiable {
    let id: String
    let order: Int
    let target: Int
    let timeLimit: TimeInterval?
    let reward: Int
    let grantsMultiplier: Bool
    let startsMultiball: Bool
    let isWizard: Bool
    /// Draining a ball cancels the mission instead of just pausing it.
    let failsOnDrain: Bool
}

/// Drives the six chained missions and the wizard mode that follows them.
/// Only one mission runs at a time; the rest wait their turn at the saucers.
final class MissionEngine {

    static let catalog: [Mission] = [
        Mission(id: "warmUp", order: 0, target: 5, timeLimit: 20, reward: 150_000,
                grantsMultiplier: false, startsMultiball: false, isWizard: false,
                failsOnDrain: false),
        Mission(id: "rampRush", order: 1, target: 4, timeLimit: 30, reward: 200_000,
                grantsMultiplier: true, startsMultiball: false, isWizard: false,
                failsOnDrain: false),
        Mission(id: "targetFrenzy", order: 2, target: 5, timeLimit: nil, reward: 250_000,
                grantsMultiplier: false, startsMultiball: false, isWizard: false,
                failsOnDrain: true),
        Mission(id: "orbitLoop", order: 3, target: 3, timeLimit: 25, reward: 300_000,
                grantsMultiplier: false, startsMultiball: false, isWizard: false,
                failsOnDrain: false),
        Mission(id: "lock3", order: 4, target: 3, timeLimit: nil, reward: 0,
                grantsMultiplier: false, startsMultiball: true, isWizard: false,
                failsOnDrain: false),
        Mission(id: "jackpotHunt", order: 5, target: 3, timeLimit: nil, reward: 400_000,
                grantsMultiplier: false, startsMultiball: false, isWizard: false,
                failsOnDrain: false),
        Mission(id: "finalShot", order: 6, target: 12, timeLimit: 60, reward: 1_000_000,
                grantsMultiplier: false, startsMultiball: false, isWizard: true,
                failsOnDrain: false),
    ]

    private(set) var active: Mission?
    private(set) var progress = 0
    private(set) var completed: Set<String> = []

    private var startedAt: TimeInterval = 0
    private var now: TimeInterval = 0

    var isWizardUnlocked: Bool {
        MissionEngine.catalog
            .filter { !$0.isWizard }
            .allSatisfy { completed.contains($0.id) }
    }

    var nextMission: Mission? {
        if let pending = MissionEngine.catalog.first(where: {
            !$0.isWizard && !completed.contains($0.id)
        }) {
            return pending
        }
        guard let wizard = MissionEngine.catalog.first(where: { $0.isWizard }) else { return nil }
        return completed.contains(wizard.id) ? nil : wizard
    }

    var remainingTime: TimeInterval? {
        guard let active, let limit = active.timeLimit else { return nil }
        return max(0, limit - (now - startedAt))
    }

    // MARK: - Lifecycle

    /// Called when the ball settles into a saucer. Returns the mission that started.
    @discardableResult
    func startNextMission(at time: TimeInterval) -> Mission? {
        now = time
        guard active == nil, let mission = nextMission else { return nil }
        active = mission
        progress = 0
        startedAt = time
        return mission
    }

    /// Returns `.failed` when a timed mission runs out.
    func advance(to time: TimeInterval) -> GameEffect? {
        now = time
        guard let active, let limit = active.timeLimit else { return nil }
        guard time - startedAt > limit else { return nil }
        let id = active.id
        self.active = nil
        progress = 0
        return .missionFailed(id: id)
    }

    func handleBallDrained() -> GameEffect? {
        guard let active, active.failsOnDrain else { return nil }
        let id = active.id
        self.active = nil
        progress = 0
        return .missionFailed(id: id)
    }

    // MARK: - Progress

    /// Feeds a table event into the active mission. Returns the effects it produced.
    func handle(_ event: TableEvent, at time: TimeInterval) -> [GameEffect] {
        now = time
        guard let mission = active, counts(event, for: mission) else { return [] }

        progress += 1
        if progress >= mission.target {
            return [complete(mission)]
        }
        return [.missionProgressed(id: mission.id, current: progress, target: mission.target)]
    }

    private func complete(_ mission: Mission) -> GameEffect {
        completed.insert(mission.id)
        active = nil
        progress = 0
        return .missionCompleted(id: mission.id, reward: mission.reward)
    }

    private func counts(_ event: TableEvent, for mission: Mission) -> Bool {
        switch mission.id {
        case "warmUp":
            if case .popBumper = event { return true }
        case "rampRush":
            if case .rampCompleted = event { return true }
        case "targetFrenzy":
            if case .dropTarget = event { return true }
        case "orbitLoop":
            if case .orbitCompleted = event { return true }
        case "lock3":
            if case .saucerEntered = event { return true }
        case "jackpotHunt":
            if case .litJackpotHit = event { return true }
        case "finalShot":
            switch event {
            case .dropTarget, .standupTarget, .rampCompleted, .orbitCompleted, .litJackpotHit:
                return true
            default:
                return false
            }
        default:
            return false
        }
        return false
    }

    // MARK: - Reset

    func reset() {
        active = nil
        progress = 0
        completed.removeAll()
        startedAt = 0
        now = 0
    }

    static func mission(withID id: String) -> Mission? {
        catalog.first { $0.id == id }
    }
}
