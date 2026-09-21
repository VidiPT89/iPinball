import SwiftUI

struct SettingsView: View {

    @Environment(AppSettings.self) private var settings
    @Environment(\.palette) private var palette

    @State private var showResetConfirmation = false

    var body: some View {
        @Bindable var settings = settings

        Panel_Scaffold(title: settings.t("settings.title")) {
            SectionLabel(text: settings.t("settings.language"))
            GlowCard {
                NeonSegmented(
                    options: AppLanguage.allCases.map {
                        ($0, $0 == .pt ? "Português (PT)" : "English (EN)")
                    },
                    selection: $settings.language)
            }

            SectionLabel(text: settings.t("settings.appearance"))
            GlowCard {
                NeonSegmented(
                    options: AppTheme.allCases.map {
                        ($0, settings.t("settings.theme.\($0.rawValue)"))
                    },
                    selection: $settings.theme)
            }

            SectionLabel(text: settings.t("settings.audio"))
            GlowCard {
                VStack(spacing: 14) {
                    SettingRow(title: settings.t("settings.sound")) {
                        Toggle("", isOn: $settings.soundEnabled).labelsHidden()
                    }
                    SettingRow(title: settings.t("settings.music")) {
                        Toggle("", isOn: $settings.musicEnabled).labelsHidden()
                    }
                    #if os(iOS)
                    SettingRow(title: settings.t("settings.haptics")) {
                        Toggle("", isOn: $settings.hapticsEnabled).labelsHidden()
                    }
                    #endif
                }
            }

            SectionLabel(text: settings.t("settings.controls"))
            GlowCard {
                VStack(spacing: 14) {
                    SettingRow(title: settings.t("settings.leftHanded"),
                               subtitle: settings.t("settings.leftHanded.hint")) {
                        Toggle("", isOn: $settings.leftHanded).labelsHidden()
                    }
                    SettingRow(title: settings.t("settings.autoPlunge"),
                               subtitle: settings.t("settings.autoPlunge.hint")) {
                        Toggle("", isOn: $settings.autoPlunge).labelsHidden()
                    }
                }
            }

            SectionLabel(text: settings.t("settings.game"))
            GlowCard {
                SettingRow(title: settings.t("settings.balls")) {
                    NeonSegmented(options: [(3, "3"), (5, "5")],
                                  selection: $settings.ballCount)
                        .frame(width: 120)
                }
            }

            SectionLabel(text: settings.t("settings.data"))
            GlowCard {
                Button {
                    showResetConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text(settings.t("settings.resetScores"))
                        Spacer()
                    }
                    .font(Typography.body(15))
                    .foregroundStyle(palette.dangerColor)
                }
                .buttonStyle(.plain)
            }

            footer
        }
        .confirmationDialog(settings.t("settings.resetConfirm"),
                            isPresented: $showResetConfirmation,
                            titleVisibility: .visible) {
            Button(settings.t("settings.resetScores"), role: .destructive) {
                settings.clearRecords()
            }
            Button(settings.t("common.cancel"), role: .cancel) {}
        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text(settings.t("about.developedBy"))
                .font(Typography.label(12))
                .foregroundStyle(palette.dimColor)
            Text("\(settings.t("about.version")) \(AppInfo.version)")
                .font(Typography.mono(11))
                .foregroundStyle(palette.faintColor)
        }
        .padding(.top, 16)
    }
}
