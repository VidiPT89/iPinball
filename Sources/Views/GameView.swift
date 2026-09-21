import SpriteKit
import SwiftUI

struct GameView: View {

    let audio: AudioEngine
    let haptics: HapticsEngine
    let onQuit: () -> Void

    @Environment(AppSettings.self) private var settings
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var model = GameModel()
    @State private var scene = PinballScene()
    @State private var isConfigured = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // The table and its controls take the keyboard. The screens
                // that sit on top of it are deliberately outside this layer:
                // the modifier makes its subtree focusable and reports the
                // flipper letters as handled, so a text field inside it —
                // the initials box — could never receive a keystroke.
                ZStack {
                    palette.feltColor.ignoresSafeArea()

                    SpriteView(scene: prepared(for: proxy.size),
                               preferredFramesPerSecond: 60,
                               options: [.ignoresSiblingOrder])
                        .ignoresSafeArea()
                        .accessibilityHidden(true)

                    ControlOverlay(model: model, scene: scene)

                    VStack(spacing: 0) {
                        HUDView(model: model, onPause: pause)
                        Spacer()
                        if model.showLaunchHint && !model.isGameOver {
                            LaunchHint()
                                .padding(.bottom, 28)
                                .transition(.opacity)
                        }
                    }

                    BannerLayer(banner: model.banner)
                        .allowsHitTesting(false)
                }
                .gameKeyboardControls(scene: scene, model: model,
                                      pause: pause, resume: resume)

                if model.isPaused {
                    PauseOverlay(onResume: resume, onRestart: restart, onQuit: quit)
                        .transition(.opacity)
                }

                if model.isGameOver {
                    GameOverView(model: model, onPlayAgain: restart, onMenu: quit)
                        .transition(.opacity)
                }
            }
        }
        .onChange(of: palette.accent) { _, _ in scene.repaint(with: palette) }
        .onChange(of: reduceMotion) { _, new in scene.reduceMotion = new }
        .onChange(of: model.isGameOver) { _, isOver in
            guard isOver else { return }
            model.highScoreRank = settings.rank(for: model.finalScore)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active, !model.isGameOver { pause() }
        }
        .onDisappear { scene.setPaused(true) }
    }

    // MARK: - Scene wiring

    /// Configures the scene the first time a real size is known, and hands the
    /// same instance back on every later layout pass.
    private func prepared(for size: CGSize) -> PinballScene {
        guard !isConfigured, size.width > 0, size.height > 0 else { return scene }

        scene.size = size
        scene.scaleMode = .resizeFill
        scene.model = model
        scene.audio = audio
        scene.haptics = haptics
        scene.palette = palette
        scene.reduceMotion = reduceMotion
        scene.autoPlunge = settings.autoPlunge
        scene.ballCount = settings.ballCount

        DispatchQueue.main.async {
            isConfigured = true
            scene.startGame()
        }
        return scene
    }

    // MARK: - Commands

    private func pause() {
        guard !model.isGameOver, !model.isPaused else { return }
        withAnimation(Motion.standard) { model.isPaused = true }
        scene.setPaused(true)
        audio.play(.uiTap)
    }

    private func resume() {
        withAnimation(Motion.standard) { model.isPaused = false }
        scene.setPaused(false)
    }

    private func restart() {
        withAnimation(Motion.standard) {
            model.isPaused = false
            model.isGameOver = false
        }
        scene.ballCount = settings.ballCount
        scene.autoPlunge = settings.autoPlunge
        scene.setPaused(false)
        scene.startGame()
    }

    private func quit() {
        scene.setPaused(true)
        onQuit()
    }
}

// MARK: - Launch hint

private struct LaunchHint: View {

    @Environment(AppSettings.self) private var settings
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var bounce = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: PlatformTraits.usesTouchControls
                  ? "hand.draw.fill" : "space")
                .font(.system(size: 13, weight: .bold))
            Text(settings.t(PlatformTraits.usesTouchControls
                            ? "hud.launch" : "hud.launchKeyboard"))
                .font(Typography.label(13))
        }
        // Over the playfield, which stays dark in both themes, so this reads
        // off the dark palette rather than the one the chrome is using.
        .foregroundStyle(Color(platform: Palette.dark.textPrimary))
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(Capsule().fill(Color(platform: Palette.dark.surface).opacity(0.92)))
        .overlay(Capsule().strokeBorder(
            Color(platform: Palette.dark.accent).opacity(0.45), lineWidth: 1))
        .offset(y: bounce && !reduceMotion ? 5 : -5)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                bounce = true
            }
        }
    }
}

// MARK: - Banner

/// The big word that sweeps across on a jackpot or a tilt.
private struct BannerLayer: View {

    let banner: GameModel.Banner?

    @Environment(AppSettings.self) private var settings
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var shown: GameModel.Banner?
    @State private var visible = false

    var body: some View {
        ZStack {
            if let shown, visible {
                Text(settings.t(shown.key))
                    .font(Typography.display(38))
                    .kerning(2)
                    .foregroundStyle(color(for: shown.style))
                    .shadow(color: color(for: shown.style).opacity(0.7), radius: 22)
                    .padding(.horizontal, 26)
                    .padding(.vertical, 14)
                    // A solid dark capsule, not a material: the banner lands on
                    // top of lit bumpers, and a translucent one in light mode
                    // turned TILT into dark red on a warm blur.
                    .background(
                        Capsule()
                            .fill(Color(platform: Palette.dark.background).opacity(0.94))
                            .overlay(Capsule().strokeBorder(
                                color(for: shown.style).opacity(0.55), lineWidth: 1.5))
                    )
                    .scaleEffect(reduceMotion ? 1 : 1.0)
                    .transition(reduceMotion
                                ? .opacity
                                : .scale(scale: 0.7).combined(with: .opacity))
                    .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .onChange(of: banner) { _, new in
            guard let new else { return }
            shown = new
            withAnimation(reduceMotion ? nil : Motion.snappy) { visible = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + Motion.bannerSweep) {
                guard shown?.id == new.id else { return }
                withAnimation(reduceMotion ? nil : Motion.standard) { visible = false }
            }
        }
    }

    /// Always the dark palette, for the same reason as the capsule behind it.
    private func color(for style: GameModel.Banner.Style) -> Color {
        switch style {
        case .neutral: return Color(platform: Palette.dark.textPrimary)
        case .good:    return Color(platform: Palette.dark.success)
        case .great:   return Color(platform: Palette.dark.accentLight)
        case .bad:     return Color(platform: Palette.dark.danger)
        }
    }
}
