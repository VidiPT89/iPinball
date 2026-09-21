import SwiftUI

/// The invisible touch zones laid over the playfield.
///
/// While the ball waits in the shooter lane the whole screen is the plunger,
/// because nothing else is worth touching yet. Once the ball is live the
/// screen splits into flipper zones instead.
struct ControlOverlay: View {

    let model: GameModel
    let scene: PinballScene

    @Environment(AppSettings.self) private var settings
    @Environment(\.palette) private var palette

    var body: some View {
        GeometryReader { proxy in
            if !PlatformTraits.usesTouchControls {
                Color.clear
            } else if model.showLaunchHint && !model.isGameOver && !model.isPaused {
                plungerZone(height: proxy.size.height)
            } else if !model.isGameOver && !model.isPaused {
                flipperZones(size: proxy.size)
            }
        }
    }

    // MARK: - Plunger

    private func plungerZone(height: CGFloat) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let pull = max(0, value.translation.height)
                        scene.chargePlunger(
                            to: pull / (height * PhysicsTuning.plungerFullPullRatio))
                    }
                    .onEnded { _ in scene.firePlunger() }
            )
            .accessibilityElement()
            .accessibilityLabel(Text(settings.t("a11y.plunger")))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { scene.firePlunger() }
    }

    // MARK: - Flippers

    private func flipperZones(size: CGSize) -> some View {
        let leftSide: TableSide = settings.leftHanded ? .right : .left
        let rightSide: TableSide = settings.leftHanded ? .left : .right

        return HStack(spacing: 0) {
            VStack(spacing: 0) {
                // The top slice of the left column works the upper flipper,
                // which sits high on the table on that side.
                zone(side: .left, upper: true,
                     label: settings.t("a11y.upperFlipper"))
                    .frame(height: size.height * 0.34)
                zone(side: leftSide, upper: false,
                     label: settings.t("a11y.leftFlipper"))
            }
            zone(side: rightSide, upper: false,
                 label: settings.t("a11y.rightFlipper"))
        }
    }

    private func zone(side: TableSide, upper: Bool, label: String) -> some View {
        FlipperZone(label: label,
                    onPress: { scene.pressFlipper(side: side, upper: upper) },
                    onRelease: { scene.releaseFlipper(side: side, upper: upper) },
                    onNudge: { direction in scene.nudge(direction: direction) })
    }
}

/// One half of the screen. Holding presses the flipper; a short horizontal
/// flick inside the same touch nudges the table instead of pressing again.
private struct FlipperZone: View {

    let label: String
    let onPress: () -> Void
    let onRelease: () -> Void
    let onNudge: (CGFloat) -> Void

    @State private var isDown = false
    @State private var didNudge = false

    private let nudgeThreshold: CGFloat = 46

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDown {
                            isDown = true
                            didNudge = false
                            onPress()
                        }
                        let dx = value.translation.width
                        guard !didNudge, abs(dx) > nudgeThreshold,
                              abs(dx) > abs(value.translation.height)
                        else { return }
                        didNudge = true
                        onNudge(dx > 0 ? 1 : -1)
                    }
                    .onEnded { _ in
                        isDown = false
                        onRelease()
                    }
            )
            .accessibilityElement()
            .accessibilityLabel(Text(label))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction {
                onPress()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12, execute: onRelease)
            }
    }
}

// MARK: - Keyboard

/// Keyboard play, which is the only way to work the table on a Mac and a
/// welcome shortcut on an iPad with a keyboard attached.
///
/// Left / A — left flipper · Right / L — right flipper · Up / W — upper
/// flipper · Space — hold to charge the plunger, release to launch ·
/// N and M — nudge · Esc or P — pause.
struct GameKeyboardControls: ViewModifier {

    let scene: PinballScene
    let model: GameModel
    let pause: () -> Void
    let resume: () -> Void

    @State private var plungerStart: Date?
    @State private var chargeTimer: Timer?
    @FocusState private var hasKeyboardFocus: Bool

    /// The table stops listening once the game is over, so the initials field
    /// on the screen above it gets the keystrokes. The flipper keys include
    /// `a`, `d`, `l`, `w`, `n`, `m` and `p`, each reported as handled, so
    /// initials like "DAM" were impossible to type while the table listened.
    private var releasesKeyboard: Bool { model.isGameOver }

    func body(content: Content) -> some View {
        content
            .focusable(!releasesKeyboard)
            .focusEffectDisabled()
            .focused($hasKeyboardFocus)
            .onKeyPress(phases: [.down, .up]) { press in
                releasesKeyboard ? .ignored : handle(press)
            }
            // Without taking the focus the table never sees a key press, and
            // on the Mac the keyboard is the only way to play.
            .onAppear { hasKeyboardFocus = true }
            .onChange(of: releasesKeyboard) { _, released in
                stopCharging()
                hasKeyboardFocus = !released
            }
            .onDisappear { stopCharging() }
    }

    private func handle(_ press: KeyPress) -> KeyPress.Result {
        let isDown = press.phase == .down

        switch press.key {
        case .leftArrow:
            flipper(.left, upper: false, down: isDown)
        case .rightArrow:
            flipper(.right, upper: false, down: isDown)
        case .upArrow:
            flipper(.left, upper: true, down: isDown)
        case .space:
            isDown ? beginCharging() : endCharging()
        case .escape:
            if isDown { model.isPaused ? resume() : pause() }
        default:
            switch press.characters.lowercased() {
            case "a": flipper(.left, upper: false, down: isDown)
            case "l", "d": flipper(.right, upper: false, down: isDown)
            case "w": flipper(.left, upper: true, down: isDown)
            case "n": if isDown { scene.nudge(direction: -1) }
            case "m": if isDown { scene.nudge(direction: 1) }
            case "p": if isDown { model.isPaused ? resume() : pause() }
            default: return .ignored
            }
        }
        return .handled
    }

    private func flipper(_ side: TableSide, upper: Bool, down: Bool) {
        down ? scene.pressFlipper(side: side, upper: upper)
             : scene.releaseFlipper(side: side, upper: upper)
    }

    // MARK: Plunger

    private func beginCharging() {
        guard plungerStart == nil else { return }
        plungerStart = Date()
        chargeTimer = Timer.scheduledTimer(withTimeInterval: 1 / 30, repeats: true) { _ in
            guard let start = plungerStart else { return }
            // A full second of holding is a full-strength launch.
            scene.chargePlunger(to: CGFloat(Date().timeIntervalSince(start)))
        }
    }

    private func endCharging() {
        guard plungerStart != nil else { return }
        stopCharging()
        scene.firePlunger()
    }

    private func stopCharging() {
        chargeTimer?.invalidate()
        chargeTimer = nil
        plungerStart = nil
    }
}

extension View {
    func gameKeyboardControls(scene: PinballScene, model: GameModel,
                              pause: @escaping () -> Void,
                              resume: @escaping () -> Void) -> some View {
        modifier(GameKeyboardControls(scene: scene, model: model,
                                      pause: pause, resume: resume))
    }
}
