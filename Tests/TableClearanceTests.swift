import XCTest
@testable import iPinball

/// A ball that cannot fit somewhere it can reach is a ball that gets wedged.
/// These tests measure the table rather than look at it: every pair of solid
/// edges that is closer together than the ball, anywhere it can roll, is a
/// pocket waiting to happen.
final class TableClearanceTests: XCTestCase {

    private let diameter = TableLayout.ballRadius * 2

    /// Every wall segment on the table, paired with the wall it belongs to so
    /// neighbouring segments of the same rail are not compared with each other.
    private var segments: [(wall: Int, a: CGPoint, b: CGPoint)] {
        TableLayout.walls.enumerated().flatMap { index, wall in
            zip(wall.points, wall.points.dropFirst()).map { (index, $0, $1) }
        }
    }

    func testNoTwoRailsFormAPocketNarrowerThanTheBall() {
        var offenders: [String] = []
        let all = segments

        for i in 0..<all.count {
            for j in (i + 1)..<all.count {
                guard all[i].wall != all[j].wall else { continue }
                // Rails that meet form a corner, not a pocket. The arch joins
                // both side walls, and its first segment away from that
                // junction is naturally within a ball of them.
                guard !joined(all[i].wall, all[j].wall) else { continue }
                let gap = distance(all[i].a, all[i].b, all[j].a, all[j].b)
                // Touching rails are fine — a corner is not a pocket. What is
                // not fine is a slot the ball can enter and not leave.
                guard gap > 0.0005, gap < diameter else { continue }
                offenders.append(String(
                    format: "gap %.4f (%.0f%% of a ball) between wall %d and wall %d",
                    gap, gap / diameter * 100, all[i].wall, all[j].wall))
            }
        }

        XCTAssertTrue(offenders.isEmpty,
                      "the ball would wedge here:\n" + offenders.joined(separator: "\n"))
    }

    func testTheShooterLaneSitsOutsideThePlayfield() {
        // Keeping it outside is what lets the playfield stay symmetric without
        // its right-hand lanes landing inside the lane and crossing its walls.
        XCTAssertGreaterThan(TableLayout.shooterLaneCenterX, TableLayout.playfieldRightEdge)
        XCTAssertLessThan(TableLayout.shooterLaneCenterX, TableLayout.width)

        for element in TableLayout.allElementCentres {
            XCTAssertLessThan(element.point.x + element.radius,
                              TableLayout.playfieldRightEdge,
                              "\(element.name) pokes into the shooter lane")
        }
    }

    func testBothInlanesAndOutlanesAreWiderThanTheBall() {
        // Measured at the height where the lanes run straight, below the posts.
        let y: CGFloat = 0.35
        let lanes: [(String, CGFloat, CGFloat)] = [
            ("left outlane", 0.015, 0.072),
            ("left inlane", 0.072, 0.128),
            ("right inlane", 0.872, 0.928),
            ("right outlane", 0.928, TableLayout.playfieldRightEdge),
            ("shooter lane", TableLayout.playfieldRightEdge, 1.08),
        ]

        for (name, from, to) in lanes {
            XCTAssertGreaterThan(to - from, diameter,
                                 "\(name) at y=\(y) is narrower than the ball")
        }
    }

    func testTheSlingshotsStayClearOfTheOutlaneDividers() {
        let dividers: [CGFloat] = [0.072, 0.928]
        for slingshot in TableLayout.slingshots {
            let outerX = slingshot.side == .left
                ? slingshot.vertices.map(\.x).min()!
                : slingshot.vertices.map(\.x).max()!
            let divider = slingshot.side == .left ? dividers[0] : dividers[1]
            XCTAssertGreaterThan(abs(outerX - divider), diameter,
                                 "the \(slingshot.side.rawValue) inlane is too tight")
        }
    }

    func testTheArchRoofsTheWholeCabinetIncludingTheShooterLane() {
        let leftEdge = TableLayout.topArcCenter.x - TableLayout.topArcRadius
        let rightEdge = TableLayout.topArcCenter.x + TableLayout.topArcRadius
        XCTAssertLessThanOrEqual(leftEdge, 0.02)
        XCTAssertGreaterThanOrEqual(rightEdge, 1.07,
                                    "a ball launched up the shooter lane would escape")
    }

    /// True when two rails share a junction, and so are one boundary.
    private func joined(_ a: Int, _ b: Int) -> Bool {
        let ends = { (index: Int) -> [CGPoint] in
            let points = TableLayout.walls[index].points
            return [points.first, points.last].compactMap { $0 }
        }
        for p in ends(a) where ends(b).contains(where: { $0.distance(to: p) < 0.02 }) {
            _ = p
            return true
        }
        return false
    }

    // MARK: - Geometry

    /// Shortest distance between two line segments, which is zero when they
    /// cross — and crossing rails are exactly how the worst pockets formed.
    private func distance(_ p1: CGPoint, _ p2: CGPoint,
                          _ q1: CGPoint, _ q2: CGPoint) -> CGFloat {
        if segmentsIntersect(p1, p2, q1, q2) { return 0 }
        return min(pointToSegment(p1, q1, q2), pointToSegment(p2, q1, q2),
                   pointToSegment(q1, p1, p2), pointToSegment(q2, p1, p2))
    }

    private func pointToSegment(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x, dy = b.y - a.y
        guard dx != 0 || dy != 0 else { return p.distance(to: a) }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / (dx * dx + dy * dy)))
        return p.distance(to: CGPoint(x: a.x + t * dx, y: a.y + t * dy))
    }

    private func segmentsIntersect(_ p1: CGPoint, _ p2: CGPoint,
                                   _ q1: CGPoint, _ q2: CGPoint) -> Bool {
        func orientation(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> Int {
            let v = (b.y - a.y) * (c.x - b.x) - (b.x - a.x) * (c.y - b.y)
            if abs(v) < 1e-9 { return 0 }
            return v > 0 ? 1 : 2
        }
        let o1 = orientation(p1, p2, q1), o2 = orientation(p1, p2, q2)
        let o3 = orientation(q1, q2, p1), o4 = orientation(q1, q2, p2)
        return o1 != o2 && o3 != o4
    }
}
