import CoreGraphics
import XCTest
@testable import iPinball

/// Pop bumpers and slingshots used to set one fixed velocity whatever the ball
/// was doing, so every ball that touched them left along the same line. These
/// tests pin down the replacement: the kick adds to the ball's own motion.
final class KickModelTests: XCTestCase {

    private let up = CGVector(dx: 0, dy: 1)

    private func dot(_ a: CGVector, _ b: CGVector) -> CGFloat { a.dx * b.dx + a.dy * b.dy }

    func testTheWayTheBallComesInDecidesTheWayItGoesOut() {
        let fromLeft = KickModel.activeKick(incoming: CGVector(dx: 1.5, dy: -1),
                                            normal: up, kickSpeed: 2, spin: 0)
        let fromRight = KickModel.activeKick(incoming: CGVector(dx: -1.5, dy: -1),
                                             normal: up, kickSpeed: 2, spin: 0)
        XCTAssertGreaterThan(fromLeft.dx, 0.5, "a ball arriving from the left carries on right")
        XCTAssertLessThan(fromRight.dx, -0.5, "and one from the right carries on left")
    }

    func testTheBallAlwaysLeavesAwayFromTheKicker() {
        for angle in stride(from: 0.0, to: 2 * Double.pi, by: 0.3) {
            let incoming = CGVector(angle: CGFloat(angle), magnitude: 3)
            let out = KickModel.activeKick(incoming: incoming, normal: up,
                                           kickSpeed: 1.5, spin: 0)
            // At least the kick itself, even for a ball that only grazed it.
            XCTAssertGreaterThanOrEqual(dot(out, up), 1.5 - 1e-6, "angle \(angle)")
        }
    }

    func testAHarderHitComesBackFaster() {
        let soft = KickModel.activeKick(incoming: CGVector(dx: 0, dy: -0.5),
                                        normal: up, kickSpeed: 2, spin: 0)
        let hard = KickModel.activeKick(incoming: CGVector(dx: 0, dy: -4),
                                        normal: up, kickSpeed: 2, spin: 0)
        XCTAssertGreaterThan(hard.magnitude, soft.magnitude)
    }

    func testSpinTurnsTheKickWithoutChangingItsSpeed() {
        let straight = KickModel.activeKick(incoming: CGVector(dx: 0, dy: -2),
                                            normal: up, kickSpeed: 2, spin: 0)
        let turned = KickModel.activeKick(incoming: CGVector(dx: 0, dy: -2),
                                          normal: up, kickSpeed: 2, spin: 0.1)
        XCTAssertEqual(straight.magnitude, turned.magnitude, accuracy: 1e-6)
        XCTAssertNotEqual(straight.dx, turned.dx, accuracy: 1e-3)
    }

    // MARK: - Slingshot face

    /// The left slingshot's rubber runs from its inner corner up to its top.
    private let face = (a: CGPoint(x: 0.318, y: 0.412), b: CGPoint(x: 0.150, y: 0.505))
    private let inside = CGPoint(x: 0.150, y: 0.318)

    func testTheFaceNormalPointsUpAndIntoThePlayfield() {
        let normal = KickModel.faceNormal(from: face.a, to: face.b, awayFrom: inside)
        XCTAssertGreaterThan(normal.dx, 0)
        XCTAssertGreaterThan(normal.dy, 0)
        XCTAssertEqual(normal.magnitude, 1, accuracy: 1e-6)
    }

    func testOnlyABallOnTheRubberFaceFiresTheSlingshot() {
        let normal = KickModel.faceNormal(from: face.a, to: face.b, awayFrom: inside)
        let middle = CGPoint(x: (face.a.x + face.b.x) / 2, y: (face.a.y + face.b.y) / 2)
        let onFace = CGPoint(x: middle.x + normal.dx * 0.02, y: middle.y + normal.dy * 0.02)
        XCTAssertTrue(KickModel.touchesFace(onFace, from: face.a, to: face.b,
                                            normal: normal, reach: 0.03))

        // Underneath the slingshot, against its lower edge.
        let below = CGPoint(x: 0.24, y: 0.34)
        XCTAssertFalse(KickModel.touchesFace(below, from: face.a, to: face.b,
                                             normal: normal, reach: 0.03))

        // Level with the face but past its end.
        let pastTheEnd = CGPoint(x: 0.36, y: 0.42)
        XCTAssertFalse(KickModel.touchesFace(pastTheEnd, from: face.a, to: face.b,
                                             normal: normal, reach: 0.03))
    }

    func testBothTableSlingshotsKickUpAndTowardsTheMiddle() {
        for sling in TableLayout.slingshots {
            let v = sling.vertices
            let normal = KickModel.faceNormal(from: v[2], to: v[0], awayFrom: v[1])
            XCTAssertGreaterThan(normal.dy, 0.3, "\(sling.side)")
            XCTAssertEqual(normal.dx > 0, sling.side == .left, "\(sling.side)")
        }
    }

    // MARK: - Ejects

    func testAnEjectIsVariedButStaysCloseToItsAim() {
        let aim: CGFloat = -1.15
        let low = KickModel.eject(angle: aim, speed: 2, variation: -1,
                                  angleSpread: 0.1, speedSpread: 0.1)
        let high = KickModel.eject(angle: aim, speed: 2, variation: 1,
                                   angleSpread: 0.1, speedSpread: 0.1)
        XCTAssertNotEqual(low.dx, high.dx, accuracy: 1e-3)
        for vector in [low, high] {
            XCTAssertEqual(atan2(vector.dy, vector.dx), aim, accuracy: 0.1 + 1e-6)
            XCTAssertEqual(vector.magnitude, 2, accuracy: 0.2 + 1e-6)
        }
    }

    // MARK: - Ramp entry

    /// A ball coming off the left orbit rolls across the mouth of the left
    /// ramp on its way to the inlane. The mouth sensor used to check only the
    /// speed, so that ball was carried up the ramp as if it had been shot
    /// there — once on every single ball.
    func testOnlyABallHeadingUpIntoTheMouthMakesTheClimb() throws {
        let ramp = try XCTUnwrap(TableLayout.ramps.first { $0.side == .left })
        let minimum: CGFloat = 0.7
        let up = ramp.entryDirection

        XCTAssertTrue(ramp.admits(CGVector(dx: up.dx * 2, dy: up.dy * 2), minimumSpeed: minimum))
        XCTAssertFalse(ramp.admits(CGVector(dx: 2, dy: -0.4), minimumSpeed: minimum),
                       "rolling across the mouth towards the inlane")
        XCTAssertFalse(ramp.admits(CGVector(dx: -up.dx * 2, dy: -up.dy * 2), minimumSpeed: minimum),
                       "coming back down out of the mouth")
        XCTAssertFalse(ramp.admits(CGVector(dx: up.dx * 0.5, dy: up.dy * 0.5), minimumSpeed: minimum),
                       "too slow to climb")
    }

    func testEveryRampClimbsAwayFromTheFlippers() {
        for ramp in TableLayout.ramps {
            XCTAssertGreaterThan(ramp.entryDirection.dy, 0.8, "\(ramp.side)")
            XCTAssertEqual(ramp.entryDirection.magnitude, 1, accuracy: 1e-6)
        }
    }
}

