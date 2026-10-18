import SpriteKit

/// Generates the few raster textures the table needs at runtime, so the app
/// ships with no image assets and the palette can change with the theme.
///
/// Everything is drawn into a plain y-up bitmap through `TextureCanvas`, which
/// keeps the drawing identical on iOS and macOS.
@MainActor
enum TextureFactory {

    private static var cache: [String: SKTexture] = [:]

    static func purge() { cache.removeAll() }

    private static func cached(_ key: String,
                               _ make: () -> SKTexture) -> SKTexture {
        if let hit = cache[key] { return hit }
        let texture = make()
        cache[key] = texture
        return texture
    }

    // MARK: Steel ball

    /// A polished ball is a mirror. Seen from above it shows the bright
    /// backbox and cabinet lamps in its upper half, the dark playfield below a
    /// soft horizon, and one hard highlight where the nearest lamp is.
    static func steelBall(diameter: CGFloat) -> SKTexture {
        cached("ball-\(Int(diameter))") {
            let size = CGSize(width: diameter, height: diameter)
            return TextureCanvas.texture(size: size, scale: 3) { cg in
                let rect = CGRect(origin: .zero, size: size)
                cg.addEllipse(in: rect)
                cg.clip()

                // Sky above, playfield below, meeting at a blurred horizon.
                if let reflection = TextureCanvas.gradient(
                    [.hex(0xF4F6FA), .hex(0xB8BECB), .hex(0x5E6574), .hex(0x262A33), .hex(0x3A3F4B)],
                    locations: [0, 0.38, 0.52, 0.80, 1]) {
                    cg.drawLinearGradient(reflection,
                                          start: CGPoint(x: diameter * 0.5, y: diameter),
                                          end: CGPoint(x: diameter * 0.5, y: 0),
                                          options: [])
                }

                // The rim falls away from the light, which is what makes it round.
                if let rim = TextureCanvas.gradient(
                    [PlatformColor.black.withAlphaComponent(0),
                     PlatformColor.black.withAlphaComponent(0.55)],
                    locations: [0.62, 1]) {
                    let centre = CGPoint(x: diameter * 0.46, y: diameter * 0.56)
                    cg.drawRadialGradient(rim, startCenter: centre, startRadius: 0,
                                          endCenter: centre, endRadius: diameter * 0.56,
                                          options: [.drawsAfterEndLocation])
                }

                // The playfield's warm light bounced back into the lower edge.
                if let bounce = TextureCanvas.gradient(
                    [PlatformColor.hex(0xFFB25A).withAlphaComponent(0.16),
                     PlatformColor.hex(0xFFB25A).withAlphaComponent(0)],
                    locations: [0, 1]) {
                    let low = CGPoint(x: diameter * 0.52, y: diameter * 0.04)
                    cg.drawRadialGradient(bounce, startCenter: low, startRadius: 0,
                                          endCenter: low, endRadius: diameter * 0.32,
                                          options: [])
                }

                // The lamp: a hard highlight with a softer bloom round it.
                if let bloom = TextureCanvas.gradient(
                    [PlatformColor.white.withAlphaComponent(0.9),
                     PlatformColor.white.withAlphaComponent(0)],
                    locations: [0, 1]) {
                    let lamp = CGPoint(x: diameter * 0.35, y: diameter * 0.70)
                    cg.drawRadialGradient(bloom, startCenter: lamp, startRadius: 0,
                                          endCenter: lamp, endRadius: diameter * 0.22,
                                          options: [])
                }
                cg.setFillColor(PlatformColor.white.cgColor)
                cg.fillEllipse(in: CGRect(x: diameter * 0.29, y: diameter * 0.66,
                                          width: diameter * 0.12, height: diameter * 0.08))
            }
        }
    }

    /// A soft round shadow, dark in the middle and gone at the edge.
    static func softShadow(diameter: CGFloat) -> SKTexture {
        cached("shadow-\(Int(diameter))") {
            let size = CGSize(width: diameter, height: diameter)
            return TextureCanvas.texture(size: size, scale: 1) { cg in
                guard let gradient = TextureCanvas.gradient(
                    [PlatformColor.black.withAlphaComponent(0.75),
                     PlatformColor.black.withAlphaComponent(0.35),
                     PlatformColor.black.withAlphaComponent(0)],
                    locations: [0, 0.45, 1])
                else { return }
                let centre = CGPoint(x: diameter / 2, y: diameter / 2)
                cg.drawRadialGradient(gradient, startCenter: centre, startRadius: 0,
                                      endCenter: centre, endRadius: diameter / 2, options: [])
            }
        }
    }

    // MARK: Playfield

    /// The printed playfield under its clear coat. `pools` are where the GI
    /// bulbs light it, as fractions of the texture.
    static func playfield(size: CGSize, cornerRadius: CGFloat, base: PlatformColor,
                          warm: PlatformColor, pools: [CGPoint]) -> SKTexture {
        cached("playfield-\(Int(size.width))x\(Int(size.height))-\(base.cacheKey)-\(warm.cacheKey)") {
            TextureCanvas.texture(size: size, scale: 1) { cg in
                let rect = CGRect(origin: .zero, size: size)
                cg.addPath(CGPath(roundedRect: rect, cornerWidth: cornerRadius,
                                  cornerHeight: cornerRadius, transform: nil))
                cg.clip()
                cg.setFillColor(base.cgColor)
                cg.fill(rect)

                let span = max(size.width, size.height)

                // The whole field catches more light in the middle.
                if let lift = TextureCanvas.gradient(
                    [PlatformColor.white.withAlphaComponent(0.06),
                     PlatformColor.white.withAlphaComponent(0)],
                    locations: [0, 1]) {
                    let centre = CGPoint(x: size.width * 0.5, y: size.height * 0.55)
                    cg.drawRadialGradient(lift, startCenter: centre, startRadius: 0,
                                          endCenter: centre, endRadius: span * 0.6, options: [])
                }

                // Warm pools under the GI bulbs.
                if let pool = TextureCanvas.gradient(
                    [warm.withAlphaComponent(0.11), warm.withAlphaComponent(0)],
                    locations: [0, 1]) {
                    for spot in pools {
                        let centre = CGPoint(x: spot.x * size.width, y: spot.y * size.height)
                        cg.drawRadialGradient(pool, startCenter: centre, startRadius: 0,
                                              endCenter: centre, endRadius: size.width * 0.22,
                                              options: [])
                    }
                }

                // The grain of the print and the clear coat over it. Seeded,
                // so the table looks the same every time it is built.
                var random = SeededRandom(seed: 0x1BA11)
                let specks = Int(size.width * size.height / 70)
                for _ in 0..<specks {
                    let light = random.next() & 1 == 0
                    let alpha = 0.015 + CGFloat(random.next() % 1000) / 1000 * 0.035
                    cg.setFillColor((light ? PlatformColor.white : PlatformColor.black)
                        .withAlphaComponent(alpha).cgColor)
                    cg.fill(CGRect(x: CGFloat(random.next() % 100_000) / 100_000 * size.width,
                                   y: CGFloat(random.next() % 100_000) / 100_000 * size.height,
                                   width: 1, height: 1))
                }

                // Into the corners the light runs out.
                if let vignette = TextureCanvas.gradient(
                    [PlatformColor.black.withAlphaComponent(0),
                     PlatformColor.black.withAlphaComponent(0.5)],
                    locations: [0, 1]) {
                    let centre = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                    cg.drawRadialGradient(vignette, startCenter: centre, startRadius: span * 0.32,
                                          endCenter: centre, endRadius: span * 0.62,
                                          options: [.drawsAfterEndLocation])
                }
            }
        }
    }

    // MARK: Glass

    /// Two faint diagonal sheens and the reflection of the backbox along the
    /// top, drawn white on transparent for a screen blend.
    static func glassGlare(size: CGSize) -> SKTexture {
        cached("glass-\(Int(size.width))x\(Int(size.height))") {
            TextureCanvas.texture(size: size, scale: 0.5) { cg in
                let clear = PlatformColor.white.withAlphaComponent(0)
                if let sheen = TextureCanvas.gradient(
                    [clear, clear, .white.withAlphaComponent(0.07), clear,
                     clear, .white.withAlphaComponent(0.035), clear, clear],
                    locations: [0, 0.24, 0.31, 0.38, 0.58, 0.63, 0.69, 1]) {
                    cg.drawLinearGradient(sheen, start: CGPoint(x: 0, y: size.height),
                                          end: CGPoint(x: size.width, y: size.height * 0.35),
                                          options: [])
                }
                if let backbox = TextureCanvas.gradient(
                    [.white.withAlphaComponent(0.05), clear], locations: [0, 1]) {
                    cg.drawLinearGradient(backbox, start: CGPoint(x: 0, y: size.height),
                                          end: CGPoint(x: 0, y: size.height * 0.86),
                                          options: [])
                }
            }
        }
    }

    // MARK: Glow

    static func radialGlow(diameter: CGFloat, color: PlatformColor) -> SKTexture {
        cached("glow-\(Int(diameter))-\(color.cacheKey)") {
            let size = CGSize(width: diameter, height: diameter)
            return TextureCanvas.texture(size: size) { cg in
                guard let gradient = TextureCanvas.gradient(
                    [color.withAlphaComponent(0.85),
                     color.withAlphaComponent(0.30),
                     color.withAlphaComponent(0.0)],
                    locations: [0, 0.45, 1])
                else { return }

                let centre = CGPoint(x: diameter / 2, y: diameter / 2)
                cg.drawRadialGradient(gradient, startCenter: centre, startRadius: 0,
                                      endCenter: centre, endRadius: diameter / 2,
                                      options: [])
            }
        }
    }

    // MARK: Slingshot plastic

    /// The translucent cover over a slingshot: bright where the bulb sits
    /// under it, darker at the edges, with a stripe of moulded texture.
    static func slingshotPlastic(size: CGSize, color: PlatformColor) -> SKTexture {
        cached("sling-\(Int(size.width))x\(Int(size.height))-\(color.cacheKey)") {
            TextureCanvas.texture(size: size, scale: 1) { cg in
                let rect = CGRect(origin: .zero, size: size)
                cg.setFillColor(color.blended(with: .black, amount: 0.55).cgColor)
                cg.fill(rect)
                if let bulb = TextureCanvas.gradient(
                    [color.blended(with: .white, amount: 0.25), color.withAlphaComponent(0)],
                    locations: [0, 1]) {
                    let centre = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
                    cg.drawRadialGradient(bulb, startCenter: centre, startRadius: 0,
                                          endCenter: centre,
                                          endRadius: max(size.width, size.height) * 0.55,
                                          options: [])
                }
                cg.setStrokeColor(PlatformColor.white.withAlphaComponent(0.10).cgColor)
                cg.setLineWidth(max(1, size.width * 0.03))
                var x = -size.height
                while x < size.width {
                    cg.move(to: CGPoint(x: x, y: 0))
                    cg.addLine(to: CGPoint(x: x + size.height, y: size.height))
                    x += size.width * 0.16
                }
                cg.strokePath()
            }
        }
    }

    // MARK: Bumper cap

    /// The cap of a pop bumper seen from above: a translucent plastic dome
    /// lit by the bulb inside it, with a star moulded into the top.
    static func bumperCap(diameter: CGFloat, color: PlatformColor) -> SKTexture {
        cached("bumper-\(Int(diameter))-\(color.cacheKey)") {
            let size = CGSize(width: diameter, height: diameter)
            let rect = CGRect(origin: .zero, size: size)
            return TextureCanvas.texture(size: size) { cg in
                cg.addEllipse(in: rect)
                cg.clip()

                guard let dome = TextureCanvas.gradient(
                    [color.blended(with: .white, amount: 0.65),
                     color.blended(with: .white, amount: 0.15),
                     color,
                     color.blended(with: .black, amount: 0.50)],
                    locations: [0, 0.30, 0.70, 1])
                else { return }
                let bulb = CGPoint(x: diameter * 0.5, y: diameter * 0.5)
                cg.drawRadialGradient(dome, startCenter: bulb, startRadius: 0,
                                      endCenter: bulb, endRadius: diameter * 0.5,
                                      options: [.drawsAfterEndLocation])

                // The moulded star, a shade darker than the plastic round it.
                let star = CGMutablePath()
                for point in 0..<10 {
                    let r = diameter * (point.isMultiple(of: 2) ? 0.26 : 0.11)
                    let angle = CGFloat.pi / 2 + CGFloat(point) * .pi / 5
                    let vertex = CGPoint(x: bulb.x + cos(angle) * r, y: bulb.y + sin(angle) * r)
                    if point == 0 { star.move(to: vertex) } else { star.addLine(to: vertex) }
                }
                star.closeSubpath()
                cg.addPath(star)
                cg.setFillColor(color.blended(with: .black, amount: 0.25)
                    .withAlphaComponent(0.55).cgColor)
                cg.fillPath()

                // The rolled lip of the cap and the lamp's reflection on it.
                cg.setStrokeColor(PlatformColor.white.withAlphaComponent(0.35).cgColor)
                cg.setLineWidth(diameter * 0.045)
                cg.strokeEllipse(in: rect.insetBy(dx: diameter * 0.06, dy: diameter * 0.06))
                cg.setFillColor(PlatformColor.white.withAlphaComponent(0.55).cgColor)
                cg.fillEllipse(in: CGRect(x: diameter * 0.24, y: diameter * 0.66,
                                          width: diameter * 0.20, height: diameter * 0.12))
            }
        }
    }
}

/// A small deterministic generator, so generated textures come out the same
/// on every launch and in every snapshot.
struct SeededRandom {
    private var state: UInt64

    init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9 : seed }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
