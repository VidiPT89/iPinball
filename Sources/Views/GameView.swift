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
                    Color(platform: CabinetColors.cabinet).ignoresSafeArea()

                    SpriteView(scene: prepared(for: proxy.size),
                               preferredFramesPerSecond: 60,
                               options: [.ignoresSiblingOrder])
                        .ignoresSafeArea()
                        .accessibilityHidden(true)

                    ControlOverlay(model: model, scene: scene)

                    VStack(spacing: 0) {
                        HUDView(model: model, onPause: pause)
                        Spacer()
                    }
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
