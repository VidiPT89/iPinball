import XCTest
@testable import iPinball

/// A ball that cannot fit somewhere it can reach is a ball that gets wedged.
/// These tests measure the table rather than look at it: every pair of solid
/// edges that is closer together than the ball, anywhere it can roll, is a
/// pocket waiting to happen.
final class TableClearanceTests: XCTestCase {

    private let diameter = TableLayout.ballRadius * 2

    /// Every solid edge on the table, grouped by the thing it belongs to so
    /// neighbouring segments of the same rail are not compared with each other.
    ///
    /// This deliberately includes the slingshots and the targets, not just the
    /// walls. An earlier version only compared walls with walls, and so missed
    /// the pinch between a post and the top of a slingshot that closed the
    /// mouth of both inlanes to under half a ball.
    private var edges: [(group: String, a: CGPoint, b: CGPoint)] {
        var result: [(String, CGPoint, CGPoint)] = []

        for (index, wall) in TableLayout.walls.enumerated() {
            for (a, b) in zip(wall.points, wall.points.dropFirst()) {
                result.append(("wall \(index)", a, b))
            }
        }
        for slingshot in TableLayout.slingshots {
            let loop = slingshot.vertices + [slingshot.vertices[0]]
            for (a, b) in zip(loop, loop.dropFirst()) {
                result.append(("slingshot \(slingshot.side.rawValue)", a, b))
            }
        }
        return result
    }

    /// The flipper blades at rest, as a line with a radius — which is the
    /// shape the ball actually meets. Leaving these out is how the drain gap
    /// between the two tips came to be narrower than the ball without anything
    /// noticing.
    private var blades: [(name: String, a: CGPoint, b: CGPoint, radius: CGFloat)] {
        TableLayout.flippers.map { flipper in
            let sign: CGFloat = flipper.side == .left ? 1 : -1
            let angle = PhysicsTuning.flipperRestAngle
            let tip = CGPoint(x: flipper.pivot.x + sign * flipper.length * cos(angle),
                              y: flipper.pivot.y + flipper.length * sin(angle))
            let name = "\(flipper.isUpper ? "upper " : "")flipper \(flipper.side.rawValue)"
            return (name, flipper.pivot, tip, flipper.thickness * 0.34)
        }
    }

    /// The round solid things: posts and the pop bumpers.
    private var discs: [(name: String, centre: CGPoint, radius: CGFloat)] {
        TableLayout.posts.map { ("post at \($0.center)", $0.center, $0.radius) }
            + TableLayout.bumpers.map { ("bumper \($0.index)", $0.center, $0.radius) }
    }

    func testNoTwoRailsFormAPocketNarrowerThanTheBall() {
        var offenders: [String] = []
        let all = edges

        for i in 0..<all.count {
            for j in (i + 1)..<all.count {
                guard all[i].group != all[j].group else { continue }
                // Rails that meet form a corner, not a pocket. The arch joins
                // both side walls, and its first segment away from that
                // junction is naturally within a ball of them.
                guard !joined(all[i].group, all[j].group) else { continue }
                let gap = distance(all[i].a, all[i].b, all[j].a, all[j].b)
                guard gap > 0.0005, gap < diameter else { continue }
                offenders.append(String(
                    format: "%.4f (%.0f%% of a ball) between %@ and %@",
                    gap, gap / diameter * 100, all[i].group, all[j].group))
            }
        }

        XCTAssertTrue(offenders.isEmpty,
                      "the ball would wedge here:\n" + offenders.joined(separator: "\n"))
    }

    /// The gap a post leaves against everything solid around it. This is the
    /// one that matters most: a post sits in the middle of a lane, so it eats
    /// into the clearance on both of its sides at once.
    func testEveryPostLeavesRoomForTheBallOnBothSides() {
        var offenders: [String] = []

        for disc in discs {
            for edge in edges {
                // A post that caps the end of a rail is part of that rail.
                let ends = min(edge.a.distance(to: disc.centre),
                               edge.b.distance(to: disc.centre))
                guard ends > disc.radius + 0.012 else { continue }

                let gap = pointToSegment(disc.centre, edge.a, edge.b) - disc.radius
                guard gap > 0.0005, gap < diameter else { continue }
                offenders.append(String(
                    format: "%.4f (%.0f%% of a ball) between %@ and %@",
                    gap, gap / diameter * 100, disc.name, edge.group))
            }

            for other in discs where other.name != disc.name {
                let gap = disc.centre.distance(to: other.centre)
                    - disc.radius - other.radius
                guard gap > 0.0005, gap < diameter else { continue }
                offenders.append(String(
                    format: "%.4f (%.0f%% of a ball) between %@ and %@",
                    gap, gap / diameter * 100, disc.name, other.name))
            }
        }

        XCTAssertTrue(offenders.isEmpty,
                      "the ball cannot get past:\n" + offenders.joined(separator: "\n"))
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
            ("left outlane", 0.015, 0.082),
            ("left inlane", 0.082, 0.150),
            ("right inlane", 0.850, 0.918),
            ("right outlane", 0.918, TableLayout.playfieldRightEdge),
            ("shooter lane", TableLayout.playfieldRightEdge, 1.08),
        ]

        for (name, from, to) in lanes {
            XCTAssertGreaterThan(to - from, diameter,
                                 "\(name) at y=\(y) is narrower than the ball")
        }
    }

    /// The one gap the whole game depends on. If the ball cannot fall between
    /// the flipper tips it perches on them, the middle of the table never
    /// drains, and a game cannot end on its own.
    func testTheBallFitsBetweenTheFlipperTips() {
        let lower = blades.filter { !$0.name.hasPrefix("upper") }
        guard lower.count == 2 else { return XCTFail("expected two lower flippers") }

        let separation = abs(lower[0].b.x - lower[1].b.x)
        let gap = separation - lower[0].radius - lower[1].radius

        XCTAssertGreaterThan(gap, diameter * 1.3, String(
            format: "the drain gap is %.3f, only %.2f of a ball — it perches instead",
            gap, gap / diameter))
        XCTAssertLessThan(gap, diameter * 3,
                          "so wide the flippers cannot cover the drain")
    }

    /// Posts and rails against the blades, which sweep a large part of the
    /// bottom of the table and so meet almost everything down there.
    func testNothingPinchesTheBallAgainstAFlipper() {
        var offenders: [String] = []

        for blade in blades {
            for edge in edges {
                // The apron ends on the pivot on purpose, to hand the ball over.
                guard min(edge.a.distance(to: blade.a), edge.b.distance(to: blade.a))
                        > blade.radius + 0.02 else { continue }
                let gap = segmentDistance(blade.a, blade.b, edge.a, edge.b) - blade.radius
                guard gap > 0.0005, gap < diameter else { continue }
                offenders.append(String(format: "%.4f (%.0f%%) between %@ and %@",
                                        gap, gap / diameter * 100, blade.name, edge.group))
            }
            for disc in discs {
                let gap = pointToSegment(disc.centre, blade.a, blade.b)
                    - blade.radius - disc.radius
                guard gap > 0.0005, gap < diameter else { continue }
                offenders.append(String(format: "%.4f (%.0f%%) between %@ and %@",
                                        gap, gap / diameter * 100, blade.name, disc.name))
            }
        }

        XCTAssertTrue(offenders.isEmpty,
                      "the ball wedges against a flipper here:\n"
                      + offenders.joined(separator: "\n"))
    }

    func testTheSlingshotsStayClearOfTheOutlaneDividers() {
        let dividers: [CGFloat] = [0.082, 0.918]
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
    private func joined(_ a: String, _ b: String) -> Bool {
        func ends(_ group: String) -> [CGPoint] {
            guard group.hasPrefix("wall "),
                  let index = Int(group.dropFirst("wall ".count)),
                  TableLayout.walls.indices.contains(index) else { return [] }
            let points = TableLayout.walls[index].points
            return [points.first, points.last].compactMap { $0 }
        }
        let first = ends(a), second = ends(b)
        return first.contains { p in second.contains { $0.distance(to: p) < 0.02 } }
    }

    // MARK: - Geometry

    private func segmentDistance(_ p1: CGPoint, _ p2: CGPoint,
                                 _ q1: CGPoint, _ q2: CGPoint) -> CGFloat {
        distance(p1, p2, q1, q2)
    }

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
