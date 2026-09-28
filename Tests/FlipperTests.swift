import SpriteKit
import XCTest
@testable import iPinball

/// A flipper used to get one push when pressed and one when released, and
/// nothing in between. A ball resting on a held flipper pushed it back down,
/// and the ball sat on a flipper that no longer did what the button said.
/// `drive()` now runs every frame; these tests pin down what it asks for.
final class FlipperTests: XCTestCase {

    private let geometry = TableGeometry(sceneSize: CGSize(width: 560, height: 940))
    private let range = PhysicsTuning.flipperActiveAngle - PhysicsTuning.flipperRestAngle

    private func flipper(_ side: TableSide) throws -> FlipperNode {
        let config = try XCTUnwrap(TableLayout.flippers.first { $0.side == side })
        return FlipperNode(config: config, geometry: geometry, palette: .dark)
    }

    private func sign(_ side: TableSide) -> CGFloat { side == .left ? 1 : -1 }

    /// Puts the blade `travel` radians up from rest, the way physics would.
    private func raise(_ node: FlipperNode, by travel: CGFloat, side: TableSide) {
        node.zRotation = sign(side) * (PhysicsTuning.flipperRestAngle + travel)
    }

    func testPressingSwingsTheBladeUpAtFullSpeed() throws {
        for side in [TableSide.left, .right] {
            let node = try flipper(side)
            node.press()
            XCTAssertEqual(node.physicsBody?.angularVelocity ?? 0,
                           sign(side) * PhysicsTuning.flipperAngularSpeed,
                           accuracy: 1e-6, "\(side)")
        }
    }

    func testAHeldFlipperStaysPutAndFightsBackWhenPushedDown() throws {
        for side in [TableSide.left, .right] {
            let node = try flipper(side)
            node.press()

            raise(node, by: range, side: side)
            node.drive()
            XCTAssertEqual(node.physicsBody?.angularVelocity ?? 1, 0, accuracy: 1e-6,
                           "\(side): fully up, it has nowhere further to go")

            // A ball resting on it has pushed it part of the way down.
            raise(node, by: range - 0.1, side: side)
            node.drive()
            let push = (node.physicsBody?.angularVelocity ?? 0) * sign(side)
            XCTAssertGreaterThan(push, 0, "\(side): it has to push back up")
        }
    }

    func testReleasingBringsTheBladeBackDownAndHoldsItThere() throws {
        for side in [TableSide.left, .right] {
            let node = try flipper(side)
            node.press()
            raise(node, by: range, side: side)
            node.release()
            let fall = (node.physicsBody?.angularVelocity ?? 0) * sign(side)
            XCTAssertLessThan(fall, 0, "\(side): released, it swings back down")

            raise(node, by: 0, side: side)
            node.drive()
            XCTAssertEqual(node.physicsBody?.angularVelocity ?? 1, 0, accuracy: 1e-6,
                           "\(side): at rest, it stays at rest")
        }
    }

    func testOnlyAHeldFlipperCradlesTheBall() throws {
        let node = try flipper(.left)
        let onTheBlade = CGPoint(x: node.pivotInScene.x + node.reach * 0.5,
                                 y: node.pivotInScene.y)
        XCTAssertFalse(node.isCradling(onTheBlade), "a flipper at rest holds nothing")
        node.press()
        XCTAssertTrue(node.isCradling(onTheBlade))
        let farAway = CGPoint(x: node.pivotInScene.x, y: node.pivotInScene.y + node.reach * 3)
        XCTAssertFalse(node.isCradling(farAway))
    }
}
