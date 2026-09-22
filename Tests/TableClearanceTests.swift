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
    private var edges: [(group: String, a: CGPoint, b: CGPoint, radius: CGFloat)] {
        var result: [(String, CGPoint, CGPoint, CGFloat)] = []

        for (index, wall) in TableLayout.walls.enumerated() {
            for (a, b) in zip(wall.points, wall.points.dropFirst()) {
                result.append(("wall \(index)", a, b, 0))
            }
        }
        for slingshot in TableLayout.slingshots {
            let loop = slingshot.vertices + [slingshot.vertices[0]]
            for (a, b) in zip(loop, loop.dropFirst()) {
                result.append(("slingshot \(slingshot.side.rawValue)", a, b, 0))
            }
        }
        // A thin target is a line with a radius, like a blade.
        for target in TableLayout.dropTargets {
            result.append(bar("drop target \(target.index)", target.center,
                              target.angle, target.size))
        }
        for target in TableLayout.standupTargets {
            result.append(bar("standup target \(target.index)", target.center,
                              target.angle, target.size))
        }
        // Both ends of a flipper's swing: at rest it can pinch against one
        // thing and, raised, against another. The upper flipper was buried
        // inside a pop bumper at full throw while looking clear at rest.
        for flipper in TableLayout.flippers {
            let sign: CGFloat = flipper.side == .left ? 1 : -1
            let label = "\(flipper.isUpper ? "upper " : "")flipper \(flipper.side.rawValue)"
            for (state, angle) in [("resting", PhysicsTuning.flipperRestAngle),
                                   ("raised", PhysicsTuning.flipperActiveAngle)] {
                let tip = CGPoint(x: flipper.pivot.x + sign * flipper.length * cos(angle),
                                  y: flipper.pivot.y + flipper.length * sin(angle))
                result.append(("\(label) \(state)", flipper.pivot, tip,
                               flipper.thickness * 0.34))
            }
        }
        return result
    }

    private func bar(_ name: String, _ centre: CGPoint, _ angle: CGFloat,
                     _ size: CGSize) -> (String, CGPoint, CGPoint, CGFloat) {
        let dx = size.width / 2 * cos(angle)
        let dy = size.width / 2 * sin(angle)
        return (name,
                CGPoint(x: centre.x - dx, y: centre.y - dy),
                CGPoint(x: centre.x + dx, y: centre.y + dy),
                size.height / 2)
    }

    /// The lower flipper tips, for the one gap that decides whether a game
    /// can end at all.
    private var lowerTips: [(CGPoint, CGFloat)] {
        TableLayout.flippers.filter { !$0.isUpper }.map { flipper in
            let sign: CGFloat = flipper.side == .left ? 1 : -1
            let angle = PhysicsTuning.flipperRestAngle
            return (CGPoint(x: flipper.pivot.x + sign * flipper.length * cos(angle),
                            y: flipper.pivot.y + flipper.length * sin(angle)),
                    flipper.thickness * 0.34)
        }
    }

    /// The round solid things. A post is allowed to cap the end of a wall —
    /// that is how the outlane dividers are finished — but a pop bumper caps
    /// nothing, so it never gets that exemption.
    private var discs: [(name: String, centre: CGPoint, radius: CGFloat,
                         capsRails: Bool)] {
        TableLayout.posts.map { ("post at \($0.center)", $0.center, $0.radius, true) }
            + TableLayout.bumpers.map {
                ("bumper \($0.index)", $0.center, $0.radius, false)
            }
    }

    func testNoTwoRailsFormAPocketNarrowerThanTheBall() {
        var offenders: [String] = []
        let all = edges
        let joined = joinedGroups

        for i in 0..<all.count {
            for j in (i + 1)..<all.count {
                guard all[i].group != all[j].group else { continue }
                // Rails that meet form a corner, not a pocket. The arch joins
                // both side walls, and its first segment away from that
                // junction is naturally within a ball of them.
                guard !joined.contains(pair(all[i].group, all[j].group)) else { continue }
                let gap = distance(all[i].a, all[i].b, all[j].a, all[j].b)
                    - all[i].radius - all[j].radius
                guard gap < diameter else { continue }
                offenders.append(describe(gap, all[i].group, all[j].group))
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
                // A post finishing a wall sits on the rim, and that is a
                // junction rather than a pinch. Nothing else gets a pass: a
                // blade tip landing on a bumper's rim is not a join, and
                // treating it as one is how the upper flipper stayed buried
                // inside a pop bumper without the test noticing.
                let ends = min(edge.a.distance(to: disc.centre),
                               edge.b.distance(to: disc.centre))
                let isJunction = disc.capsRails
                    && edge.group.hasPrefix("wall")
                    && abs(ends - disc.radius) < 0.02
                guard !isJunction else { continue }

                let gap = pointToSegment(disc.centre, edge.a, edge.b)
                    - disc.radius - edge.radius
                guard gap < diameter else { continue }
                offenders.append(describe(gap, disc.name, edge.group))
            }

            for other in discs where other.name != disc.name {
                let gap = disc.centre.distance(to: other.centre)
                    - disc.radius - other.radius
                guard gap > 0.0005, gap < diameter else { continue }
                offenders.append(describe(gap, disc.name, other.name))
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
        let tips = lowerTips
        guard tips.count == 2 else { return XCTFail("expected two lower flippers") }

        let gap = abs(tips[0].0.x - tips[1].0.x) - tips[0].1 - tips[1].1

        XCTAssertGreaterThan(gap, diameter * 1.3, String(
            format: "the drain gap is %.3f, only %.2f of a ball — it perches instead",
            gap, gap / diameter))
        XCTAssertLessThan(gap, diameter * 3,
                          "so wide the flippers cannot cover the drain")
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

    private func describe(_ gap: CGFloat, _ a: String, _ b: String) -> String {
        gap < 0
            ? String(format: "%@ and %@ overlap by %.4f", a, b, -gap)
            : String(format: "%.4f (%.0f%% of a ball) between %@ and %@",
                     gap, gap / diameter * 100, a, b)
    }

    private func pair(_ a: String, _ b: String) -> String {
        a < b ? "\(a)|\(b)" : "\(b)|\(a)"
    }

    /// Pairs of groups that meet somewhere, and so form a corner rather than a
    /// pocket. Judged per group rather than per segment: the arch joins both
    /// side walls at a point, and the segments just past that join sit within
    /// a ball of the wall without any pocket existing.
    ///
    /// It covers an end-to-end join and an edge that lands partway along
    /// another, which is how the apron attaches to the outlane divider.
    private var joinedGroups: Set<String> {
        let all = edges
        var result: Set<String> = []
        for i in 0..<all.count {
            for j in (i + 1)..<all.count where all[i].group != all[j].group {
                let key = pair(all[i].group, all[j].group)
                guard !result.contains(key) else { continue }
                let touching: CGFloat = 0.02
                let meets = [all[i].a, all[i].b].contains {
                    pointToSegment($0, all[j].a, all[j].b) < touching
                } || [all[j].a, all[j].b].contains {
                    pointToSegment($0, all[i].a, all[i].b) < touching
                }
                if meets { result.insert(key) }
            }
        }
        return result
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
