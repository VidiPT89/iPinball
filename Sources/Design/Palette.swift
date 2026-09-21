import SwiftUI

/// The ividi.dev identity: burnt orange, amber and near-black.
/// Every colour in the app comes from here, resolved for the active scheme.
struct Palette {

    let background: PlatformColor
    let surface: PlatformColor
    let surfaceRaised: PlatformColor
    let accent: PlatformColor
    let accentLight: PlatformColor
    let accentDark: PlatformColor
    let textPrimary: PlatformColor
    let textDim: PlatformColor
    let textFaint: PlatformColor
    let danger: PlatformColor
    let success: PlatformColor
    /// The playfield stays dark in both schemes. A pinball table is a box lit
    /// from the inside, and the neon needs black behind it.
    let tableFelt: PlatformColor
    let tableRail: PlatformColor

    static let dark = Palette(
        background: .hex(0x0A0A0F),
        surface: .hex(0x0D0D18),
        surfaceRaised: .hex(0x12121F),
        accent: .hex(0xF99C00),
        accentLight: .hex(0xFCBB00),
        accentDark: .hex(0xDD7400),
        textPrimary: .hex(0xE2E8F0),
        textDim: .hex(0x94A3B8),
        textFaint: .hex(0x5B6474),
        danger: .hex(0xEF4444),
        success: .hex(0x22C55E),
        tableFelt: .hex(0x0D0D14),
        tableRail: .hex(0x1C1C2B)
    )

    static let light = Palette(
        background: .hex(0xF6F4F0),
        surface: .hex(0xFFFFFF),
        surfaceRaised: .hex(0xEFEAE2),
        accent: .hex(0xDD7400),
        accentLight: .hex(0xF99C00),
        accentDark: .hex(0xB65C00),
        textPrimary: .hex(0x12121F),
        textDim: .hex(0x5B6474),
        textFaint: .hex(0x94A3B8),
        danger: .hex(0xC0392B),
        success: .hex(0x15803D),
        tableFelt: .hex(0x121220),
        tableRail: .hex(0x2A2A3D)
    )

    static func resolve(_ scheme: ColorScheme) -> Palette {
        scheme == .light ? .light : .dark
    }

    // MARK: SwiftUI bridges

    var backgroundColor: Color { Color(platform: background) }
    var surfaceColor: Color { Color(platform: surface) }
    var surfaceRaisedColor: Color { Color(platform: surfaceRaised) }
    var accentColor: Color { Color(platform: accent) }
    var accentLightColor: Color { Color(platform: accentLight) }
    var accentDarkColor: Color { Color(platform: accentDark) }
    var textColor: Color { Color(platform: textPrimary) }
    var dimColor: Color { Color(platform: textDim) }
    var faintColor: Color { Color(platform: textFaint) }
    var dangerColor: Color { Color(platform: danger) }
    var successColor: Color { Color(platform: success) }
    var feltColor: Color { Color(platform: tableFelt) }

    var glow: Color { Color(platform: accent).opacity(0.35) }

    var accentGradient: LinearGradient {
        LinearGradient(colors: [accentLightColor, accentColor, accentDarkColor],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var backdropGradient: RadialGradient {
        RadialGradient(colors: [accentColor.opacity(0.16), backgroundColor],
                       center: .top, startRadius: 0, endRadius: 620)
    }
}

private struct PaletteKey: EnvironmentKey {
    static let defaultValue = Palette.dark
}

extension EnvironmentValues {
    var palette: Palette {
        get { self[PaletteKey.self] }
        set { self[PaletteKey.self] = newValue }
    }
}
