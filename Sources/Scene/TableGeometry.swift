import CoreGraphics

/// Converts the layout units of `TableLayout` into scene points.
/// One uniform scale for both axes keeps circles round.
struct TableGeometry {

    let scale: CGFloat
    let origin: CGPoint

    /// `topInset` is the strip at the top of the scene the HUD sits over. The
    /// table is fitted into what is left, so the top arc is never hidden
    /// behind the scoreboard.
    init(sceneSize: CGSize, topInset: CGFloat = 0) {
        let usableHeight = max(1, sceneSize.height - topInset)
        let fitted = min(sceneSize.width / TableLayout.width,
                         usableHeight / TableLayout.height)
        scale = fitted
        origin = CGPoint(x: (sceneSize.width - TableLayout.width * fitted) / 2,
                         y: (usableHeight - TableLayout.height * fitted) / 2)
    }

    func point(_ p: CGPoint) -> CGPoint {
        CGPoint(x: origin.x + p.x * scale, y: origin.y + p.y * scale)
    }

    /// The inverse of `point`, for asking where something is on the table.
    func localPoint(_ p: CGPoint) -> CGPoint {
        CGPoint(x: (p.x - origin.x) / scale, y: (p.y - origin.y) / scale)
    }

    func length(_ value: CGFloat) -> CGFloat { value * scale }

    func size(_ value: CGSize) -> CGSize {
        CGSize(width: value.width * scale, height: value.height * scale)
    }

    func rect(_ value: CGRect) -> CGRect {
        CGRect(origin: point(value.origin), size: size(value.size))
    }

    func path(through points: [CGPoint], closed: Bool = false) -> CGPath {
        let path = CGMutablePath()
        guard let first = points.first else { return path }
        path.move(to: point(first))
        for p in points.dropFirst() { path.addLine(to: point(p)) }
        if closed { path.closeSubpath() }
        return path
    }

    /// Catmull-Rom smoothing, used for the ramp rails so they do not look like
    /// a chain of straight segments.
    func smoothPath(through points: [CGPoint]) -> CGPath {
        guard points.count > 2 else { return path(through: points) }
        let scenePoints = points.map(point)
        let path = CGMutablePath()
        path.move(to: scenePoints[0])
        for i in 0..<(scenePoints.count - 1) {
            let p0 = scenePoints[max(i - 1, 0)]
            let p1 = scenePoints[i]
            let p2 = scenePoints[i + 1]
            let p3 = scenePoints[min(i + 2, scenePoints.count - 1)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        return path
    }

    /// The same curve as `smoothPath`, sampled into points so a ramp can be
    /// built as a real surface with two edges instead of one thick stroke.
    func smoothPoints(through points: [CGPoint], samplesPerSegment: Int = 14) -> [CGPoint] {
        guard points.count > 2, let last = points.last else { return points.map(point) }
        let scenePoints = points.map(point)
        var result: [CGPoint] = []

        for i in 0..<(scenePoints.count - 1) {
            let p0 = scenePoints[max(i - 1, 0)]
            let p1 = scenePoints[i]
            let p2 = scenePoints[i + 1]
            let p3 = scenePoints[min(i + 2, scenePoints.count - 1)]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)

            for step in 0..<samplesPerSegment {
                let t = CGFloat(step) / CGFloat(samplesPerSegment)
                let u = 1 - t
                let x = u*u*u * p1.x + 3*u*u*t * c1.x + 3*u*t*t * c2.x + t*t*t * p2.x
                let y = u*u*u * p1.y + 3*u*u*t * c1.y + 3*u*t*t * c2.y + t*t*t * p2.y
                result.append(CGPoint(x: x, y: y))
            }
        }
        result.append(point(last))
        return result
    }
}

extension CGVector {
    var magnitude: CGFloat { (dx * dx + dy * dy).squareRoot() }

    func normalized() -> CGVector {
        let m = magnitude
        guard m > 0 else { return CGVector(dx: 0, dy: 1) }
        return CGVector(dx: dx / m, dy: dy / m)
    }

    static func * (lhs: CGVector, rhs: CGFloat) -> CGVector {
        CGVector(dx: lhs.dx * rhs, dy: lhs.dy * rhs)
    }

    init(angle: CGFloat, magnitude: CGFloat) {
        self.init(dx: cos(angle) * magnitude, dy: sin(angle) * magnitude)
    }
}

extension CGPoint {
    func distance(to other: CGPoint) -> CGFloat {
        ((x - other.x) * (x - other.x) + (y - other.y) * (y - other.y)).squareRoot()
    }
}
