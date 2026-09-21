import SpriteKit

/// A ramp drawn the way one is actually built, rather than as a thick line.
///
/// The climb is a tapering surface with a bright rail down each edge; the way
/// back is a thin wire habitrail with rungs across it. Both sit on a soft
/// shadow, which is what tells the eye the track passes *over* the targets and
/// slingshot it crosses. Painting it as one thick stroke with a felt-coloured
/// core made it read as a slot cut into the table instead.
final class RampNode: SKNode {

    let side: TableSide

    private let shadow = SKShapeNode()
    private let surface = SKShapeNode()
    private let rails = SKShapeNode()
    private let rungs = SKShapeNode()
    private let flare = SKShapeNode()

    /// Track half-widths, as fractions of the table width. The climb is wide
    /// enough to read as something the ball rides inside; the return is a wire.
    private static let entranceHalfWidth: CGFloat = 0.032
    private static let apexHalfWidth: CGFloat = 0.020
    private static let wireHalfWidth: CGFloat = 0.011

    init(config: TableLayout.Ramp, geometry: TableGeometry, palette: Palette) {
        side = config.side
        super.init()

        let centre = geometry.smoothPoints(through: config.path)
        guard centre.count > 3 else { return }

        // The high point is where the climb becomes the return.
        let apex = centre.enumerated().max { $0.element.y < $1.element.y }?.offset
            ?? centre.count / 2

        let (left, right) = edges(along: centre, apex: apex, geometry: geometry)

        addChild(shadow)
        addChild(surface)
        addChild(rails)
        addChild(rungs)
        addChild(flare)

        buildSurface(left: left, right: right, geometry: geometry)
        buildRails(left: left, right: right, geometry: geometry)
        buildRungs(left: left, right: right, from: apex, geometry: geometry)
        buildFlare(at: centre[0], towards: centre[1], geometry: geometry)

        repaint(with: palette)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    // MARK: - Shape

    /// Offsets the centre line to both sides by a half-width that narrows as
    /// the track climbs and again as it turns into the return wire.
    private func edges(along centre: [CGPoint], apex: Int,
                       geometry: TableGeometry) -> ([CGPoint], [CGPoint]) {
        let entrance = geometry.length(Self.entranceHalfWidth)
        let top = geometry.length(Self.apexHalfWidth)
        let wire = geometry.length(Self.wireHalfWidth)

        func halfWidth(at index: Int) -> CGFloat {
            if index <= apex {
                let t = CGFloat(index) / CGFloat(max(apex, 1))
                return entrance + (top - entrance) * t
            }
            // The return pinches down to a wire over the first stretch of the
            // descent, so the change reads as the track becoming a habitrail.
            let span = CGFloat(max(centre.count - apex, 1))
            let t = min(1, CGFloat(index - apex) / span * 3)
            return top + (wire - top) * t
        }

        var left: [CGPoint] = []
        var right: [CGPoint] = []

        for (index, point) in centre.enumerated() {
            let before = centre[max(index - 1, 0)]
            let after = centre[min(index + 1, centre.count - 1)]
            let along = CGVector(dx: after.x - before.x, dy: after.y - before.y).normalized()
            let across = CGVector(dx: -along.dy, dy: along.dx)
            let half = halfWidth(at: index)

            left.append(CGPoint(x: point.x + across.dx * half,
                                y: point.y + across.dy * half))
            right.append(CGPoint(x: point.x - across.dx * half,
                                 y: point.y - across.dy * half))
        }
        return (left, right)
    }

    private func buildSurface(left: [CGPoint], right: [CGPoint],
                              geometry: TableGeometry) {
        let path = CGMutablePath()
        path.addLines(between: left)
        path.addLines(between: right.reversed())
        path.closeSubpath()

        surface.path = path
        surface.lineWidth = 0
        surface.zPosition = 29

        shadow.path = path
        shadow.lineWidth = 0
        shadow.position = CGPoint(x: geometry.length(0.006), y: -geometry.length(0.012))
        shadow.zPosition = 28
    }

    private func buildRails(left: [CGPoint], right: [CGPoint],
                            geometry: TableGeometry) {
        let path = CGMutablePath()
        path.addLines(between: left)
        path.addLines(between: right)

        rails.path = path
        rails.fillColor = .clear
        rails.lineWidth = max(1.4, geometry.length(0.0055))
        rails.lineCap = .round
        rails.lineJoin = .round
        rails.glowWidth = geometry.length(0.004)
        rails.zPosition = 30
    }

    /// The cross-ties of the return wire, every few samples.
    private func buildRungs(left: [CGPoint], right: [CGPoint], from apex: Int,
                            geometry: TableGeometry) {
        let path = CGMutablePath()
        var index = apex + 4
        while index < left.count {
            path.move(to: left[index])
            path.addLine(to: right[index])
            index += 7
        }

        rungs.path = path
        rungs.fillColor = .clear
        rungs.lineWidth = max(1, geometry.length(0.0035))
        rungs.lineCap = .round
        rungs.zPosition = 30.5
    }

    /// A short funnel at the mouth, so the entrance looks like it accepts a
    /// ball rather than stopping dead at the first rail.
    private func buildFlare(at entrance: CGPoint, towards next: CGPoint,
                            geometry: TableGeometry) {
        let along = CGVector(dx: next.x - entrance.x, dy: next.y - entrance.y).normalized()
        let across = CGVector(dx: -along.dy, dy: along.dx)
        let mouth = geometry.length(Self.entranceHalfWidth * 1.55)
        let throat = geometry.length(Self.entranceHalfWidth)
        let depth = geometry.length(0.030)

        let back = CGPoint(x: entrance.x + along.dx * depth * 0.2,
                           y: entrance.y + along.dy * depth * 0.2)
        let lip = CGPoint(x: entrance.x - along.dx * depth,
                          y: entrance.y - along.dy * depth)

        // Two separate wings. Drawn as one path they were joined by a bar
        // across the throat, which read as a line blocking the entrance.
        let path = CGMutablePath()
        path.move(to: CGPoint(x: lip.x + across.dx * mouth, y: lip.y + across.dy * mouth))
        path.addLine(to: CGPoint(x: back.x + across.dx * throat,
                                 y: back.y + across.dy * throat))
        path.move(to: CGPoint(x: lip.x - across.dx * mouth, y: lip.y - across.dy * mouth))
        path.addLine(to: CGPoint(x: back.x - across.dx * throat,
                                 y: back.y - across.dy * throat))

        flare.path = path
        flare.fillColor = .clear
        flare.lineWidth = max(1.6, geometry.length(0.007))
        flare.lineCap = .round
        flare.glowWidth = geometry.length(0.005)
        flare.zPosition = 31
    }

    // MARK: - Colour

    func repaint(with palette: Palette) {
        // A warm translucent deck, not the felt colour: the track is something
        // laid on top of the table, so it must not match what is underneath.
        surface.fillColor = palette.accentDark.withAlphaComponent(0.30)
        shadow.fillColor = .black.withAlphaComponent(0.45)
        rails.strokeColor = palette.accentLight
        rungs.strokeColor = palette.accentLight.withAlphaComponent(0.6)
        flare.strokeColor = palette.accent
    }
}
