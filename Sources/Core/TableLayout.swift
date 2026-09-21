import CoreGraphics
import Foundation

/// The whole table expressed in layout units, independent of screen size.
///
/// `x` runs 0…1 across the cabinet and `y` runs 0…`height` from the drain to
/// the top arc. Both axes share one scale factor, so a circle stays a circle
/// once `TableBuilder` maps these values onto the screen.
enum TableLayout {

    /// The cabinet, not the playfield. The shooter lane lives outside the
    /// playable area, which is what keeps the playfield symmetric about its
    /// own centre: mirroring the right-hand lanes about the cabinet centre
    /// used to drop them inside the shooter lane, where they crossed its
    /// walls and formed pockets narrower than the ball.
    static let width: CGFloat = 1.09
    static let height: CGFloat = 1.85
    static var aspectRatio: CGFloat { height / width }

    static let ballRadius: CGFloat = PhysicsTuning.ballRadiusRatio
    static let wallThickness: CGFloat = 0.012

    // MARK: - Key anchors

    /// Centred on the cabinet, so the arch roofs the shooter lane too.
    static let topArcCenter = CGPoint(x: 0.5475, y: 1.30)
    static let topArcRadius: CGFloat = 0.5325

    static let playfieldRightEdge: CGFloat = 1.00
    static let shooterLaneCenterX: CGFloat = 1.040
    static let shooterLaneBottomY: CGFloat = 0.13

    static let ballStart = CGPoint(x: shooterLaneCenterX, y: shooterLaneBottomY + 0.05)

    // MARK: - Structures

    /// Every wall on this table is an open chain; none of them close a loop.
    struct Wall {
        let points: [CGPoint]
    }

    struct Bumper {
        let index: Int
        let center: CGPoint
        let radius: CGFloat
    }

    struct Slingshot {
        let side: TableSide
        let vertices: [CGPoint]
    }

    struct DropTarget {
        let index: Int
        let center: CGPoint
        let angle: CGFloat
        let size: CGSize
    }

    struct StandupTarget {
        let index: Int
        let center: CGPoint
        let angle: CGFloat
        let size: CGSize
    }

    struct Rollover {
        let index: Int
        let center: CGPoint
        let radius: CGFloat
    }

    struct Saucer {
        let side: TableSide
        let center: CGPoint
        let radius: CGFloat
        let ejectAngle: CGFloat
    }

    struct Ramp {
        let side: TableSide
        /// Entrance first, exit last. The ball is carried along this spline.
        let path: [CGPoint]
        let entranceRadius: CGFloat
        /// Direction the ball leaves with, in radians.
        let exitAngle: CGFloat
    }

    struct OrbitGate {
        let side: TableSide
        let center: CGPoint
        let size: CGSize
    }

    struct Flipper {
        let side: TableSide
        let pivot: CGPoint
        let length: CGFloat
        let thickness: CGFloat
        let isUpper: Bool
    }

    struct Spinner {
        let center: CGPoint
        let length: CGFloat
        let angle: CGFloat
    }

    struct Post {
        let center: CGPoint
        let radius: CGFloat
    }

    // MARK: - Perimeter and guides

    static let topArc: [CGPoint] = {
        stride(from: CGFloat.pi, through: 0, by: -CGFloat.pi / 48).map { angle in
            CGPoint(x: topArcCenter.x + cos(angle) * topArcRadius,
                    y: topArcCenter.y + sin(angle) * topArcRadius)
        }
    }()

    static var walls: [Wall] {
        [
            // Left outer wall, from the bottom of the outlane up into the arc.
            Wall(points: [CGPoint(x: 0.015, y: 0.0), CGPoint(x: 0.015, y: 1.30)]),
            Wall(points: topArc),
            // Right outer wall, down the far side of the shooter lane.
            Wall(points: [CGPoint(x: 1.08, y: 1.30), CGPoint(x: 1.08, y: 0.13),
                          CGPoint(x: 1.00, y: 0.13)]),
            // Shooter lane divider, stopping short of the arc so the ball escapes.
            // It doubles as the right edge of the playfield.
            Wall(points: [CGPoint(x: 1.00, y: 0.13), CGPoint(x: 1.00, y: 1.14),
                          CGPoint(x: 0.985, y: 1.20)]),
            // Left outlane / inlane divider.
            Wall(points: [CGPoint(x: 0.072, y: 0.0), CGPoint(x: 0.072, y: 0.44),
                          CGPoint(x: 0.105, y: 0.53)]),
            // Right outlane / inlane divider.
            Wall(points: [CGPoint(x: 0.928, y: 0.0), CGPoint(x: 0.928, y: 0.44),
                          CGPoint(x: 0.895, y: 0.53)]),
            // Left apron: inlane floor that feeds the flipper, then the drain lip.
            Wall(points: [CGPoint(x: 0.072, y: 0.30), CGPoint(x: 0.215, y: 0.215),
                          CGPoint(x: 0.300, y: 0.150), CGPoint(x: 0.420, y: 0.092),
                          CGPoint(x: 0.455, y: 0.072), CGPoint(x: 0.455, y: 0.0)]),
            // Right apron, mirrored.
            Wall(points: [CGPoint(x: 0.928, y: 0.30), CGPoint(x: 0.785, y: 0.215),
                          CGPoint(x: 0.700, y: 0.150), CGPoint(x: 0.580, y: 0.092),
                          CGPoint(x: 0.545, y: 0.072), CGPoint(x: 0.545, y: 0.0)]),
            // Left orbit guide: inner wall of the lane hugging the left rail.
            Wall(points: [CGPoint(x: 0.108, y: 0.60), CGPoint(x: 0.100, y: 0.86),
                          CGPoint(x: 0.108, y: 1.10), CGPoint(x: 0.150, y: 1.24),
                          CGPoint(x: 0.230, y: 1.32)]),
            // Right orbit guide.
            Wall(points: [CGPoint(x: 0.892, y: 0.60), CGPoint(x: 0.900, y: 0.86),
                          CGPoint(x: 0.892, y: 1.10), CGPoint(x: 0.850, y: 1.24),
                          CGPoint(x: 0.770, y: 1.32)]),
            // Lane dividers between the four P-I-N-B rollovers.
            Wall(points: [CGPoint(x: 0.380, y: 1.46), CGPoint(x: 0.380, y: 1.27)]),
            Wall(points: [CGPoint(x: 0.500, y: 1.48), CGPoint(x: 0.500, y: 1.27)]),
            Wall(points: [CGPoint(x: 0.620, y: 1.46), CGPoint(x: 0.620, y: 1.27)]),
            // Funnel that drops the lanes into the bumper nest.
            Wall(points: [CGPoint(x: 0.260, y: 1.27), CGPoint(x: 0.300, y: 1.18)]),
            Wall(points: [CGPoint(x: 0.740, y: 1.27), CGPoint(x: 0.700, y: 1.18)]),
        ]
    }

    static var posts: [Post] {
        [
            Post(center: CGPoint(x: 0.105, y: 0.53), radius: 0.016),
            Post(center: CGPoint(x: 0.895, y: 0.53), radius: 0.016),
            Post(center: CGPoint(x: 0.300, y: 0.150), radius: 0.013),
            Post(center: CGPoint(x: 0.700, y: 0.150), radius: 0.013),
            Post(center: CGPoint(x: 0.500, y: 0.56), radius: 0.015),
        ]
    }

    // MARK: - Interactive elements

    static let bumpers: [Bumper] = [
        Bumper(index: 0, center: CGPoint(x: 0.315, y: 0.96), radius: 0.072),
        Bumper(index: 1, center: CGPoint(x: 0.500, y: 1.07), radius: 0.072),
        Bumper(index: 2, center: CGPoint(x: 0.685, y: 0.96), radius: 0.072),
    ]

    static let slingshots: [Slingshot] = [
        Slingshot(side: .left, vertices: [
            CGPoint(x: 0.128, y: 0.505),
            CGPoint(x: 0.128, y: 0.318),
            CGPoint(x: 0.318, y: 0.412),
        ]),
        Slingshot(side: .right, vertices: [
            CGPoint(x: 0.872, y: 0.505),
            CGPoint(x: 0.872, y: 0.318),
            CGPoint(x: 0.682, y: 0.412),
        ]),
    ]

    /// Bank of five, angled so a flipper shot sweeps across it.
    static let dropTargets: [DropTarget] = {
        let start = CGPoint(x: 0.165, y: 0.640)
        let step = CGPoint(x: 0.0615, y: 0.0224)
        return (0..<5).map { i in
            DropTarget(index: i,
                       center: CGPoint(x: start.x + step.x * CGFloat(i),
                                       y: start.y + step.y * CGFloat(i)),
                       angle: 0.35,
                       size: CGSize(width: 0.052, height: 0.020))
        }
    }()

    static let standupTargets: [StandupTarget] = [
        StandupTarget(index: 0, center: CGPoint(x: 0.680, y: 0.740),
                      angle: -0.55, size: CGSize(width: 0.050, height: 0.020)),
        StandupTarget(index: 1, center: CGPoint(x: 0.775, y: 0.660),
                      angle: -0.75, size: CGSize(width: 0.050, height: 0.020)),
        StandupTarget(index: 2, center: CGPoint(x: 0.840, y: 0.560),
                      angle: -0.95, size: CGSize(width: 0.050, height: 0.020)),
        StandupTarget(index: 3, center: CGPoint(x: 0.500, y: 0.905),
                      angle: 0.0, size: CGSize(width: 0.055, height: 0.020)),
    ]

    static let rollovers: [Rollover] = (0..<4).map { i in
        Rollover(index: i,
                 center: CGPoint(x: 0.32 + 0.12 * CGFloat(i), y: 1.345),
                 radius: 0.030)
    }

    static let saucers: [Saucer] = [
        Saucer(side: .left, center: CGPoint(x: 0.155, y: 1.07),
               radius: 0.040, ejectAngle: -0.45),
        Saucer(side: .right, center: CGPoint(x: 0.845, y: 0.760),
               radius: 0.040, ejectAngle: .pi + 0.65),
    ]

    /// The climb runs up the side, turns over at the top and comes back down
    /// as a habitrail that feeds the inlane. The turn is rounded rather than a
    /// reversal between two points, which used to render as a spike, and the
    /// apex stops below the saucer instead of crossing it.
    static let ramps: [Ramp] = [
        Ramp(side: .left,
             path: [CGPoint(x: 0.285, y: 0.520), CGPoint(x: 0.254, y: 0.690),
                    CGPoint(x: 0.224, y: 0.860), CGPoint(x: 0.198, y: 0.975),
                    CGPoint(x: 0.168, y: 1.012), CGPoint(x: 0.136, y: 0.988),
                    CGPoint(x: 0.120, y: 0.880), CGPoint(x: 0.111, y: 0.700),
                    CGPoint(x: 0.110, y: 0.510), CGPoint(x: 0.118, y: 0.365)],
             entranceRadius: 0.042,
             exitAngle: -1.35),
        Ramp(side: .right,
             path: [CGPoint(x: 0.715, y: 0.520), CGPoint(x: 0.746, y: 0.690),
                    CGPoint(x: 0.776, y: 0.860), CGPoint(x: 0.802, y: 0.975),
                    CGPoint(x: 0.832, y: 1.012), CGPoint(x: 0.864, y: 0.988),
                    CGPoint(x: 0.880, y: 0.880), CGPoint(x: 0.889, y: 0.700),
                    CGPoint(x: 0.890, y: 0.510), CGPoint(x: 0.882, y: 0.365)],
             entranceRadius: 0.042,
             exitAngle: -1.79),
    ]

    static let orbitGates: [OrbitGate] = [
        OrbitGate(side: .left, center: CGPoint(x: 0.062, y: 0.82),
                  size: CGSize(width: 0.080, height: 0.020)),
        OrbitGate(side: .right, center: CGPoint(x: 0.938, y: 0.82),
                  size: CGSize(width: 0.080, height: 0.020)),
    ]

    static let spinner = Spinner(center: CGPoint(x: 0.062, y: 0.66),
                                 length: 0.072, angle: 0.0)

    static let magnetCenter = CGPoint(x: 0.500, y: 0.790)
    static let magnetRadius: CGFloat = 0.10

    static let flippers: [Flipper] = [
        Flipper(side: .left, pivot: CGPoint(x: 0.315, y: 0.175),
                length: 0.170, thickness: 0.030, isUpper: false),
        Flipper(side: .right, pivot: CGPoint(x: 0.685, y: 0.175),
                length: 0.170, thickness: 0.030, isUpper: false),
        Flipper(side: .left, pivot: CGPoint(x: 0.245, y: 0.985),
                length: 0.140, thickness: 0.026, isUpper: true),
    ]

    /// Sensor strip across the bottom that ends a ball.
    static let drainRect = CGRect(x: 0.0, y: -0.02, width: width, height: 0.045)

    // MARK: - Helpers

    static func contains(_ point: CGPoint) -> Bool {
        point.x >= 0 && point.x <= width && point.y >= -0.05 && point.y <= height
    }

    /// Every interactive element centre, used by the layout tests to prove that
    /// nothing was placed off the table or on top of something else.
    static var allElementCentres: [(name: String, point: CGPoint, radius: CGFloat)] {
        var result: [(String, CGPoint, CGFloat)] = []
        bumpers.forEach { result.append(("bumper\($0.index)", $0.center, $0.radius)) }
        dropTargets.forEach { result.append(("drop\($0.index)", $0.center, $0.size.width / 2)) }
        standupTargets.forEach { result.append(("standup\($0.index)", $0.center, $0.size.width / 2)) }
        rollovers.forEach { result.append(("rollover\($0.index)", $0.center, $0.radius)) }
        saucers.forEach { result.append(("saucer-\($0.side.rawValue)", $0.center, $0.radius)) }
        return result
    }
}
