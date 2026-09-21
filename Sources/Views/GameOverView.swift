import SwiftUI

struct GameOverView: View {

    let model: GameModel
    let onPlayAgain: () -> Void
    let onMenu: () -> Void

    @Environment(AppSettings.self) private var settings
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var initials = ""
    @State private var hasSaved = false
    @State private var appeared = false

    private var isHighScore: Bool { model.highScoreRank != nil && !hasSaved }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            // The card is centred in the window rather than pinned to the top,
            // but still scrolls if it outgrows the space (long translations,
            // large Dynamic Type, a short window).
            GeometryReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        if model.highScoreRank != nil {
                            Text(settings.t("gameover.newHighScore"))
                                .font(Typography.label(13))
                                .kerning(3)
                                .foregroundStyle(palette.accentLightColor)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Capsule().strokeBorder(
                                    palette.accentColor.opacity(0.6), lineWidth: 1))
                        }

                        Text(settings.t("gameover.title"))
                            .font(Typography.display(34))
                            .foregroundStyle(palette.textColor)

                        scoreCard

                        if isHighScore { initialsEntry }

                        VStack(spacing: 10) {
                            ShareLink(item: settings.t("gameover.shareText",
                                                       model.finalScore.grouped)) {
                                Label(settings.t("gameover.share"),
                                      systemImage: "square.and.arrow.up")
                                    .font(Typography.title(17))
                                    .foregroundStyle(palette.textColor)
                                    .frame(maxWidth: .infinity, minHeight: 50)
                                    .background(palette.surfaceRaisedColor)
                                    .clipShape(RoundedRectangle(cornerRadius: 16,
                                                                style: .continuous))
                            }
                            .buttonStyle(.plain)

                            NeonButton(title: settings.t("gameover.playAgain"),
                                       systemImage: "arrow.clockwise",
                                       kind: .primary) {
                                saveIfNeeded()
                                onPlayAgain()
                            }
                            NeonButton(title: settings.t("gameover.menu"),
                                       systemImage: "house.fill",
                                       kind: .ghost) {
                                saveIfNeeded()
                                onMenu()
                            }
                        }
                    }
                    .frame(maxWidth: 380)
                    .padding(24)
                    .frame(maxWidth: .infinity, minHeight: proxy.size.height)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared || reduceMotion ? 1 : 0.94)
        }
        .accessibilityAddTraits(.isModal)
        .onAppear {
            withAnimation(Motion.respectingReduceMotion(Motion.snappy,
                                                        reduceMotion: reduceMotion)) {
                appeared = true
            }
        }
        .onDisappear { saveIfNeeded() }
    }

    // MARK: - Pieces

    private var scoreCard: some View {
        GlowCard {
            VStack(spacing: 14) {
                VStack(spacing: 4) {
                    Text(settings.t("gameover.score"))
                        .font(Typography.label(11))
                        .kerning(1.6)
                        .textCase(.uppercase)
                        .foregroundStyle(palette.faintColor)
                    Text(model.finalScore.grouped)
                        .font(Typography.score(40))
                        .foregroundStyle(palette.accentLightColor)
                }

                Divider().overlay(palette.faintColor.opacity(0.3))

                HStack {
                    statistic(settings.t("gameover.missions"), "\(model.missionsCompleted)")
                    Spacer()
                    statistic(settings.t("highscores.jackpots"), "\(model.jackpotCount)")
                    Spacer()
                    statistic(settings.t("highscores.bestCombo"), "\(model.bestCombo)×")
                }

                if settings.bestScore > 0 {
                    HStack {
                        Text(settings.t("gameover.best"))
                            .font(Typography.label(12))
                            .foregroundStyle(palette.dimColor)
                        Spacer()
                        Text(max(settings.bestScore, model.finalScore).grouped)
                            .font(Typography.mono(13))
                            .foregroundStyle(palette.textColor)
                    }
                }
            }
        }
    }

    private func statistic(_ title: String, _ value: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(Typography.score(18))
                .foregroundStyle(palette.textColor)
            Text(title)
                .font(Typography.label(10))
                .foregroundStyle(palette.faintColor)
        }
        .accessibilityElement(children: .combine)
    }

    private var initialsEntry: some View {
        GlowCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(settings.t("gameover.initials"))
                    .font(Typography.label(12))
                    .foregroundStyle(palette.dimColor)

                HStack(spacing: 10) {
                    TextField("AAA", text: $initials)
                        .textFieldStyle(.plain)
                        .font(Typography.score(24))
                        .foregroundStyle(palette.textColor)
                        .multilineTextAlignment(.center)
                        .frame(height: 46)
                        .frame(maxWidth: .infinity)
                        .background(palette.surfaceRaisedColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        #if os(iOS)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        #endif
                        .onChange(of: initials) { _, new in
                            initials = String(new.uppercased()
                                .filter(\.isLetter).prefix(3))
                        }

                    Button(settings.t("gameover.save")) { saveIfNeeded() }
                        .font(Typography.title(16))
                        .foregroundStyle(Color(platform: .hex(0x14100A)))
                        .padding(.horizontal, 18)
                        .frame(height: 46)
                        .background(palette.accentGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .buttonStyle(.plain)
                        .disabled(initials.isEmpty)
                        .opacity(initials.isEmpty ? 0.5 : 1)
                }
            }
        }
    }

    /// Records the game exactly once, whichever way the player leaves.
    private func saveIfNeeded() {
        guard !hasSaved else { return }
        hasSaved = true
        settings.recordGame(
            score: model.finalScore,
            initials: initials.isEmpty ? nil : initials,
            missionsCompleted: model.missionsCompleted,
            ballsPlayed: model.ballsPlayed,
            jackpots: model.jackpotCount,
            bestCombo: model.bestCombo,
            duration: Date().timeIntervalSince(model.startedAt))
    }
}
