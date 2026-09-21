import SwiftUI

struct PauseOverlay: View {

    let onResume: () -> Void
    let onRestart: () -> Void
    let onQuit: () -> Void

    @Environment(AppSettings.self) private var settings
    @Environment(\.palette) private var palette

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture(perform: onResume)

            VStack(spacing: 18) {
                Text(settings.t("pause.title"))
                    .font(Typography.display(34))
                    .foregroundStyle(palette.textColor)

                VStack(spacing: 10) {
                    NeonButton(title: settings.t("pause.resume"),
                               systemImage: "play.fill",
                               kind: .primary, action: onResume)
                    NeonButton(title: settings.t("pause.restart"),
                               systemImage: "arrow.clockwise",
                               kind: .secondary, action: onRestart)
                    NeonButton(title: settings.t("pause.menu"),
                               systemImage: "house.fill",
                               kind: .ghost, action: onQuit)
                }
                .frame(maxWidth: 340)
            }
            .padding(28)
        }
        .accessibilityAddTraits(.isModal)
    }
}
