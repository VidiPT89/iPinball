import SwiftUI

/// The dot-matrix display in the backbox: amber plasma dots behind glass,
/// the scoreboard of every table from the early 90s on. Everything the
/// machine has to say goes through here — the score, the ball, the mission,
/// JACKPOT, TILT, and the end-of-ball bonus counted out line by line.
struct DotMatrixDisplay: View {

    let model: GameModel

    @Environment(AppSettings.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The plasma colour. It does not follow the theme: a DMD is always amber
    /// on black, whatever the room's lights are doing.
    private static let plasma = Color(platform: .hex(0xFF8A1C))

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            TimelineView(.periodic(from: .now, by: 0.1)) { context in
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.black)
                    DotGrid(pitch: pitch(for: height))
                        .fill(Self.plasma.opacity(0.10))
                    frame(at: context.date, height: height)
                        .foregroundStyle(Self.plasma)
                        .padding(.horizontal, height * 0.12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .mask(DotGrid(pitch: pitch(for: height)).fill(Color.white))
                        .shadow(color: Self.plasma.opacity(0.55), radius: 3)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color(platform: .hex(0x2A2A33)), lineWidth: 2)
                )
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Text(settings.t("a11y.scoreValue", model.score.grouped)))
        .accessibilityValue(Text(settings.t("a11y.ballValue", model.ball, model.ballCount)))
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// About 28 rows of dots, the density of a 128 × 32 panel at this size.
    private func pitch(for height: CGFloat) -> CGFloat { max(2, height / 28) }

    // MARK: - What to show

    @ViewBuilder
    private func frame(at date: Date, height: CGFloat) -> some View {
        if let bonus = model.bonus, let start = model.bonusStartedAt,
           let end = model.bonusEndsAt, date < end {
            bonusFrame(bonus, elapsed: date.timeIntervalSince(start), height: height)
        } else if let banner = model.banner, date >= banner.showsAt,
                  date.timeIntervalSince(banner.showsAt) < Motion.dmdMessage {
            messageFrame(banner, elapsed: date.timeIntervalSince(banner.showsAt),
                         height: height)
        } else {
            scoreFrame(at: date, height: height)
        }
    }

    private func scoreFrame(at date: Date, height: CGFloat) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(settings.t("hud.ball").uppercased() + " \(model.ball)")
                Spacer()
                Text(multiplierText)
            }
            .font(small(height))

            Text(model.score.grouped)
                .font(large(height))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxHeight: .infinity)

            statusLine(at: date)
                .font(small(height))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.vertical, height * 0.08)
    }

    private var multiplierText: String {
        let total = model.playerMultiplier * model.comboMultiplier * (model.isMultiball ? 2 : 1)
        return total > 1 ? "\(total)X" : ""
    }

    /// The bottom row: what the player should be doing right now.
    @ViewBuilder
    private func statusLine(at date: Date) -> some View {
        if model.showLaunchHint {
            // Alternates between the skill shot and how to launch.
            let phase = Int(date.timeIntervalSinceReferenceDate / 1.6) % 2
            Text(settings.t(phase == 0 ? "hud.skillShotHint"
                            : (PlatformTraits.usesTouchControls ? "hud.launch"
                                                                : "hud.launchKeyboard"))
                .uppercased())
        } else if let id = model.missionID {
            HStack {
                Text(settings.t("mission.\(id).name").uppercased())
                Spacer()
                if let remaining = model.missionRemaining {
                    Text("\(model.missionCurrent)/\(model.missionTarget)  "
                         + String(format: "%02.0f", max(0, remaining)))
                } else {
                    Text("\(model.missionCurrent)/\(model.missionTarget)")
                }
            }
        } else if model.isMultiball {
            Text(settings.t("hud.jackpotIsLit"))
        } else {
            laneLetters
        }
    }

    /// P-I-N-B, with the unlit letters dimmed rather than hidden.
    private var laneLetters: some View {
        HStack(spacing: 10) {
            ForEach(LaneLetter.allCases, id: \.rawValue) { letter in
                Text(letter.symbol)
                    .opacity(model.litLanes.contains(letter.rawValue) ? 1 : 0.28)
            }
        }
    }

    private func messageFrame(_ banner: GameModel.Banner, elapsed: TimeInterval,
                              height: CGFloat) -> some View {
        // Bad news flashes; good news holds steady after a short flash in.
        let flashes = banner.style == .bad || elapsed < 0.35
        let visible = reduceMotion || !flashes || Int(elapsed / 0.12) % 2 == 0
        return VStack(spacing: height * 0.04) {
            Text(settings.t(banner.key).uppercased())
                .font(large(height))
                .lineLimit(1)
                .minimumScaleFactor(0.4)
            if let detail = banner.detail {
                Text(detail).font(medium(height))
            }
        }
        .opacity(visible ? 1 : 0)
    }

    private func bonusFrame(_ bonus: BonusReport, elapsed: TimeInterval,
                            height: CGFloat) -> some View {
        let step = Int(elapsed / Motion.dmdBonusStep)
        var lines: [(String, String)] = [(settings.t("hud.bonus"), "")]
        if bonus.targets > 0 {
            lines.append((settings.t("hud.bonusTargets"),
                          "\(bonus.targets) × \(ScoreValue.bonusPerDroppedTarget.grouped)"))
        }
        if bonus.loops > 0 {
            lines.append((settings.t("hud.bonusLoops"),
                          "\(bonus.loops) × \(ScoreValue.bonusPerLoop.grouped)"))
        }
        if bonus.multiplier > 1 {
            lines.append((settings.t("hud.bonusMultiplier"), "\(bonus.multiplier)X"))
        }

        return Group {
            if step < lines.count {
                VStack(spacing: height * 0.04) {
                    Text(lines[step].0.uppercased()).font(large(height))
                    if !lines[step].1.isEmpty {
                        Text(lines[step].1).font(medium(height))
                    }
                }
            } else {
                VStack(spacing: height * 0.04) {
                    Text(settings.t("hud.bonusTotal").uppercased()).font(medium(height))
                    Text(bonus.total.grouped).font(large(height))
                }
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.5)
    }

    // MARK: - Type

    private func large(_ height: CGFloat) -> Font {
        .system(size: height * 0.40, weight: .black, design: .monospaced)
    }

    private func medium(_ height: CGFloat) -> Font {
        .system(size: height * 0.24, weight: .heavy, design: .monospaced)
    }

    private func small(_ height: CGFloat) -> Font {
        .system(size: height * 0.18, weight: .heavy, design: .monospaced)
    }
}

/// A square lattice of round dots, used both as the unlit panel and as the
/// mask that breaks the text up into lit pixels.
private struct DotGrid: Shape {

    let pitch: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = pitch * 0.40
        var y = rect.minY + pitch / 2
        while y < rect.maxY {
            var x = rect.minX + pitch / 2
            while x < rect.maxX {
                path.addEllipse(in: CGRect(x: x - radius, y: y - radius,
                                           width: radius * 2, height: radius * 2))
                x += pitch
            }
            y += pitch
        }
        return path
    }
}
