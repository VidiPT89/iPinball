import XCTest
@testable import iPinball

/// The shooter lane is a dead end if a plunge cannot carry the ball over the
/// arch above it: the ball drops back in, and nothing on the table can move it
/// out again. These measure the ballistics rather than trusting them.
final class PlungerTests: XCTestCase {

    /// Height a launch reaches, in table widths, from `v² / 2g`.
    private func rise(at speed: CGFloat) -> CGFloat {
        speed * speed / (2 * PhysicsTuning.gravity)
    }

    /// Where the arch crosses the middle of the shooter lane.
    private var archOverTheLane: CGFloat {
        let dx = TableLayout.shooterLaneCenterX - TableLayout.topArcCenter.x
        return TableLayout.topArcCenter.y
            + (TableLayout.topArcRadius * TableLayout.topArcRadius - dx * dx).squareRoot()
    }

    func testTheWeakestPlungeStillClearsTheShooterLane() {
        let top = TableLayout.ballStart.y + rise(at: PhysicsTuning.plungerMinSpeed)
        XCTAssertGreaterThan(
            top, archOverTheLane - TableLayout.ballRadius,
            "a soft plunge drops the ball back into the lane, and it is stuck there")
    }

    func testEvenAZeroLengthPullClearsTheLane() {
        // `firePlunger` floors the charge at 0.18, which is what a tap gives.
        let speed = PhysicsTuning.plungerMinSpeed
            + (PhysicsTuning.plungerMaxSpeed - PhysicsTuning.plungerMinSpeed) * 0.18
        let top = TableLayout.ballStart.y + rise(at: speed)
        XCTAssertGreaterThan(top, archOverTheLane - TableLayout.ballRadius)
    }

    func testAFullPlungeIsNotClampedAwayByTheSpeedLimit() {
        XCTAssertLessThanOrEqual(
            PhysicsTuning.plungerMaxSpeed, PhysicsTuning.maxBallSpeed,
            "the per-frame clamp would undo the launch on the first update")
    }

    func testAFullPlungeStaysInsideTheCabinet() {
        let top = TableLayout.ballStart.y + rise(at: PhysicsTuning.plungerMaxSpeed)
        XCTAssertGreaterThan(top, archOverTheLane)
        XCTAssertLessThan(top, TableLayout.height * 2.2,
                          "so fast the solver could put the ball through the arch")
    }

    func testTheLaneIsTallEnoughToBeWorthClearing() {
        // Guards the geometry the numbers above depend on.
        XCTAssertGreaterThan(archOverTheLane, TableLayout.ballStart.y + 1.0)
        XCTAssertGreaterThan(TableLayout.shooterLaneCenterX, TableLayout.playfieldRightEdge)
    }

    func testGravityIsExpressedInTableWidthsSoTheTablePlaysTheSameAtAnySize() {
        // A scene twice as wide gets twice the points-per-second-squared, which
        // is what keeps the launch reaching the same height on every screen.
        let small = TableGeometry(sceneSize: CGSize(width: 400, height: 900))
        let large = TableGeometry(sceneSize: CGSize(width: 800, height: 1800))

        let smallGravity = PhysicsTuning.gravity * small.scale / PhysicsTuning.pointsPerMetre
        let largeGravity = PhysicsTuning.gravity * large.scale / PhysicsTuning.pointsPerMetre

        XCTAssertEqual(largeGravity / smallGravity, large.scale / small.scale,
                       accuracy: 0.0001)
    }
}
