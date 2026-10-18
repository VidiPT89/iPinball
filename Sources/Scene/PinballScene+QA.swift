import SpriteKit

/// Switches for playing the table without a person at it, read from the
/// environment. Always off in a release build.
///
/// - `IPINBALL_AUTOSTART=1` skips the title card and the menu and goes
///   straight to a game.
/// - `IPINBALL_AUTOPLAY=1` plunges every ball and works the flippers, so a
///   game plays itself: for recording the README demo, and for leaving a
///   build running on a device to see that nothing breaks.
/// - `IPINBALL_PANEL=howToPlay` (or `settings`, `highScores`, `about`)
///   opens that panel over the menu, for App Store screenshots.
enum QAFlags {
    static var startsInGame: Bool { value("IPINBALL_AUTOSTART") != nil }
    static var autoplay: Bool { value("IPINBALL_AUTOPLAY") != nil }
    static var panel: Panel? { value("IPINBALL_PANEL").flatMap(Panel.init(rawValue:)) }

    private static func value(_ name: String) -> String? {
        #if DEBUG
        ProcessInfo.processInfo.environment[name]
        #else
        nil
        #endif
    }
}

#if DEBUG

/// Instruments for finding faults on the table. Debug builds only: none of
/// this is compiled into a release build.
///
/// - `IPINBALL_DROP="x,y"` drops every new ball at that layout point instead
///   of serving it to the plunger, so a trap can be reproduced on demand
///   rather than waited for. `"x,y,vx,vy"` fires it, in table widths per
///   second, to test a shot.
/// - `IPINBALL_QA_LOG=1` prints each place the stuck-ball watchdog had to act,
///   and at the end of every game how often each part of the table was hit —
///   which is how to tell a trap, or a shot nobody can reach, from bad luck.
extension PinballScene {

    private static var tallies: [String: Int] = [:]
    private static var isLogging: Bool {
        ProcessInfo.processInfo.environment["IPINBALL_QA_LOG"] != nil
    }

    func dropForQA(_ ball: BallNode) {
        guard let spec = ProcessInfo.processInfo.environment["IPINBALL_DROP"] else { return }
        let values = spec.split(separator: ",").compactMap { Double($0) }
        guard values.count == 2 || values.count == 4 else { return }
        let point = CGPoint(x: values[0], y: values[1])
        // Optional velocity, in table widths per second, to fire a shot.
        let velocity = values.count == 4
            ? CGVector(dx: values[2], dy: values[3]) : CGVector(dx: 0, dy: 0)
        run(.sequence([.wait(forDuration: 0.5), .run { [weak self, weak ball] in
            guard let self, let ball else { return }
            ball.park(at: self.geometry.point(point))
            ball.physicsBody?.isDynamic = true
            ball.physicsBody?.velocity = CGVector(dx: self.geometry.length(velocity.dx),
                                                  dy: self.geometry.length(velocity.dy))
            self.model?.showLaunchHint = false
            self.dispatch(.ballLaunched)
        }]))
    }

    /// Flips whichever flipper a falling ball reaches the outer half of, as
    /// one short stroke followed by a rest. Holding on while a ball was near
    /// cradled it, and letting go dropped it straight back into the next
    /// press: the ball rocked on the flipper for ever and never left it.
    func autoFlipForQA() {
        for flipper in parts.flippers {
            let side = flipper.side
            if flipper.isPressed {
                if sceneTime >= Self.flipEnds[side, default: 0] {
                    releaseFlipper(side: side)
                    Self.flipRestEnds[side] = sceneTime + 0.25
                }
                continue
            }
            guard sceneTime >= Self.flipRestEnds[side, default: 0] else { continue }
            let onTheBlade = balls.contains { ball in
                let reach = ball.position.distance(to: flipper.pivotInScene)
                return !ball.isOnRamp
                    && reach > flipper.reach * 0.45 && reach < flipper.reach * 1.1
                    && (ball.physicsBody?.velocity.dy ?? 0) < 0
            }
            if onTheBlade {
                pressFlipper(side: side)
                Self.flipEnds[side] = sceneTime + 0.18
            }
        }
    }

    private static var flipEnds: [TableSide: TimeInterval] = [:]
    private static var flipRestEnds: [TableSide: TimeInterval] = [:]

    func logWatchdogForQA(at position: CGPoint, strength: CGFloat) {
        guard Self.isLogging else { return }
        let spot = geometry.localPoint(position)
        qaPrint(String(format: "[QA] watchdog x%.0f at (%.3f, %.3f)", strength, spot.x, spot.y))
        Self.tallies["watchdog", default: 0] += 1
    }

    func tallyForQA(_ event: TableEvent) {
        guard Self.isLogging else { return }
        // "popBumper(index: 2)" and "popBumper(index: 0)" count together.
        let name = String(describing: event).prefix { $0 != "(" }
        Self.tallies[String(name), default: 0] += 1
    }

    func reportForQA() {
        guard Self.isLogging else { return }
        let lines = Self.tallies.sorted { $0.key < $1.key }.map { "  \($0.key): \($0.value)" }
        qaPrint("[QA] game over\n" + lines.joined(separator: "\n"))
        Self.tallies.removeAll()
    }

    /// Straight to standard error: `print` is buffered when the output is a
    /// file, and the log would only appear once the app quit.
    private func qaPrint(_ line: String) {
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }
}
#endif
