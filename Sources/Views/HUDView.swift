import SwiftUI

/// The backbox. A dot-matrix display carries everything the player needs to
/// read while the ball is moving, with the pause button beside it.
struct HUDView: View {

    let model: GameModel
    let onPause: () -> Void

    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            DotMatrixDisplay(model: model)
                .frame(height: 84)
                .frame(maxWidth: 520)
            pauseButton
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .hudTypeSize()
    }

    private var pauseButton: some View {
        Button(action: onPause) {
            Image(systemName: "pause.fill")
                .font(.system(size: 12, weight: .black))
                // The cabinet is black in both themes, so the button is too.
                .foregroundStyle(Color(platform: Palette.dark.textPrimary))
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color(platform: Palette.dark.surfaceRaised)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(settings.t("a11y.pause")))
    }
}
