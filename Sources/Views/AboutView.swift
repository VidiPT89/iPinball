import SwiftUI

struct AboutView: View {

    @Environment(AppSettings.self) private var settings
    @Environment(\.palette) private var palette
    @Environment(\.openURL) private var openURL

    private let website = URL(string: "https://ividi.dev/")!
    private let github = URL(string: "https://github.com/VidiPT89/")!

    var body: some View {
        Panel_Scaffold(title: settings.t("about.title")) {
            VStack(spacing: 12) {
                NeonTitle(text: "iPinball", size: 42)
                Text(settings.t("menu.tagline"))
                    .font(Typography.label(12))
                    .kerning(2.2)
                    .textCase(.uppercase)
                    .foregroundStyle(palette.dimColor)
            }
            .padding(.vertical, 12)

            GlowCard {
                VStack(spacing: 14) {
                    Text(settings.t("about.developedBy"))
                        .font(Typography.title(17))
                        .foregroundStyle(palette.textColor)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Divider().overlay(palette.faintColor.opacity(0.25))

                    linkRow(title: settings.t("about.website"),
                            value: "ividi.dev",
                            icon: "globe",
                            url: website,
                            label: settings.t("a11y.openWebsite"))

                    linkRow(title: settings.t("about.github"),
                            value: "@VidiPT89",
                            icon: "chevron.left.forwardslash.chevron.right",
                            url: github,
                            label: settings.t("a11y.openGitHub"))

                    Divider().overlay(palette.faintColor.opacity(0.25))

                    HStack {
                        Text(settings.t("about.version"))
                            .font(Typography.body(14))
                            .foregroundStyle(palette.dimColor)
                        Spacer()
                        Text(AppInfo.version)
                            .font(Typography.mono(14))
                            .foregroundStyle(palette.textColor)
                    }
                }
            }

            Text(settings.t("about.credits"))
                .font(Typography.label(11))
                .foregroundStyle(palette.faintColor)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
        }
    }

    private func linkRow(title: String, value: String, icon: String,
                         url: URL, label: String) -> some View {
        Button {
            openURL(url)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(palette.accentColor)
                    .frame(width: 22)
                Text(title)
                    .font(Typography.body(14))
                    .foregroundStyle(palette.dimColor)
                Spacer()
                Text(value)
                    .font(Typography.mono(14))
                    .foregroundStyle(palette.textColor)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(palette.faintColor)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}
