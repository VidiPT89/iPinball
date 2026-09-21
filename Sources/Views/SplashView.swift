import SwiftUI

/// The short title card. It plays once, credits the author, and gets out of
/// the way — on its own after `Motion.splashTotal`, or immediately on a tap.
struct SplashView: View {

    let onFinish: () -> Void

    @Environment(AppSettings.self) private var settings
    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    @State private var ballDropped = false
    @State private var showWordmark = false
    @State private var showCredit = false
    @State private var showLinks = false
    @State private var hasFinished = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ZStack {
                glowHalo
                steelBall
            }
            .frame(height: 120)

            NeonTitle(text: "iPinball", size: 56)
                .opacity(showWordmark ? 1 : 0)
                .scaleEffect(showWordmark || reduceMotion ? 1 : 0.86)
                .padding(.top, 14)

            Text(settings.t("menu.tagline"))
                .font(Typography.label(14))
                .kerning(2.4)
                .textCase(.uppercase)
                .foregroundStyle(palette.dimColor)
                .opacity(showWordmark ? 1 : 0)
                .padding(.top, 10)

            Spacer()

            credits
                .padding(.bottom, 44)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .accessibilityElement(children: .contain)
        .accessibilityAction { finish() }
        .onAppear(perform: run)
    }

    // MARK: - Pieces

    private var steelBall: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [.white, Color(white: 0.78), Color(white: 0.35), Color(white: 0.16)],
                    center: UnitPoint(x: 0.34, y: 0.30),
                    startRadius: 2,
                    endRadius: 58)
            )
            .frame(width: 74, height: 74)
            .shadow(color: palette.accentColor.opacity(0.7), radius: 26)
            .offset(y: ballDropped || reduceMotion ? 0 : -160)
            .opacity(ballDropped || reduceMotion ? 1 : 0)
    }

    private var glowHalo: some View {
        Circle()
            .fill(palette.accentColor)
            .frame(width: 150, height: 150)
            .blur(radius: 55)
            .opacity(ballDropped ? 0.55 : 0)
    }

    private var credits: some View {
        VStack(spacing: 12) {
            Text(settings.t("about.developedBy"))
                .font(Typography.body(15))
                .foregroundStyle(palette.textColor)

            HStack(spacing: 22) {
                linkButton(title: "ividi.dev", systemImage: "globe",
                           url: Links.website, label: settings.t("a11y.openWebsite"))
                linkButton(title: "VidiPT89", systemImage: "chevron.left.forwardslash.chevron.right",
                           url: Links.github, label: settings.t("a11y.openGitHub"))
            }
        }
        .opacity(showCredit ? 1 : 0)
        .offset(y: showCredit || reduceMotion ? 0 : 14)
        .overlay(alignment: .bottom) {
            Text("v\(AppInfo.version)")
                .font(Typography.mono(11))
                .foregroundStyle(palette.faintColor)
                .opacity(showLinks ? 1 : 0)
                .offset(y: 30)
        }
    }

    private func linkButton(title: String, systemImage: String,
                            url: URL, label: String) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(Typography.label(13))
            }
            .foregroundStyle(palette.accentColor)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }

    // MARK: - Choreography

    private func run() {
        guard !reduceMotion else {
            ballDropped = true
            showWordmark = true
            showCredit = true
            showLinks = true
            schedule(after: Motion.splashReducedMotion) { finish() }
            return
        }

        withAnimation(.spring(response: Motion.splashBallDrop, dampingFraction: 0.55)) {
            ballDropped = true
        }
        withAnimation(.easeOut(duration: Motion.splashWordmark).delay(0.35)) {
            showWordmark = true
        }
        withAnimation(.easeOut(duration: Motion.splashCredit).delay(0.85)) {
            showCredit = true
        }
        withAnimation(.easeOut(duration: Motion.splashLinks).delay(1.20)) {
            showLinks = true
        }
        schedule(after: Motion.splashTotal) { finish() }
    }

    private func schedule(after delay: TimeInterval, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    /// Guarded, because the timer and a tap can both arrive.
    private func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        onFinish()
    }
}

enum AppInfo {
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.0.0"
    }
}
