import SwiftUI

enum Typography {

    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    static func title(_ size: CGFloat = 26) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    static func body(_ size: CGFloat = 16) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    static func label(_ size: CGFloat = 13) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    /// Tabular figures so the scoreboard digits never dance.
    static func score(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
            .monospacedDigit()
    }

    static func mono(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }
}

extension View {
    /// Caps Dynamic Type inside the HUD, where an unbounded size breaks layout.
    func hudTypeSize() -> some View {
        dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }
}
