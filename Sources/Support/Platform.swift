import CoreGraphics
import SpriteKit
import SwiftUI

#if canImport(UIKit)
import UIKit
typealias PlatformColor = UIColor
#else
import AppKit
typealias PlatformColor = NSColor
#endif

// MARK: - Colours

extension PlatformColor {

    /// `0xRRGGBB` literal, which is how the ividi.dev palette is written down.
    static func hex(_ value: UInt32) -> PlatformColor {
        PlatformColor(red: CGFloat((value >> 16) & 0xFF) / 255,
                      green: CGFloat((value >> 8) & 0xFF) / 255,
                      blue: CGFloat(value & 0xFF) / 255,
                      alpha: 1)
    }

    /// sRGB components, going through a conversion on macOS where a colour may
    /// live in a space that cannot answer `getRed` directly.
    var rgba: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
        #else
        guard let converted = usingColorSpace(.sRGB) else { return (0, 0, 0, 1) }
        return (converted.redComponent, converted.greenComponent,
                converted.blueComponent, converted.alphaComponent)
        #endif
    }

    /// Linear blend, used when the table repaints itself after a theme change.
    func blended(with other: PlatformColor, amount: CGFloat) -> PlatformColor {
        let a = rgba
        let b = other.rgba
        let t = max(0, min(1, amount))
        return PlatformColor(red: a.r + (b.r - a.r) * t,
                             green: a.g + (b.g - a.g) * t,
                             blue: a.b + (b.b - a.b) * t,
                             alpha: a.a + (b.a - a.a) * t)
    }

    /// A stable key for the texture cache. `hashValue` is not stable enough
    /// across launches and produces needless cache misses.
    var cacheKey: String {
        let c = rgba
        return String(format: "%02X%02X%02X%02X",
                      Int(c.r * 255), Int(c.g * 255), Int(c.b * 255), Int(c.a * 255))
    }
}

extension Color {
    init(platform: PlatformColor) {
        #if canImport(UIKit)
        self.init(uiColor: platform)
        #else
        self.init(nsColor: platform)
        #endif
    }
}

// MARK: - Offscreen drawing

/// Draws into a bitmap and hands back an `SKTexture`, without UIKit or AppKit.
/// The context is y-up, matching SpriteKit, so the drawing code reads the same
/// way as the scene code around it.
enum TextureCanvas {

    static func texture(size: CGSize, scale: CGFloat = 2,
                        _ draw: (CGContext) -> Void) -> SKTexture {
        let pixels = CGSize(width: max(1, size.width * scale),
                            height: max(1, size.height * scale))
        guard let context = CGContext(
            data: nil,
            width: Int(pixels.width),
            height: Int(pixels.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else {
            return SKTexture()
        }
        context.scaleBy(x: scale, y: scale)
        draw(context)
        guard let image = context.makeImage() else { return SKTexture() }
        let texture = SKTexture(cgImage: image)
        texture.filteringMode = .linear
        return texture
    }

    static func gradient(_ colors: [PlatformColor],
                         locations: [CGFloat]) -> CGGradient? {
        CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                   colors: colors.map(\.cgColor) as CFArray,
                   locations: locations)
    }
}

// MARK: - Platform traits

enum PlatformTraits {
    /// Touch platforms get on-screen flipper zones; the Mac gets the keyboard.
    static var usesTouchControls: Bool {
        #if os(iOS)
        return true
        #else
        return false
        #endif
    }
}
