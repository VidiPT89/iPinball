import CoreGraphics

/// How the table's active parts throw the ball.
///
/// A real pop bumper or slingshot adds its kick to the ball's own motion: the
/// way the ball comes in decides the way it goes out, and a solenoid never
/// fires quite the same twice. The first version set one fixed velocity
/// instead, so every ball that touched a slingshot left along the same line
/// and the table played the same few shots over and over.
///
/// Everything here is deterministic; the scene supplies the random `spin` and
/// `variation`, which keeps the maths testable.
enum KickModel {

    /// The ball's velocity after an active kicker fires.
    ///
    /// - Parameters:
    ///   - normal: points away from the kicker, out of the surface that was hit.
    ///   - kickSpeed: what the solenoid adds along the normal.
    ///   - spin: a small turn, in radians, for the play in a real mechanism.
    static func activeKick(incoming: CGVector, normal: CGVector,
                           kickSpeed: CGFloat, spin: CGFloat) -> CGVector {
        let n = normal.normalized()
        let along = incoming.dx * n.dx + incoming.dy * n.dy
        let tangent = CGVector(dx: incoming.dx - n.dx * along,
                               dy: incoming.dy - n.dy * along)
        // Whether the solver has already bounced the ball or not, the part
        // along the normal leaves outwards.
        let outwards = abs(along) * PhysicsTuning.kickRebound + kickSpeed
        let out = CGVector(dx: tangent.dx * PhysicsTuning.kickKeepsTangent + n.dx * outwards,
                           dy: tangent.dy * PhysicsTuning.kickKeepsTangent + n.dy * outwards)
        return out.rotated(by: spin)
    }

    /// A saucer eject, a ramp exit or a plunge: aimed, but never identical.
    /// `variation` runs from -1 to 1 and scales both spreads.
    static func eject(angle: CGFloat, speed: CGFloat, variation: CGFloat,
                      angleSpread: CGFloat, speedSpread: CGFloat) -> CGVector {
        let v = max(-1, min(1, variation))
        return CGVector(angle: angle + angleSpread * v,
                        magnitude: speed * (1 + speedSpread * v))
    }

    /// The unit normal of the segment `a`→`b`, on the side away from `inside`.
    static func faceNormal(from a: CGPoint, to b: CGPoint, awayFrom inside: CGPoint) -> CGVector {
        let normal = CGVector(dx: -(b.y - a.y), dy: b.x - a.x).normalized()
        let toInside = CGVector(dx: inside.x - a.x, dy: inside.y - a.y)
        let facesInside = normal.dx * toInside.dx + normal.dy * toInside.dy > 0
        return facesInside ? normal * -1 : normal
    }

    /// Whether a ball centred at `point` is resting against the face `a`→`b`:
    /// in front of it, within `reach`, and between its two ends.
    static func touchesFace(_ point: CGPoint, from a: CGPoint, to b: CGPoint,
                            normal: CGVector, reach: CGFloat) -> Bool {
        let edge = CGVector(dx: b.x - a.x, dy: b.y - a.y)
        let offset = CGVector(dx: point.x - a.x, dy: point.y - a.y)
        let length2 = edge.dx * edge.dx + edge.dy * edge.dy
        guard length2 > 0 else { return false }
        let t = (offset.dx * edge.dx + offset.dy * edge.dy) / length2
        let distance = offset.dx * normal.dx + offset.dy * normal.dy
        return (0...1).contains(t) && distance > -reach * 0.25 && distance <= reach
    }
}

// MARK: - Vector maths

extension CGVector {
    var magnitude: CGFloat { (dx * dx + dy * dy).squareRoot() }

    func normalized() -> CGVector {
        let m = magnitude
        guard m > 0 else { return CGVector(dx: 0, dy: 1) }
        return CGVector(dx: dx / m, dy: dy / m)
    }

    func rotated(by angle: CGFloat) -> CGVector {
        CGVector(dx: dx * cos(angle) - dy * sin(angle),
                 dy: dx * sin(angle) + dy * cos(angle))
    }

    static func * (lhs: CGVector, rhs: CGFloat) -> CGVector {
        CGVector(dx: lhs.dx * rhs, dy: lhs.dy * rhs)
    }

    init(angle: CGFloat, magnitude: CGFloat) {
        self.init(dx: cos(angle) * magnitude, dy: sin(angle) * magnitude)
    }
}
