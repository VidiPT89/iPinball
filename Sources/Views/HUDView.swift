import SwiftUI

/// The backglass. Everything the player needs to read at a glance while the
/// ball is moving, and nothing else.
struct HUDView: View {

    let model: GameModel
    let onPause: () -> Void

    @Environment(AppSettings.self) private var settings
    @Environment(\.palette) private var palette

    var body: some View {
        VStack(spacing: 8) {
            topRow
            if model.missionID != nil { missionStrip }
            if let remaining = model.ballSaveRemaining, remaining > 0 {
                ballSaveStrip(remaining: remaining)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .hudTypeSize()
    }

    // MARK: - Rows

    private var topRow: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(settings.t("hud.score"))
                    .font(Typography.label(10))
                    .kerning(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.faintColor)

                ScoreTicker(value: model.score, font: Typography.score(30))
                    .accessibilityLabel(
                        Text(settings.t("a11y.scoreValue", model.score.grouped)))
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 6) {
                    multiplierChip
                    pauseButton
                }
                laneLights
                ballPips
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(palette.accentColor.opacity(0.22), lineWidth: 1)
        )
    }

    private var multiplierChip: some View {
        let total = model.playerMultiplier * model.comboMultiplier
            * (model.isMultiball ? 2 : 1)
        return Text("\(total)×")
            .font(Typography.score(16))
            .foregroundStyle(total > 1 ? Color(platform: .hex(0x14100A)) : palette.dimColor)
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(
                Capsule().fill(total > 1
                               ? AnyShapeStyle(palette.accentGradient)
                               : AnyShapeStyle(palette.surfaceRaisedColor))
            )
            .animation(Motion.snappy, value: total)
            .accessibilityLabel(Text(settings.t("hud.multiplier")))
            .accessibilityValue(Text("\(total)"))
    }

    private var pauseButton: some View {
        Button(action: onPause) {
            Image(systemName: "pause.fill")
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(palette.textColor)
                .frame(width: 28, height: 28)
                .background(Circle().fill(palette.surfaceRaisedColor))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(settings.t("a11y.pause")))
    }

    private var laneLights: some View {
        HStack(spacing: 4) {
            ForEach(LaneLetter.allCases, id: \.rawValue) { letter in
                let lit = model.litLanes.contains(letter.rawValue)
                Text(letter.symbol)
                    .font(Typography.label(10))
                    .foregroundStyle(lit ? Color(platform: .hex(0x14100A)) : palette.faintColor)
                    .frame(width: 18, height: 18)
                    .background(
                        Circle().fill(lit
                                      ? AnyShapeStyle(palette.accentGradient)
                                      : AnyShapeStyle(palette.surfaceRaisedColor))
                    )
                    .animation(Motion.snappy, value: lit)
                    .accessibilityLabel(Text(settings.t(lit ? "a11y.laneLit" : "a11y.laneOff",
                                                        letter.symbol)))
            }
        }
    }

    private var ballPips: some View {
        HStack(spacing: 4) {
            Text(settings.t("hud.ball"))
                .font(Typography.label(10))
                .foregroundStyle(palette.faintColor)
            ForEach(1...max(1, model.ballCount), id: \.self) { index in
                Circle()
                    .fill(index <= model.ball ? palette.accentColor : palette.faintColor.opacity(0.3))
                    .frame(width: 7, height: 7)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(
            Text(settings.t("a11y.ballValue", model.ball, model.ballCount)))
    }

    // MARK: - Strips

    private var missionStrip: some View {
        let id = model.missionID ?? ""
        let progress = model.missionTarget > 0
            ? Double(model.missionCurrent) / Double(model.missionTarget)
            : 0

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(settings.t("mission.\(id).name"))
                    .font(Typography.label(12))
                    .foregroundStyle(palette.accentLightColor)
                Spacer()
                if let remaining = model.missionRemaining {
                    Text(String(format: "%.0f s", max(0, remaining)))
                        .font(Typography.mono(12))
                        .foregroundStyle(remaining < 6 ? palette.dangerColor : palette.dimColor)
                } else {
                    Text("\(model.missionCurrent)/\(model.missionTarget)")
                        .font(Typography.mono(12))
                        .foregroundStyle(palette.dimColor)
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.surfaceRaisedColor)
                    Capsule()
                        .fill(palette.accentGradient)
                        .frame(width: proxy.size.width * min(1, max(0, progress)))
                }
            }
            .frame(height: 5)
            .animation(Motion.snappy, value: progress)

            Text(settings.t("mission.\(id).goal"))
                .font(Typography.label(11))
                .foregroundStyle(palette.faintColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }

    private func ballSaveStrip(remaining: TimeInterval) -> some View {
        let total = model.isMultiball ? PhysicsTuning.multiballSaveDuration
                                      : PhysicsTuning.ballSaveDuration
        return HStack(spacing: 8) {
            Image(systemName: "shield.fill")
                .font(.system(size: 11, weight: .bold))
            Text(settings.t("hud.ballSave"))
                .font(Typography.label(11))
            Spacer()
            Text(String(format: "%.0f", max(0, remaining)))
                .font(Typography.mono(11))
        }
        .foregroundStyle(palette.successColor)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(palette.surfaceColor.opacity(0.9))
                    Capsule()
                        .fill(palette.successColor.opacity(0.18))
                        .frame(width: proxy.size.width * CGFloat(remaining / total))
                }
            }
        )
        .clipShape(Capsule())
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }
}
