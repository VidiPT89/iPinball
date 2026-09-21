import SwiftUI

struct HighScoresView: View {

    @Environment(AppSettings.self) private var settings
    @Environment(\.palette) private var palette

    var body: some View {
        Panel_Scaffold(title: settings.t("highscores.title")) {
            if settings.saved.highScores.isEmpty {
                GlowCard {
                    Text(settings.t("highscores.empty"))
                        .font(Typography.body(14))
                        .foregroundStyle(palette.dimColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                GlowCard(padding: 10) {
                    VStack(spacing: 0) {
                        ForEach(Array(settings.saved.highScores.enumerated()),
                                id: \.element.id) { index, entry in
                            row(rank: index + 1, entry: entry)
                            if index < settings.saved.highScores.count - 1 {
                                Divider().overlay(palette.faintColor.opacity(0.18))
                            }
                        }
                    }
                }
            }

            SectionLabel(text: settings.t("highscores.stats"))
            GlowCard {
                VStack(spacing: 12) {
                    statRow(settings.t("highscores.games"),
                            "\(settings.saved.lifetime.gamesPlayed)")
                    statRow(settings.t("highscores.balls"),
                            "\(settings.saved.lifetime.ballsPlayed)")
                    statRow(settings.t("highscores.jackpots"),
                            "\(settings.saved.lifetime.jackpots)")
                    statRow(settings.t("highscores.bestCombo"),
                            "\(settings.saved.lifetime.bestCombo)×")
                    statRow(settings.t("highscores.playTime"),
                            formatted(settings.saved.lifetime.playTime))
                }
            }
        }
    }

    private func row(rank: Int, entry: HighScore) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(Typography.score(15))
                .foregroundStyle(rank <= 3 ? palette.accentLightColor : palette.faintColor)
                .frame(width: 24, alignment: .trailing)

            Text(entry.initials)
                .font(Typography.mono(15))
                .foregroundStyle(palette.textColor)
                .frame(width: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.score.grouped)
                    .font(Typography.score(16))
                    .foregroundStyle(palette.textColor)
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(Typography.label(10))
                    .foregroundStyle(palette.faintColor)
            }

            Spacer(minLength: 4)

            if entry.missionsCompleted > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "target")
                        .font(.system(size: 9, weight: .bold))
                    Text("\(entry.missionsCompleted)")
                        .font(Typography.mono(11))
                }
                .foregroundStyle(palette.accentColor)
            }
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 6)
        .accessibilityElement(children: .combine)
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .font(Typography.body(14))
                .foregroundStyle(palette.dimColor)
            Spacer()
            Text(value)
                .font(Typography.mono(14))
                .foregroundStyle(palette.textColor)
        }
        .accessibilityElement(children: .combine)
    }

    private func formatted(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let hours = minutes / 60
        return hours > 0 ? "\(hours) h \(minutes % 60) min" : "\(minutes) min"
    }
}
