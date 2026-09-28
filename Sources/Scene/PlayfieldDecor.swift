import SpriteKit

/// The fixed colours of the cabinet hardware. Chrome, rubber and plastic do not
/// change with the app theme, any more than they would on a real machine.
enum CabinetColors {
    static let steel: PlatformColor = .hex(0xAEB4C0)
    static let steelHighlight: PlatformColor = .hex(0xF4F6FA)
    static let rubber: PlatformColor = .hex(0xF2EEE6)
    static let flipperBody: PlatformColor = .hex(0xF4F1EA)
    static let apron: PlatformColor = .hex(0x15151F)
    static let cabinet: PlatformColor = .hex(0x07070B)
    static let insertRed: PlatformColor = .hex(0xE8412C)
    static let insertGreen: PlatformColor = .hex(0x2FD36B)
}

// MARK: - Insert lamp

/// A coloured plastic insert set into the playfield with a bulb underneath.
/// Dark when off, bright and haloed when on, and flashing when the machine
/// wants the player to shoot at it — the language every 90s table spoke.
final class InsertLamp: SKNode {

    enum State { case off, on, blinking }

    private let lens: SKShapeNode
    private let halo: SKSpriteNode
    private let label: SKLabelNode?
    private let colour: PlatformColor
    private(set) var state: State = .off

    init(path: CGPath, colour: PlatformColor, text: String? = nil, fontSize: CGFloat = 0) {
        self.colour = colour
        lens = SKShapeNode(path: path)
        let box = path.boundingBoxOfPath
        let diameter = max(box.width, box.height) * 2.2
        halo = SKSpriteNode(texture: TextureFactory.radialGlow(diameter: diameter, color: colour))
        halo.size = CGSize(width: diameter, height: diameter)
        halo.blendMode = .add
        halo.zPosition = -1

        if let text {
            let node = SKLabelNode(text: text)
            node.fontName = "AvenirNextCondensed-Heavy"
            node.fontSize = fontSize
            node.verticalAlignmentMode = .center
            node.horizontalAlignmentMode = .center
            node.zPosition = 1
            label = node
        } else {
            label = nil
        }

        super.init()
        zPosition = 11
        lens.lineWidth = 1
        addChild(halo)
        addChild(lens)
        if let label { addChild(label) }
        paint(lit: false)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    func set(_ newState: State) {
        guard newState != state else { return }
        state = newState
        removeAction(forKey: "blink")
        switch newState {
        case .off:
            paint(lit: false)
        case .on:
            paint(lit: true)
        case .blinking:
            run(.repeatForever(.sequence([
                .run { [weak self] in self?.paint(lit: true) },
                .wait(forDuration: 0.16),
                .run { [weak self] in self?.paint(lit: false) },
                .wait(forDuration: 0.16),
            ])), withKey: "blink")
        }
    }

    private func paint(lit: Bool) {
        lens.fillColor = lit ? colour : colour.blended(with: .black, amount: 0.72)
        lens.strokeColor = colour.withAlphaComponent(lit ? 0.9 : 0.35)
        halo.alpha = lit ? 0.55 : 0
        label?.fontColor = lit ? .hex(0x14100A) : colour.withAlphaComponent(0.55)
    }

    // MARK: Shapes

    /// An arrow pointing along +y, the way inserts point at a shot.
    static func arrowPath(length: CGFloat, width: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: length / 2))
        path.addLine(to: CGPoint(x: width / 2, y: 0))
        path.addLine(to: CGPoint(x: width * 0.22, y: 0))
        path.addLine(to: CGPoint(x: width * 0.22, y: -length / 2))
        path.addLine(to: CGPoint(x: -width * 0.22, y: -length / 2))
        path.addLine(to: CGPoint(x: -width * 0.22, y: 0))
        path.addLine(to: CGPoint(x: -width / 2, y: 0))
        path.closeSubpath()
        return path
    }

    /// A five-pointed star, the insert every table saves for its wizard mode.
    static func starPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        for point in 0..<10 {
            let r = point.isMultiple(of: 2) ? radius : radius * 0.45
            let angle = CGFloat.pi / 2 + CGFloat(point) * .pi / 5
            let vertex = CGPoint(x: cos(angle) * r, y: sin(angle) * r)
            if point == 0 { path.move(to: vertex) } else { path.addLine(to: vertex) }
        }
        path.closeSubpath()
        return path
    }

    static func pillPath(width: CGFloat, height: CGFloat) -> CGPath {
        CGPath(roundedRect: CGRect(x: -width / 2, y: -height / 2, width: width, height: height),
               cornerWidth: height / 2, cornerHeight: height / 2, transform: nil)
    }
}

/// Every insert on the table, so the scene can drive them from the rules.
struct InsertBank {
    var rampArrows: [TableSide: InsertLamp] = [:]
    var orbitArrows: [TableSide: InsertLamp] = [:]
    /// 2×, 3×, 4× and 5×, in that order.
    var multipliers: [InsertLamp] = []
    var shootAgain: InsertLamp?
    var jackpot: InsertLamp?
    /// The mission ladder under the arch, keyed by mission id.
    var missions: [String: InsertLamp] = [:]

    var all: [InsertLamp] {
        Array(rampArrows.values) + Array(orbitArrows.values) + multipliers
            + [shootAgain, jackpot].compactMap { $0 } + Array(missions.values)
    }
}

// MARK: - Building the decor

extension TableBuilder {

    /// Sunburst art behind the bumper nest and the aprons that cover the dead
    /// space either side of the flippers. None of it has a physics body.
    func addArtwork(to scene: SKScene) {
        let centre = geometry.point(CGPoint(x: 0.5, y: 1.02))
        let radius = geometry.length(0.48)
        let rays = CGMutablePath()
        let count = 18
        for index in stride(from: 0, to: count, by: 2) {
            let a0 = CGFloat(index) / CGFloat(count) * 2 * .pi
            let a1 = CGFloat(index + 1) / CGFloat(count) * 2 * .pi
            rays.move(to: centre)
            rays.addLine(to: CGPoint(x: centre.x + cos(a0) * radius, y: centre.y + sin(a0) * radius))
            rays.addLine(to: CGPoint(x: centre.x + cos(a1) * radius, y: centre.y + sin(a1) * radius))
            rays.closeSubpath()
        }
        let sunburst = SKShapeNode(path: rays)
        sunburst.fillColor = palette.accent.withAlphaComponent(0.06)
        sunburst.strokeColor = .clear
        sunburst.zPosition = -8
        scene.addChild(sunburst)

        for side in [TableSide.left, .right] {
            addApron(side: side, to: scene)
        }
    }

    private func addApron(side: TableSide, to scene: SKScene) {
        let mirror: (CGPoint) -> CGPoint = { p in
            side == .left ? p : CGPoint(x: 1 - p.x, y: p.y)
        }
        let outline = [CGPoint(x: 0.082, y: 0.30), CGPoint(x: 0.215, y: 0.232),
                       CGPoint(x: 0.300, y: 0.200), CGPoint(x: 0.300, y: 0.0),
                       CGPoint(x: 0.082, y: 0.0)].map(mirror)
        let apron = SKShapeNode(path: geometry.path(through: outline, closed: true))
        apron.fillColor = CabinetColors.apron
        apron.strokeColor = CabinetColors.steel.withAlphaComponent(0.55)
        apron.lineWidth = 1.5
        apron.zPosition = 9
        scene.addChild(apron)

        let text = SKLabelNode(text: side == .left ? "iPINBALL" : "iVIDI.DEV")
        text.fontName = "AvenirNextCondensed-HeavyItalic"
        text.fontSize = geometry.length(0.030)
        text.fontColor = palette.accent.withAlphaComponent(0.8)
        text.verticalAlignmentMode = .center
        text.position = geometry.point(mirror(CGPoint(x: 0.185, y: 0.10)))
        text.zRotation = side == .left ? 0.35 : -0.35
        text.zPosition = 10
        scene.addChild(text)
    }

    func addInserts(to scene: SKScene) -> InsertBank {
        var bank = InsertBank()
        let arrow = InsertLamp.arrowPath(length: geometry.length(0.055),
                                         width: geometry.length(0.036))

        func place(_ lamp: InsertLamp, at point: CGPoint, pointingAt target: CGPoint? = nil) {
            lamp.position = geometry.point(point)
            if let target {
                lamp.zRotation = atan2(target.y - point.y, target.x - point.x) - .pi / 2
            }
            scene.addChild(lamp)
        }

        for ramp in TableLayout.ramps {
            guard let mouth = ramp.path.first else { continue }
            let lamp = InsertLamp(path: arrow, colour: palette.accentLight)
            let sign: CGFloat = ramp.side == .left ? 1 : -1
            place(lamp, at: CGPoint(x: mouth.x + sign * 0.030, y: mouth.y - 0.060),
                  pointingAt: mouth)
            bank.rampArrows[ramp.side] = lamp
        }

        for gate in TableLayout.orbitGates {
            let lamp = InsertLamp(path: arrow, colour: CabinetColors.insertGreen)
            place(lamp, at: CGPoint(x: gate.center.x, y: 0.895),
                  pointingAt: CGPoint(x: gate.center.x, y: 1))
            bank.orbitArrows[gate.side] = lamp
        }

        let dot = CGPath(ellipseIn: CGRect(x: -geometry.length(0.024), y: -geometry.length(0.024),
                                           width: geometry.length(0.048),
                                           height: geometry.length(0.048)),
                         transform: nil)
        bank.multipliers = (2...5).map { value in
            let lamp = InsertLamp(path: dot, colour: palette.accent, text: "\(value)X",
                                  fontSize: geometry.length(0.024))
            place(lamp, at: CGPoint(x: 0.5 + (CGFloat(value) - 3.5) * 0.058, y: 0.47))
            return lamp
        }

        let shootAgain = InsertLamp(
            path: InsertLamp.pillPath(width: geometry.length(0.17), height: geometry.length(0.036)),
            colour: CabinetColors.insertRed, text: "SHOOT AGAIN",
            fontSize: geometry.length(0.022))
        place(shootAgain, at: CGPoint(x: 0.5, y: 0.075))
        bank.shootAgain = shootAgain

        let jackpot = InsertLamp(
            path: InsertLamp.pillPath(width: geometry.length(0.13), height: geometry.length(0.030)),
            colour: CabinetColors.insertRed, text: "JACKPOT",
            fontSize: geometry.length(0.020))
        place(jackpot, at: CGPoint(x: 0.5, y: 0.855))
        bank.jackpot = jackpot

        bank.missions = addMissionLadder(to: scene)
        return bank
    }

    /// The six missions on an arc under the top arch, in the order they are
    /// played, with the Final Shot star in the middle of the arc. The names
    /// are printed on the playfield in English, like the rest of its art.
    private func addMissionLadder(to scene: SKScene) -> [String: InsertLamp] {
        let names = ["warmUp": "WARM-UP", "rampRush": "RAMPS", "targetFrenzy": "TARGETS",
                     "orbitLoop": "ORBITS", "lock3": "LOCK", "jackpotHunt": "JACKPOTS",
                     "finalShot": "FINAL SHOT"]
        let centre = CGPoint(x: 0.5, y: 1.30)
        let radius: CGFloat = 0.37
        let missions = MissionEngine.catalog.filter { !$0.isWizard }
        let first: CGFloat = 155 * .pi / 180
        let last: CGFloat = 25 * .pi / 180
        let lens = CGPath(ellipseIn: CGRect(x: -geometry.length(0.022), y: -geometry.length(0.022),
                                            width: geometry.length(0.044),
                                            height: geometry.length(0.044)),
                          transform: nil)
        var lamps: [String: InsertLamp] = [:]

        func caption(_ text: String, at point: CGPoint, size: CGFloat) {
            let label = SKLabelNode(text: text)
            label.fontName = "AvenirNextCondensed-DemiBold"
            label.fontSize = geometry.length(size)
            label.fontColor = CabinetColors.steel.withAlphaComponent(0.7)
            label.verticalAlignmentMode = .center
            label.position = geometry.point(point)
            label.zPosition = 10
            scene.addChild(label)
        }

        for (offset, mission) in missions.enumerated() {
            let angle = first + (last - first) * CGFloat(offset) / CGFloat(missions.count - 1)
            let point = CGPoint(x: centre.x + cos(angle) * radius,
                                y: centre.y + sin(angle) * radius)
            let lamp = InsertLamp(path: lens, colour: palette.accent, text: "\(offset + 1)",
                                  fontSize: geometry.length(0.024))
            lamp.position = geometry.point(point)
            scene.addChild(lamp)
            lamps[mission.id] = lamp
            caption(names[mission.id] ?? "", at: CGPoint(x: point.x, y: point.y - 0.040),
                    size: 0.017)
        }

        if let wizard = MissionEngine.catalog.first(where: \.isWizard) {
            let point = CGPoint(x: centre.x, y: centre.y + radius - 0.100)
            let star = InsertLamp(path: InsertLamp.starPath(radius: geometry.length(0.040)),
                                  colour: palette.accentLight)
            star.position = geometry.point(point)
            scene.addChild(star)
            lamps[wizard.id] = star
            caption(names[wizard.id] ?? "", at: CGPoint(x: point.x, y: point.y - 0.058),
                    size: 0.019)
        }
        return lamps
    }

    /// A black sheet over the table that stands in for the general
    /// illumination. A tilt switches the GI off, as it does on a real machine.
    func addGeneralIllumination(to scene: SKScene) -> SKSpriteNode {
        let size = geometry.size(CGSize(width: TableLayout.width, height: TableLayout.height))
        let sheet = SKSpriteNode(color: .black, size: size)
        sheet.anchorPoint = .zero
        sheet.position = geometry.origin
        sheet.alpha = 0
        sheet.zPosition = 50
        scene.addChild(sheet)
        return sheet
    }
}
