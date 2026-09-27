import SwiftUI

/// Every duration and curve in the app. No magic numbers in the views.
enum Motion {

    // Splash
    static let splashBallDrop: TimeInterval = 0.60
    static let splashWordmark: TimeInterval = 0.55
    static let splashCredit: TimeInterval = 0.45
    static let splashLinks: TimeInterval = 0.45
    static let splashTotal: TimeInterval = 2.60
    static let splashReducedMotion: TimeInterval = 0.40

    // Chrome
    static let screenTransition: TimeInterval = 0.32
    static let buttonPress: TimeInterval = 0.12

    // Table
    static let bumperPulse: TimeInterval = 0.12
    static let shockwave: TimeInterval = 0.35
    static let screenShake: TimeInterval = 0.15
    static let slowMotion: TimeInterval = 0.40
    static let jackpotFlash: TimeInterval = 0.10

    // Dot-matrix display
    static let dmdMessage: TimeInterval = 1.60
    static let dmdBonusStep: TimeInterval = 0.60
    static let dmdBonusTotal: TimeInterval = 1.10

    /// How many lines the display counts for a bonus: the title, then one per
    /// non-zero item, then the multiplier if there is one.
    static func bonusSteps(for report: BonusReport) -> Int {
        1 + (report.targets > 0 ? 1 : 0) + (report.loops > 0 ? 1 : 0)
            + (report.multiplier > 1 ? 1 : 0)
    }

    /// The whole count, which is also how long the next ball waits for it.
    static func bonusCountdown(for report: BonusReport) -> TimeInterval {
        Double(bonusSteps(for: report)) * dmdBonusStep + dmdBonusTotal
    }

    static var standard: Animation { .easeInOut(duration: screenTransition) }
    static var snappy: Animation { .spring(response: 0.32, dampingFraction: 0.72) }

    /// Returns `nil` when the user asked for less movement, so callers can skip
    /// the animation entirely instead of running a shorter one.
    static func respectingReduceMotion(_ animation: Animation,
                                       reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}
