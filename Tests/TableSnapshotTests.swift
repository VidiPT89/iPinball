import ImageIO
import SpriteKit
import XCTest
@testable import iPinball

/// Renders the built table off screen. It proves the scene assembles and draws
/// without a display, and — with `IPINBALL_SNAPSHOT_DIR` set — writes a PNG,
/// which is the only way to look at the table when the Mac is locked.
final class TableSnapshotTests: XCTestCase {

    @MainActor
    func testTheTableRendersOffScreen() throws {
        let size = CGSize(width: 560, height: 940)
        let scene = PinballScene()
        scene.size = size
        scene.scaleMode = .resizeFill

        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.presentScene(scene)

        // One ball on the playfield and one up on a ramp, so the picture
        // shows the steel, the shadows and how far a raised ball's falls.
        let rolling = scene.spawnBall(at: CGPoint(x: 0.5, y: 0.62))
        let raised = scene.spawnBall(at: CGPoint(x: 0.30, y: 1.02))
        raised.isOnRamp = true
        [rolling, raised].forEach { $0.updateLighting() }
        XCTAssertEqual(rolling.shadow.parent, scene, "a ball has to lay its shadow on the table")

        guard let texture = view.texture(from: scene),
              let image = texture.cgImage() as CGImage? else {
            throw XCTSkip("no renderer available in this environment")
        }

        XCTAssertGreaterThan(image.width, 0)
        XCTAssertGreaterThan(image.height, 0)
        XCTAssertFalse(scene.children.isEmpty, "the table built no nodes")

        guard let directory = ProcessInfo.processInfo
            .environment["IPINBALL_SNAPSHOT_DIR"] else { return }

        let url = URL(fileURLWithPath: directory)
            .appendingPathComponent("table.png")
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, "public.png" as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
    }
}

/// Scene regressions use an explicit clock and never depend on wall-clock sleeps.
@MainActor
final class SceneLifecycleTests: XCTestCase {
    private func table() -> PinballScene {
        let scene = PinballScene(size: CGSize(width: 560, height: 940))
        scene.model = nil
        scene.didMove(to: SKView())
        scene.startGame()
        return scene
    }

    func testPauseDoesNotConsumeBallSaveOrAcceptInput() {
        let scene = table()
        scene.firePlunger()
        scene.update(100)
        scene.update(100.02)
        let before = scene.sceneTime
        scene.setPaused(true)
        scene.pressFlipper(side: .left)
        scene.nudge(direction: 1)
        XCTAssertFalse(scene.parts.flippers.contains { $0.isPressed })
        scene.setPaused(false)
        scene.update(200)
        XCTAssertEqual(scene.sceneTime, before, accuracy: 0.001)
        XCTAssertTrue(scene.session.isBallSaveActive)
    }

    func testNewBallRaisesTargetsButSavePreservesThem() {
        let scene = table()
        scene.firePlunger()
        scene.dispatch(.dropTarget(index: 0))
        scene.dispatch(.ballDrained)
        scene.serveBall()
        XCTAssertTrue(scene.parts.dropTargets[0].isDown)
        scene.firePlunger()
        scene.dispatch(.ballDrained)
        scene.serveBall()
        XCTAssertFalse(scene.parts.dropTargets[0].isDown)
    }

    func testRestartCancelsPendingSceneActions() {
        let scene = table()
        scene.afterDelay(2) { XCTFail("stale game action ran") }
        scene.startGame()
        XCTAssertFalse(scene.hasActions())
        XCTAssertEqual(scene.balls.count, 1)
    }

    func testTiltCleanupCannotRemoveTheNextBall() {
        let scene = table()
        scene.firePlunger()
        for _ in 0..<3 { scene.dispatch(.nudged) }
        scene.dispatch(.ballDrained)
        scene.serveBall()
        XCTAssertEqual(scene.balls.count, 1)
        XCTAssertEqual(scene.session.phase, .ballReady)
    }

    func testDifferentBallsCannotCompleteEachOthersOrbit() {
        let scene = table()
        scene.firePlunger()
        let first = scene.balls[0]
        let second = scene.spawnBall(at: CGPoint(x: 0.5, y: 1.1))
        let left = SKNode()
        left.name = "orbit.left"
        let right = SKNode()
        right.name = "orbit.right"
        scene.passOrbitGate(first, node: left)
        scene.passOrbitGate(second, node: right)
        XCTAssertEqual(scene.session.score.loopsThisBall, 0)
        scene.passOrbitGate(first, node: right)
        XCTAssertEqual(scene.session.score.loopsThisBall, 1)
    }

    func testBallBelowDrainCannotFallForever() {
        let scene = table()
        scene.firePlunger()
        scene.balls[0].position = scene.geometry.point(CGPoint(x: 0.5, y: -0.2))
        scene.didSimulatePhysics()
        XCTAssertTrue(scene.balls.isEmpty)
        XCTAssertEqual(scene.session.phase, .ballReady)
    }

    func testMultiballCollisionMaskSurvivesFrameUpdate() {
        let scene = table()
        scene.firePlunger()
        scene.update(0)
        XCTAssertNotEqual(scene.balls[0].physicsBody!.collisionBitMask & PhysicsCategory.ball, 0)
    }

    func testBonusDisplayClockShiftsAcrossPause() {
        let model = GameModel()
        let start = Date(timeIntervalSince1970: 100)
        model.bonus = BonusReport(targets: 2, loops: 1, multiplier: 2)
        model.bonusStartedAt = start
        model.setDisplayPaused(true, at: start.addingTimeInterval(1))
        model.setDisplayPaused(false, at: start.addingTimeInterval(101))
        XCTAssertEqual(model.bonusStartedAt, start.addingTimeInterval(100))
    }
}

/// The shadow is what shows the ball's height: on a ramp it has to fall
/// further from the ball than on the playfield, and it must never spin.
@MainActor
final class BallLightingTests: XCTestCase {

    func testARaisedBallThrowsItsShadowFurther() {
        let ball = BallNode(radius: 10)
        ball.position = CGPoint(x: 100, y: 100)
        ball.updateLighting()
        let onTable = ball.shadow.position.distance(to: ball.position)

        ball.isOnRamp = true
        ball.updateLighting()
        let onRamp = ball.shadow.position.distance(to: ball.position)

        XCTAssertGreaterThan(onTable, 0, "the shadow sits off to one side of the ball")
        XCTAssertGreaterThan(onRamp, onTable * 1.4)
    }

    func testTheShadowIgnoresTheBallsSpin() {
        let ball = BallNode(radius: 10)
        ball.position = CGPoint(x: 50, y: 50)
        ball.updateLighting()
        let still = ball.shadow.position

        ball.zRotation = 2.4
        ball.updateLighting()
        XCTAssertEqual(ball.shadow.position.x, still.x, accuracy: 0.001)
        XCTAssertEqual(ball.shadow.position.y, still.y, accuracy: 0.001)
        XCTAssertEqual(ball.shadow.zRotation, 0)
    }
}
