import SwiftUI

// MARK: - Neon button

struct NeonButton: View {
    enum Kind { case primary, secondary, ghost }

    let title: String
    var systemImage: String?
    var kind: Kind = .primary
    var action: () -> Void

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .bold))
                }
                Text(title)
                    .font(Typography.title(19))
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: kind == .primary ? 0 : 1.4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: kind == .primary ? palette.glow : .clear,
                    radius: pressed ? 6 : 18, y: pressed ? 2 : 8)
            .scaleEffect(pressed && !reduceMotion ? 0.97 : 1)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: Motion.buttonPress)) { pressed = true }
                }
                .onEnded { _ in
                    withAnimation(.easeOut(duration: Motion.buttonPress)) { pressed = false }
                }
        )
    }

    @ViewBuilder private var background: some View {
        switch kind {
        case .primary: palette.accentGradient
        case .secondary: palette.surfaceRaisedColor
        case .ghost: Color.clear
        }
    }

    private var foreground: Color {
        kind == .primary ? Color(platform: .hex(0x14100A)) : palette.textColor
    }

    private var borderColor: Color {
        kind == .ghost ? palette.faintColor.opacity(0.5) : palette.accentColor.opacity(0.45)
    }
}

// MARK: - Glow card

struct GlowCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content
    @Environment(\.palette) private var palette

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.surfaceColor)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(palette.accentColor.opacity(0.18), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Neon wordmark

struct NeonTitle: View {
    let text: String
    var size: CGFloat = 46
    @Environment(\.palette) private var palette

    var body: some View {
        Text(text)
            .font(Typography.display(size))
            .kerning(1.5)
            .overlay(palette.accentGradient.mask(
                Text(text).font(Typography.display(size)).kerning(1.5)
            ))
            .shadow(color: palette.accentColor.opacity(0.55), radius: 18)
            .shadow(color: palette.accentLightColor.opacity(0.25), radius: 38)
    }
}

// MARK: - Rolling score

/// Counts up to the new value instead of snapping, and pops on big gains.
struct ScoreTicker: View {
    let value: Int
    var font: Font = Typography.score(34)

    @Environment(\.palette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var displayed = 0
    @State private var scale: CGFloat = 1

    var body: some View {
        Text(displayed.grouped)
            .font(font)
            .foregroundStyle(palette.textColor)
            .scaleEffect(scale)
            .onChange(of: value) { old, new in
                animate(from: old, to: new)
            }
            .onAppear { displayed = value }
            .accessibilityLabel(Text(value.grouped))
    }

    private func animate(from old: Int, to new: Int) {
        guard !reduceMotion else {
            displayed = new
            return
        }
        if new - old >= 50_000 {
            withAnimation(.easeOut(duration: Motion.scorePop)) { scale = 1.12 }
            withAnimation(.easeIn(duration: Motion.scorePop).delay(Motion.scorePop)) {
                scale = 1
            }
        }
        let steps = 14
        let stepDuration = Motion.scoreRoll / Double(steps)
        for step in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                let progress = Double(step) / Double(steps)
                let eased = 1 - pow(1 - progress, 3)
                displayed = old + Int(Double(new - old) * eased)
                if step == steps { displayed = new }
            }
        }
    }
}

// MARK: - Segmented choice

struct NeonSegmented<Value: Hashable>: View {
    let options: [(value: Value, label: String)]
    @Binding var selection: Value
    @Environment(\.palette) private var palette

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.value) { option in
                Button {
                    withAnimation(Motion.snappy) { selection = option.value }
                } label: {
                    Text(option.label)
                        .font(Typography.label(14))
                        .foregroundStyle(selection == option.value
                                         ? Color(platform: .hex(0x14100A))
                                         : palette.dimColor)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(selection == option.value
                                      ? AnyShapeStyle(palette.accentGradient)
                                      : AnyShapeStyle(Color.clear))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == option.value ? [.isSelected] : [])
            }
        }
        .padding(4)
        .background(palette.surfaceRaisedColor)
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
    }
}

// MARK: - Helpers

extension Int {
    var grouped: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
