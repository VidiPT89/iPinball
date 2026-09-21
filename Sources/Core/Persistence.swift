import Foundation

enum AppLanguage: String, Codable, CaseIterable {
    case pt
    case en

    var displayName: String {
        switch self {
        case .pt: return "PT"
        case .en: return "EN"
        }
    }

    static var systemDefault: AppLanguage {
        let code = Locale.preferredLanguages.first?.lowercased() ?? "en"
        return code.hasPrefix("pt") ? .pt : .en
    }
}

enum AppTheme: String, Codable, CaseIterable {
    case system
    case light
    case dark
}

struct GameSettings: Codable, Equatable {
    var language: AppLanguage = .systemDefault
    var theme: AppTheme = .system
    var soundEnabled = true
    var musicEnabled = true
    var hapticsEnabled = true
    var leftHanded = false
    var autoPlunge = false
    var ballCount = 3
}

struct HighScore: Codable, Equatable, Identifiable {
    var id = UUID()
    var initials: String
    var score: Int
    var date: Date
    var missionsCompleted: Int

    init(initials: String, score: Int, date: Date = Date(), missionsCompleted: Int) {
        self.initials = String(initials.prefix(3)).uppercased()
        self.score = score
        self.date = date
        self.missionsCompleted = missionsCompleted
    }
}

struct LifetimeStats: Codable, Equatable {
    var gamesPlayed = 0
    var ballsPlayed = 0
    var jackpots = 0
    var bestCombo = 1
    var totalScore = 0
    var playTime: TimeInterval = 0
}

struct SavedData: Codable, Equatable {
    static let currentVersion = 1

    var version = SavedData.currentVersion
    var settings = GameSettings()
    var highScores: [HighScore] = []
    var lifetime = LifetimeStats()

    static let highScoreCount = 10

    /// Returns the rank (0-based) if the score makes the table.
    func rank(for score: Int) -> Int? {
        guard score > 0 else { return nil }
        let better = highScores.filter { $0.score >= score }.count
        return better < SavedData.highScoreCount ? better : nil
    }

    mutating func insert(_ entry: HighScore) {
        highScores.append(entry)
        highScores.sort { $0.score > $1.score }
        if highScores.count > SavedData.highScoreCount {
            highScores.removeLast(highScores.count - SavedData.highScoreCount)
        }
    }
}

/// Codable round-trip on top of `UserDefaults`, with a version field so old
/// payloads can be migrated instead of thrown away.
final class GameStore {

    private let key = "dev.ividi.ipinball.save"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> SavedData {
        guard let data = defaults.data(forKey: key) else { return SavedData() }
        guard var decoded = try? JSONDecoder().decode(SavedData.self, from: data) else {
            return SavedData()
        }
        decoded = migrate(decoded)
        return decoded
    }

    func save(_ value: SavedData) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }

    private func migrate(_ value: SavedData) -> SavedData {
        var result = value
        if result.version < SavedData.currentVersion {
            result.version = SavedData.currentVersion
        }
        return result
    }
}
