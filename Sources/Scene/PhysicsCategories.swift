import Foundation

enum PhysicsCategory {
    static let none: UInt32 = 0
    static let ball: UInt32 = 1 << 0
    static let wall: UInt32 = 1 << 1
    static let flipper: UInt32 = 1 << 2
    static let bumper: UInt32 = 1 << 3
    static let target: UInt32 = 1 << 4
    static let rampEntrance: UInt32 = 1 << 5
    static let rollover: UInt32 = 1 << 6
    static let drain: UInt32 = 1 << 7
    static let saucer: UInt32 = 1 << 8
    static let spinner: UInt32 = 1 << 9
    static let slingshot: UInt32 = 1 << 10
    static let orbitGate: UInt32 = 1 << 11

    /// Everything solid the ball is allowed to bounce off.
    static let solid: UInt32 = wall | flipper | bumper | target | slingshot

    /// Everything that only reports a contact.
    static let sensors: UInt32 =
        rampEntrance | rollover | drain | saucer | spinner | orbitGate
}

enum NodeName {
    static let ball = "ball"
    static let flipperLeft = "flipper.left"
    static let flipperRight = "flipper.right"
    static let flipperUpper = "flipper.upper"
}
