import SwiftUI

struct MenuView: View {

    let onPlay: () -> Void
    let onOpen: (Panel) -> Void

    @Environment(AppSettings.self) private var settings
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var appeared = false

    var body: some View {
        @Bindable var settings = settings

        ZStack {
            DriftingBallsBackground()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                Spacer(minLength: 12)

                header

                Spacer(minLength: 20)

                VStack(spacing: 12) {
                    NeonButton(title: settings.t("menu.play"),
                               systemImage: "play.fill",
                               kind: .primary,
                               action: onPlay)

                    HStack(spacing: 12) {
                        NeonButton(title: settings.t("menu.highScores"),
                                   systemImage: "trophy.fill",
                                   kind: .secondary) { onOpen(.highScores) }
                        NeonButton(title: settings.t("menu.howToPlay"),
                                   systemImage: "questionmark.circle.fill",
                                   kind: .secondary) { onOpen(.howToPlay) }
                    }

                    HStack(spacing: 12) {
                        NeonButton(title: settings.t("menu.settings"),
                                   systemImage: "slider.horizontal.3",
                                   kind: .ghost) { onOpen(.settings) }
                        NeonButton(title: settings.t("menu.about"),
                                   systemImage: "info.circle",
                                   kind: .ghost) { onOpen(.about) }
                    }
                }
                .frame(maxWidth: 420)
                .padding(.horizontal, 20)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared || reduceMotion ? 0 : 24)

                Spacer(minLength: 16)

                footer
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            withAnimation(Motion.respectingReduceMotion(.easeOut(duration: 0.5).delay(0.05),
                                                        reduceMotion: reduceMotion)) {
                appeared = true
            }
        }
    }

    // MARK: - Pieces

    private var topBar: some View {
        @Bindable var settings = settings

        return HStack(spacing: 10) {
            // The language switch is a first-class control, not a setting
            // buried two screens deep.
            Button {
                withAnimation(Motion.snappy) { settings.toggleLanguage() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                        .font(.system(size: 12, weight: .bold))
                    Text(settings.language.displayName)
                        .font(Typography.label(14))
                        .contentTransition(.numericText())
                }
                .foregroundStyle(palette.accentColor)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(palette.surfaceRaisedColor)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(palette.accentColor.opacity(0.35), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(settings.t("a11y.languageToggle")))
            .accessibilityValue(Text(settings.language.displayName))

            Spacer()

            ThemeToggle()
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            NeonTitle(text: "iPinball", size: 52)

            Text(settings.t("menu.tagline"))
                .font(Typography.label(13))
                .kerning(2.6)
                .textCase(.uppercase)
                .foregroundStyle(palette.dimColor)

            if settings.bestScore > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("\(settings.t("hud.best")) \(settings.bestScore.grouped)")
                        .font(Typography.mono(13))
                }
                .foregroundStyle(palette.accentLightColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(palette.surfaceColor)
                .clipShape(Capsule())
                .padding(.top, 4)
            }
        }
        .opacity(appeared ? 1 : 0)
        .scaleEffect(appeared || reduceMotion ? 1 : 0.94)
    }

    private var footer: some View {
        Text(settings.t("about.developedBy"))
            .font(Typography.label(12))
            .foregroundStyle(palette.faintColor)
            .opacity(appeared ? 1 : 0)
    }
}

// MARK: - Theme toggle

/// System / light / dark, in that order, as a single compact control.
struct ThemeToggle: View {

    @Environment(AppSettings.self) private var settings
    @Environment(\.palette) private var palette

    var body: some View {
        @Bindable var settings = settings

        HStack(spacing: 2) {
            ForEach(AppTheme.allCases, id: \.self) { theme in
                Button {
                    withAnimation(Motion.snappy) { settings.theme = theme }
                } label: {
                    Image(systemName: icon(for: theme))
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(settings.theme == theme
                                         ? Color(platform: .hex(0x14100A))
                                         : palette.dimColor)
                        .frame(width: 36, height: 30)
                        .background(
                            Capsule().fill(settings.theme == theme
                                           ? AnyShapeStyle(palette.accentGradient)
                                           : AnyShapeStyle(Color.clear))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(settings.t(key(for: theme))))
                .accessibilityAddTraits(settings.theme == theme ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(palette.surfaceRaisedColor)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(palette.accentColor.opacity(0.25), lineWidth: 1))
    }

    private func icon(for theme: AppTheme) -> String {
        switch theme {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max.fill"
        case .dark:   return "moon.fill"
        }
    }

    private func key(for theme: AppTheme) -> String {
        "settings.theme.\(theme.rawValue)"
    }
}

// MARK: - Background

/// A handful of steel balls drifting behind the menu, so the screen is never
/// completely still. Purely decorative and switched off for reduced motion.
struct DriftingBallsBackground: View {

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let seeds: [Seed] = (0..<7).map { index in
        Seed(x: CGFloat.random(in: 0.05...0.95),
             size: CGFloat.random(in: 14...42),
             duration: Double.random(in: 9...20),
             delay: Double(index) * 1.4,
             drift: CGFloat.random(in: -40...40))
    }

    struct Seed: Identifiable {
        let id = UUID()
        let x: CGFloat
        let size: CGFloat
        let duration: Double
        let delay: Double
        let drift: CGFloat
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(seeds) { seed in
                    DriftingBall(seed: seed, height: proxy.size.height,
                                 tint: palette.accentColor,
                                 animate: !reduceMotion)
                        .position(x: seed.x * proxy.size.width, y: 0)
                }
            }
        }
        .opacity(0.22)
        .blur(radius: 0.5)
    }
}

private struct DriftingBall: View {

    let seed: DriftingBallsBackground.Seed
    let height: CGFloat
    let tint: Color
    let animate: Bool

    @State private var progress: CGFloat = 0

    var body: some View {
        Circle()
            .fill(RadialGradient(colors: [.white.opacity(0.9), tint.opacity(0.35)],
                                 center: UnitPoint(x: 0.35, y: 0.3),
                                 startRadius: 1, endRadius: seed.size))
            .frame(width: seed.size, height: seed.size)
            .offset(x: seed.drift * progress,
                    y: -seed.size + (height + seed.size * 2) * progress)
            .onAppear {
                guard animate else {
                    progress = 0.4
                    return
                }
                withAnimation(.linear(duration: seed.duration)
                    .repeatForever(autoreverses: false)
                    .delay(seed.delay)) {
                    progress = 1
                }
            }
    }
}
