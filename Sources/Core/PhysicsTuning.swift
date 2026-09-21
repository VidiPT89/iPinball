import CoreGraphics
import Foundation

/// Every tunable physical constant of the table lives here so balancing never
/// requires hunting through the scene code.
enum PhysicsTuning {

    // MARK: World

    /// The table is tilted, not vertical, so gravity is far weaker than 9.8.
    static let gravity = CGVector(dx: 0, dy: -6.2)

    // MARK: Ball

    /// Radius as a fraction of the playfield width.
    static let ballRadiusRatio: CGFloat = 0.022
    static let ballMass: CGFloat = 0.08
    static let ballRestitution: CGFloat = 0.32
    static let ballLinearDamping: CGFloat = 0.18
    static let ballAngularDamping: CGFloat = 0.4
    static let ballFriction: CGFloat = 0.10

    /// Speed clamp applied every frame, in table widths per second, so the feel
    /// is identical on every screen size. Without it the solver becomes
    /// unstable and the ball escapes through thin walls.
    static let maxBallSpeed: CGFloat = 3.4

    // MARK: Flippers

    static let flipperRestAngle: CGFloat = -0.38      // radians, ~ -22°
    static let flipperActiveAngle: CGFloat = 0.35     // radians, ~ +20°
    static let flipperAngularSpeed: CGFloat = 34      // radians per second
    static let flipperRestitution: CGFloat = 0.12
    static let flipperFriction: CGFloat = 0.6

    // MARK: Kick speeds, in table widths per second

    static let bumperKickSpeed: CGFloat = 1.95
    static let slingshotKickSpeed: CGFloat = 1.70
    static let saucerEjectSpeed: CGFloat = 1.85
    static let nudgeSpeed: CGFloat = 0.34
    static let magnetPull: CGFloat = 1.10

    // MARK: Plunger

    static let plungerMinSpeed: CGFloat = 1.45
    static let plungerMaxSpeed: CGFloat = 3.10
    /// Drag distance, as a fraction of the screen height, for a full charge.
    static let plungerFullPullRatio: CGFloat = 0.22

    // MARK: Safety nets

    /// A ball that moves less than this (in radii) for `stuckTimeout` seconds
    /// is nudged free by the watchdog.
    static let stuckDistanceRadii: CGFloat = 0.25
    static let stuckTimeout: TimeInterval = 3.0
    static let stuckKickSpeed: CGFloat = 0.55

    // MARK: Timings

    static let ballSaveDuration: TimeInterval = 8.0
    static let multiballSaveDuration: TimeInterval = 10.0
    static let saucerHoldDuration: TimeInterval = 1.0
    static let magnetHoldDuration: TimeInterval = 0.8
    static let comboWindow: TimeInterval = 4.0
    static let nudgeWindow: TimeInterval = 2.0
    static let nudgesBeforeTilt = 3
    static let rampTravelDuration: TimeInterval = 0.75
    static let rampExitSpeed: CGFloat = 1.55
}
