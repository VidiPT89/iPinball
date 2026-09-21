import SwiftUI

/// Shared frame for the four sheets, so they open the same way and are
/// dismissed the same way on both platforms.
struct Panel_Scaffold<Content: View>: View {

    let title: String
    @ViewBuilder var content: Content

    @Environment(AppSettings.self) private var settings
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            palette.backgroundColor.ignoresSafeArea()
            palette.backdropGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Text(title)
                        .font(Typography.display(26))
                        .foregroundStyle(palette.textColor)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .black))
                            .foregroundStyle(palette.textColor)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(palette.surfaceRaisedColor))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(settings.t("common.close")))
                }
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 14)

                ScrollView {
                    VStack(spacing: 14) {
                        content
                    }
                    .frame(maxWidth: 460)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .frame(minWidth: 380, minHeight: 480)
    }
}

/// One labelled row inside a card.
struct SettingRow<Control: View>: View {

    let title: String
    var subtitle: String?
    @ViewBuilder var control: Control

    @Environment(\.palette) private var palette

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typography.body(15))
                    .foregroundStyle(palette.textColor)
                if let subtitle {
                    Text(subtitle)
                        .font(Typography.label(11))
                        .foregroundStyle(palette.faintColor)
                }
            }
            Spacer(minLength: 8)
            control
        }
        .padding(.vertical, 2)
    }
}

/// Section heading above a card.
struct SectionLabel: View {
    let text: String
    @Environment(\.palette) private var palette

    var body: some View {
        Text(text)
            .font(Typography.label(11))
            .kerning(1.8)
            .textCase(.uppercase)
            .foregroundStyle(palette.faintColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
    }
}
