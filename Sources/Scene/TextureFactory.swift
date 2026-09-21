import SpriteKit

/// Generates the few raster textures the table needs at runtime, so the app
/// ships with no image assets and the palette can change with the theme.
///
/// Everything is drawn into a plain y-up bitmap through `TextureCanvas`, which
/// keeps the drawing identical on iOS and macOS.
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

    static func steelBall(diameter: CGFloat) -> SKTexture {
        cached("ball-\(Int(diameter))") {
            let size = CGSize(width: diameter, height: diameter)
            return TextureCanvas.texture(size: size) { cg in
                cg.addEllipse(in: CGRect(origin: .zero, size: size))
                cg.clip()

                guard let gradient = TextureCanvas.gradient(
                    [.hex(0xFFFFFF), .hex(0xC9CEDA), .hex(0x6D7488), .hex(0x2A2E3A)],
                    locations: [0, 0.28, 0.72, 1])
                else { return }

                // Light source up and to the left, so every ball on the table
                // agrees about where the lamp is.
                cg.drawRadialGradient(
                    gradient,
                    startCenter: CGPoint(x: diameter * 0.34, y: diameter * 0.70),
                    startRadius: 0,
                    endCenter: CGPoint(x: diameter * 0.5, y: diameter * 0.45),
                    endRadius: diameter * 0.72,
                    options: [.drawsAfterEndLocation])

                cg.setFillColor(PlatformColor.white.withAlphaComponent(0.85).cgColor)
                cg.fillEllipse(in: CGRect(x: diameter * 0.26, y: diameter * 0.62,
                                          width: diameter * 0.18, height: diameter * 0.14))
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

    // MARK: Bumper cap

    static func bumperCap(diameter: CGFloat, color: PlatformColor) -> SKTexture {
        cached("bumper-\(Int(diameter))-\(color.cacheKey)") {
            let size = CGSize(width: diameter, height: diameter)
            let rect = CGRect(origin: .zero, size: size)
            return TextureCanvas.texture(size: size) { cg in
                cg.addEllipse(in: rect)
                cg.clip()

                guard let gradient = TextureCanvas.gradient(
                    [color.blended(with: .white, amount: 0.55),
                     color,
                     color.blended(with: .black, amount: 0.55)],
                    locations: [0, 0.55, 1])
                else { return }

                cg.drawRadialGradient(
                    gradient,
                    startCenter: CGPoint(x: diameter * 0.36, y: diameter * 0.70),
                    startRadius: 0,
                    endCenter: CGPoint(x: diameter * 0.5, y: diameter * 0.5),
                    endRadius: diameter * 0.62,
                    options: [.drawsAfterEndLocation])

                cg.setStrokeColor(PlatformColor.white.withAlphaComponent(0.35).cgColor)
                cg.setLineWidth(diameter * 0.05)
                cg.strokeEllipse(in: rect.insetBy(dx: diameter * 0.16, dy: diameter * 0.16))
            }
        }
    }

    // MARK: Soft shadow used under raised parts

    static func softShadow(diameter: CGFloat) -> SKTexture {
        radialGlow(diameter: diameter, color: .black)
    }
}
