import SwiftUI

@main
struct iPinballApp: App {

    @State private var settings = AppSettings()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .preferredColorScheme(settings.colorScheme)
        }
        #if os(macOS)
        .defaultSize(width: 560, height: 940)
        .windowResizability(.contentMinSize)
        .commands {
            // The cabinet is the whole point, so nothing here should let the
            // player open a second one or tile it away.
            CommandGroup(replacing: .newItem) {}
        }
        #endif
    }
}

/// Where the player is. Deliberately a small, flat set: a pinball machine has
/// one screen and a few panels, not a navigation stack.
enum Screen: Equatable {
    case splash
    case menu
    case game
}

enum Panel: String, Identifiable {
    case settings, highScores, howToPlay, about
    var id: String { rawValue }
}

struct RootView: View {

    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var systemScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    @State private var screen: Screen = .splash
    @State private var panel: Panel?
    @State private var audio = AudioEngine()
    @State private var haptics = HapticsEngine()

    private var palette: Palette {
        Palette.resolve(settings.colorScheme ?? systemScheme)
    }

    var body: some View {
        ZStack {
            palette.backgroundColor.ignoresSafeArea()
            palette.backdropGradient.ignoresSafeArea()

            switch screen {
            case .splash:
                SplashView { advance(to: .menu) }
                    .transition(.opacity)

            case .menu:
                MenuView(
                    onPlay: { advance(to: .game) },
                    onOpen: { panel = $0 })
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))

            case .game:
                GameView(audio: audio, haptics: haptics,
                         onQuit: { advance(to: .menu) })
                    .transition(.opacity)
            }
        }
        .environment(\.palette, palette)
        .tint(palette.accentColor)
        .sheet(item: $panel) { panel in
            panelView(for: panel)
                .environment(settings)
                .environment(\.palette, self.palette)
                .tint(self.palette.accentColor)
                .preferredColorScheme(settings.colorScheme)
        }
        .onAppear {
            audio.isSoundEnabled = settings.soundEnabled
            audio.isMusicEnabled = settings.musicEnabled
            haptics.isEnabled = settings.hapticsEnabled
            audio.start()
            haptics.start()
        }
        .onChange(of: settings.soundEnabled) { _, new in audio.isSoundEnabled = new }
        .onChange(of: settings.musicEnabled) { _, new in audio.setMusic(enabled: new) }
        .onChange(of: settings.hapticsEnabled) { _, new in haptics.isEnabled = new }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                audio.start()
                haptics.start()
            default:
                // Hand the audio session and the haptic engine back while the
                // game is not on screen, instead of holding them open.
                audio.stop()
                haptics.stop()
            }
        }
    }

    @ViewBuilder
    private func panelView(for panel: Panel) -> some View {
        switch panel {
        case .settings:   SettingsView()
        case .highScores: HighScoresView()
        case .howToPlay:  HowToPlayView()
        case .about:      AboutView()
        }
    }

    private func advance(to next: Screen) {
        let animation = Motion.respectingReduceMotion(Motion.standard,
                                                      reduceMotion: reduceMotion)
        withAnimation(animation) { screen = next }
    }
}
