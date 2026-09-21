import SwiftUI

struct HowToPlayView: View {

    @Environment(AppSettings.self) private var settings
    @Environment(\.palette) private var palette

    private let topics: [(key: String, icon: String)] = [
        ("basics", "circle.fill"),
        ("controls", "hand.tap.fill"),
        ("tilt", "exclamationmark.triangle.fill"),
        ("combos", "flame.fill"),
        ("missions", "target"),
        ("save", "shield.fill"),
    ]

    var body: some View {
        Panel_Scaffold(title: settings.t("howto.title")) {
            ForEach(topics, id: \.key) { topic in
                GlowCard {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: topic.icon)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(palette.accentColor)
                            Text(settings.t("howto.\(topic.key).title"))
                                .font(Typography.title(17))
                                .foregroundStyle(palette.textColor)
                        }
                        Text(settings.t("howto.\(topic.key).body"))
                            .font(Typography.body(14))
                            .foregroundStyle(palette.dimColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .combine)
            }

            SectionLabel(text: settings.t("howto.scoring.title"))
            GlowCard {
                VStack(spacing: 9) {
                    scoreRow("howto.score.bumper", ScoreValue.popBumper)
                    scoreRow("howto.score.target", ScoreValue.standupTarget)
                    scoreRow("howto.score.dropTarget", ScoreValue.dropTarget)
                    scoreRow("howto.score.ramp", ScoreValue.ramp)
                    scoreRow("howto.score.orbit", ScoreValue.orbit)
                    scoreRow("howto.score.laneSet", ScoreValue.laneSetCompleted)
                    scoreRow("howto.score.jackpot", ScoreValue.jackpot)
                    scoreRow("howto.score.superJackpot", ScoreValue.superJackpot)
                }
            }
        }
    }

    private func scoreRow(_ key: String, _ value: Int) -> some View {
        HStack {
            Text(settings.t(key))
                .font(Typography.body(14))
                .foregroundStyle(palette.dimColor)
            Spacer()
            Text(value.grouped)
                .font(Typography.mono(14))
                .foregroundStyle(palette.accentLightColor)
        }
        .accessibilityElement(children: .combine)
    }
}
