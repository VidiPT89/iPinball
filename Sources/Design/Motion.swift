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
    static let sheetTransition: TimeInterval = 0.28
    static let buttonPress: TimeInterval = 0.12
    static let themeCrossfade: TimeInterval = 0.25

    // Scoreboard
    static let scoreRoll: TimeInterval = 0.40
    static let scorePop: TimeInterval = 0.22

    // Table
    static let bumperPulse: TimeInterval = 0.12
    static let shockwave: TimeInterval = 0.35
    static let screenShake: TimeInterval = 0.15
    static let slowMotion: TimeInterval = 0.40
    static let lightFade: TimeInterval = 0.18
    static let floatingScore: TimeInterval = 0.85
    static let jackpotFlash: TimeInterval = 0.10
    static let bannerSweep: TimeInterval = 1.10

    static var standard: Animation { .easeInOut(duration: screenTransition) }
    static var snappy: Animation { .spring(response: 0.32, dampingFraction: 0.72) }
    static var gentle: Animation { .easeOut(duration: 0.45) }

    /// Returns `nil` when the user asked for less movement, so callers can skip
    /// the animation entirely instead of running a shorter one.
    static func respectingReduceMotion(_ animation: Animation,
                                       reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }
}
