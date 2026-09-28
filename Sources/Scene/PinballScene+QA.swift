#if DEBUG
import SpriteKit

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
