#if os(iOS)
import CoreHaptics
import UIKit
#endif
import Foundation

enum HapticStrength { case light, medium, heavy }

/// Core Haptics where it exists, and nothing at all where it does not, so the
/// call sites never need to know which platform they are on.
final class HapticsEngine {

    var isEnabled = true

    #if os(iOS)
    private var engine: CHHapticEngine?
    private let supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
    private lazy var light = UIImpactFeedbackGenerator(style: .light)
    private lazy var medium = UIImpactFeedbackGenerator(style: .medium)
    private lazy var heavy = UIImpactFeedbackGenerator(style: .heavy)
    #endif

    func start() {
        #if os(iOS)
        guard supportsHaptics, engine == nil else { return }
        engine = try? CHHapticEngine()
        // iOS stops the engine whenever the app loses the foreground.
        engine?.resetHandler = { [weak self] in try? self?.engine?.start() }
        engine?.stoppedHandler = { _ in }
        try? engine?.start()
        light.prepare()
        medium.prepare()
        #endif
    }

    func stop() {
        #if os(iOS)
        engine?.stop()
        engine = nil
        #endif
    }

    // MARK: - Simple taps

    func tap(_ strength: HapticStrength) {
        guard isEnabled else { return }
        #if os(iOS)
        switch strength {
        case .light:  light.impactOccurred(intensity: 0.6)
        case .medium: medium.impactOccurred(intensity: 0.8)
        case .heavy:  heavy.impactOccurred()
        }
        #endif
    }

    // MARK: - Patterns

    func play(for effect: GameEffect) {
        guard isEnabled else { return }
        switch effect {
        case .scored(_, let label):
            tap(label == .bumper || label == .slingshot ? .light : .medium)
        case .jackpotCollected:
            rumble(duration: 0.35, intensity: 0.9)
        case .superJackpotCollected, .multiballStarted, .wizardModeStarted:
            rumble(duration: 0.65, intensity: 1.0)
        case .missionCompleted, .laneSetCompleted, .dropBankReset:
            rumble(duration: 0.25, intensity: 0.7)
        case .tilted:
            rumble(duration: 0.5, intensity: 1.0)
        case .tiltWarning:
            tap(.heavy)
        case .ballLost, .missionFailed:
            rumble(duration: 0.3, intensity: 0.5)
        case .extraBallAwarded, .ballSaved:
            tap(.medium)
        default:
            break
        }
    }

    /// A continuous buzz that fades out, used for the big moments.
    private func rumble(duration: TimeInterval, intensity: Float) {
        #if os(iOS)
        guard supportsHaptics, let engine else {
            tap(.heavy)
            return
        }
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.45),
            ],
            relativeTime: 0,
            duration: duration)

        let fade = CHHapticParameterCurve(
            parameterID: .hapticIntensityControl,
            controlPoints: [
                .init(relativeTime: 0, value: 1),
                .init(relativeTime: duration, value: 0),
            ],
            relativeTime: 0)

        guard let pattern = try? CHHapticPattern(events: [event], parameterCurves: [fade]),
              let player = try? engine.makePlayer(with: pattern)
        else { return }
        try? player.start(atTime: CHHapticTimeImmediate)
        #endif
    }
}
