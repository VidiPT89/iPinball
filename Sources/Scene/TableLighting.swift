import CoreImage
import SpriteKit

/// Where the light layers sit in the stack, and which way the shadows fall.
enum TableDepth {
    /// Above the printed playfield and its art, below everything that stands
    /// on it. Raised parts cast their shadow on to the wood, not on each other.
    static let staticShadows: CGFloat = 7
    /// The ball's and the flippers' shadows. Above the inserts and lane
    /// lamps, which are set flush into the wood, so a ball rolling over a
    /// lamp still darkens it; below every part that stands up from it.
    static let dynamicShadow: CGFloat = 12.5
    /// The glass is the last thing between the player and the table.
    static let glass: CGFloat = 88

    /// How far a part one ball-height tall throws its shadow, in table widths.
    /// The lamps of a cabinet sit above and behind the player's head, so the
    /// shadows fall a little up the table and to the right.
    static let shadowOffset = CGVector(dx: 0.0045, dy: -0.0085)
    /// A ramp is several ball-heights above the playfield.
    static let rampHeight: CGFloat = 3
}

// MARK: - Building the lighting

extension TableBuilder {

    /// The printed, clear-coated playfield, lit from above by the general
    /// illumination: brighter where the bulbs pool, darker into the corners.
    func addPlayfield(to scene: SKScene) -> SKSpriteNode {
        let rect = playfieldRect
        let corner = geometry.length(0.05)

        let wood = SKSpriteNode(texture: playfieldTexture())
        wood.size = rect.size
        wood.anchorPoint = .zero
        wood.position = rect.origin
        wood.zPosition = -10
        scene.addChild(wood)

        let edge = SKShapeNode(rect: rect, cornerRadius: corner)
        edge.fillColor = .clear
        edge.strokeColor = CabinetColors.steel.withAlphaComponent(0.5)
        edge.lineWidth = 3
        edge.zPosition = -9.5
        scene.addChild(edge)
        return wood
    }

    /// Also used to repaint the playfield when the theme changes.
    func playfieldTexture() -> SKTexture {
        // Bulbs under the plastics: the inlanes, the slingshots, the top lanes.
        let pools = [CGPoint(x: 0.16, y: 0.42), CGPoint(x: 0.84, y: 0.42),
                     CGPoint(x: 0.30, y: 0.30), CGPoint(x: 0.70, y: 0.30),
                     CGPoint(x: 0.50, y: 1.05), CGPoint(x: 0.50, y: 1.40)]
            .map { CGPoint(x: $0.x / TableLayout.width, y: $0.y / TableLayout.height) }
        return TextureFactory.playfield(
            size: playfieldRect.size, cornerRadius: geometry.length(0.05),
            base: palette.tableFelt, warm: palette.accentLight, pools: pools)
    }

    private var playfieldRect: CGRect {
        CGRect(x: geometry.origin.x, y: geometry.origin.y,
               width: geometry.length(TableLayout.width),
               height: geometry.length(TableLayout.height))
    }

    /// One soft shadow layer for everything that does not move: wireforms,
    /// posts, bumpers, slingshots, standups and the ramps above them. Blurred
    /// once and kept as a bitmap, so it costs nothing per frame.
    func addShadows(to scene: SKScene, ramps: [RampNode]) {
        let layer = SKEffectNode()
        layer.shouldRasterize = true
        layer.shouldEnableEffects = true
        layer.filter = CIFilter(name: "CIGaussianBlur",
                                parameters: [kCIInputRadiusKey: geometry.length(0.0055)])
        layer.alpha = 0.8
        layer.zPosition = TableDepth.staticShadows

        let offset = CGPoint(x: geometry.length(TableDepth.shadowOffset.dx),
                             y: geometry.length(TableDepth.shadowOffset.dy))

        func cast(_ path: CGPath, fill: Bool, lineWidth: CGFloat = 0, height: CGFloat = 1) {
            let node = SKShapeNode(path: path)
            node.fillColor = fill ? .black : .clear
            node.strokeColor = lineWidth > 0 ? .black : .clear
            node.lineWidth = lineWidth
            node.lineCap = .round
            node.lineJoin = .round
            node.position = CGPoint(x: offset.x * height, y: offset.y * height)
            layer.addChild(node)
        }

        let walls = CGMutablePath()
        for wall in TableLayout.walls { walls.addPath(geometry.path(through: wall.points)) }
        cast(walls, fill: false, lineWidth: geometry.length(TableLayout.wallThickness * 1.2))

        for post in TableLayout.posts {
            cast(circle(at: post.center, radius: post.radius * 1.2), fill: true)
        }
        for bumper in TableLayout.bumpers {
            cast(circle(at: bumper.center, radius: bumper.radius * 1.35), fill: true, height: 1.6)
        }
        for sling in TableLayout.slingshots {
            cast(geometry.path(through: sling.vertices, closed: true), fill: true)
        }
        for target in TableLayout.standupTargets {
            let size = geometry.size(target.size)
            var turn = CGAffineTransform(translationX: geometry.point(target.center).x,
                                         y: geometry.point(target.center).y)
                .rotated(by: target.angle)
            cast(CGPath(rect: CGRect(x: -size.width / 2, y: -size.height / 2,
                                     width: size.width, height: size.height),
                        transform: &turn), fill: true)
        }
        for ramp in ramps {
            guard let deck = ramp.deckPath else { continue }
            cast(deck, fill: true, height: TableDepth.rampHeight)
        }

        scene.addChild(layer)
    }

    /// The playfield glass: a faint sheen from the cabinet lights, the thing
    /// that makes the table look like something under glass rather than a
    /// drawing of one.
    func addGlass(to scene: SKScene) {
        let size = geometry.size(CGSize(width: TableLayout.width, height: TableLayout.height))
        let glass = SKSpriteNode(texture: TextureFactory.glassGlare(size: size))
        glass.size = size
        glass.anchorPoint = .zero
        glass.position = geometry.origin
        glass.blendMode = .screen
        glass.zPosition = TableDepth.glass
        scene.addChild(glass)
    }

    private func circle(at centre: CGPoint, radius: CGFloat) -> CGPath {
        let c = geometry.point(centre)
        let r = geometry.length(radius)
        return CGPath(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2),
                      transform: nil)
    }
}
