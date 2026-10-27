import SwiftUI
import UIKit

/// An sRGB colour with alpha, 0...1 per channel.
public struct RGBA: Sendable, Hashable {
    public var red: Double
    public var green: Double
    public var blue: Double
    public var alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    /// `0xRRGGBB`.
    public init(hex: UInt32, alpha: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255, alpha: alpha)
    }

    /// WCAG 2 relative luminance.
    public var luminance: Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.039_28 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG 2 contrast ratio, 1...21. AA body text needs 4.5.
    public func contrastRatio(with other: RGBA) -> Double {
        let (lighter, darker) =
            luminance > other.luminance ? (luminance, other.luminance) : (other.luminance, luminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    var uiColor: UIColor { UIColor(red: red, green: green, blue: blue, alpha: alpha) }

    /// For content colours that don't change with the theme, like paper. UI chrome uses `ThemeColor` tokens.
    public var color: Color { Color(uiColor: uiColor) }
}

/// A theme colour: one value for light mode and one for dark. Resolves automatically with the system appearance,
/// in SwiftUI and UIKit alike.
public struct ThemeColor: Sendable, Hashable {
    public enum Mode: CaseIterable, Sendable {
        case light, dark
    }

    public var light: RGBA
    public var dark: RGBA

    public init(light: RGBA, dark: RGBA) {
        self.light = light
        self.dark = dark
    }

    public init(light: UInt32, dark: UInt32) {
        self.init(light: RGBA(hex: light), dark: RGBA(hex: dark))
    }

    public subscript(mode: Mode) -> RGBA {
        switch mode {
        case .light: light
        case .dark: dark
        }
    }

    public var uiColor: UIColor {
        let light = light.uiColor
        let dark = dark.uiColor
        return UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light }
    }

    public var color: Color { Color(uiColor: uiColor) }
}

extension ThemeColor: ShapeStyle {
    public func resolve(in environment: EnvironmentValues) -> Color.Resolved {
        color.resolve(in: environment)
    }
}
