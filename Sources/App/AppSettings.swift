import Observation
import SwiftUI

/// Single source of truth for preferences, saved data and translation.
/// Injected once at the root and read by every screen.
@Observable
final class AppSettings {

    private let store: GameStore
    private(set) var saved: SavedData

    init(store: GameStore = GameStore()) {
        self.store = store
        self.saved = store.load()
    }

    // MARK: - Preferences

    var language: AppLanguage {
        get { saved.settings.language }
        set { saved.settings.language = newValue; persist() }
    }

    var theme: AppTheme {
        get { saved.settings.theme }
        set { saved.settings.theme = newValue; persist() }
    }

    var soundEnabled: Bool {
        get { saved.settings.soundEnabled }
        set { saved.settings.soundEnabled = newValue; persist() }
    }

    var musicEnabled: Bool {
        get { saved.settings.musicEnabled }
        set { saved.settings.musicEnabled = newValue; persist() }
    }

    var hapticsEnabled: Bool {
        get { saved.settings.hapticsEnabled }
        set { saved.settings.hapticsEnabled = newValue; persist() }
    }

    var controls: ControlLayout {
        get { saved.settings.controls }
        set { saved.settings.controls = newValue; persist() }
    }

    var leftHanded: Bool {
        get { saved.settings.leftHanded }
        set { saved.settings.leftHanded = newValue; persist() }
    }

    var autoPlunge: Bool {
        get { saved.settings.autoPlunge }
        set { saved.settings.autoPlunge = newValue; persist() }
    }

    var ballCount: Int {
        get { saved.settings.ballCount }
        set { saved.settings.ballCount = max(1, newValue); persist() }
    }

    var colorScheme: ColorScheme? {
        switch theme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var bestScore: Int { saved.highScores.first?.score ?? 0 }

    // MARK: - Translation

    /// Looks a key up in the active language. Unknown keys return the key
    /// itself, which makes a missing string obvious during development.
    func t(_ key: String) -> String {
        guard let pair = Strings.all[key] else { return key }
        return language == .pt ? pair.pt : pair.en
    }

    func t(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: t(key), arguments: arguments)
    }

    func toggleLanguage() {
        language = language == .pt ? .en : .pt
    }

    // MARK: - Records

    func rank(for score: Int) -> Int? { saved.rank(for: score) }

    func recordGame(score: Int, initials: String?, missionsCompleted: Int,
                    ballsPlayed: Int, jackpots: Int, bestCombo: Int,
                    duration: TimeInterval) {
        if let initials, !initials.isEmpty, score > 0 {
            saved.insert(HighScore(initials: initials, score: score,
                                   missionsCompleted: missionsCompleted))
        }
        saved.lifetime.gamesPlayed += 1
        saved.lifetime.ballsPlayed += ballsPlayed
        saved.lifetime.jackpots += jackpots
        saved.lifetime.bestCombo = max(saved.lifetime.bestCombo, bestCombo)
        saved.lifetime.totalScore += score
        saved.lifetime.playTime += duration
        persist()
    }

    func clearRecords() {
        saved.highScores.removeAll()
        saved.lifetime = LifetimeStats()
        persist()
    }

    private func persist() {
        store.save(saved)
    }
}
