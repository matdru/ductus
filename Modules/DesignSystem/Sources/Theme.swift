import SwiftUI

/// The app's look as data: colours by role, type styles and metrics. Views read these tokens from the environment
/// (`@Environment(\.theme)`) and never use raw colours, so swapping the root theme re-skins the whole app.
public struct Theme: Sendable, Identifiable {
    public let id: String
    public var name: String
    public var colors: ThemeColors
    public var typography: Typography
    public var metrics: Metrics

    public init(id: String, name: String, colors: ThemeColors, typography: Typography, metrics: Metrics) {
        self.id = id
        self.name = name
        self.colors = colors
        self.typography = typography
        self.metrics = metrics
    }

    /// Every shipped theme, in picker order.
    public static let all: [Theme] = [.graphite, .studio]

    /// The theme with this id, or Graphite.
    public static func named(_ id: String) -> Theme {
        all.first { $0.id == id } ?? .graphite
    }
}

extension Theme: CustomStringConvertible {
    /// Just the id, so logs and test names stay short.
    public var description: String { id }
}

/// Colours by role. Name what a colour is for, never what it looks like.
public struct ThemeColors: Sendable {
    /// Behind everything: the library background and the desk around pages.
    public var canvas: ThemeColor
    /// Cards, fields, panels.
    public var surface: ThemeColor
    /// Raised or selected surfaces: the selected sidebar row, popovers.
    public var elevated: ThemeColor
    public var sidebar: ThemeColor
    /// One-pixel separators and outlines.
    public var hairline: ThemeColor
    public var textPrimary: ThemeColor
    public var textSecondary: ThemeColor
    /// Decorative text that needn't meet contrast: shortcut hints, placeholders.
    public var textTertiary: ThemeColor
    public var accent: ThemeColor
    /// Text and icons on an accent-filled control.
    public var onAccent: ThemeColor
    /// Subtle accent background: the selected tool.
    public var accentTint: ThemeColor
    public var danger: ThemeColor
    public var notebook: [NotebookColor: ThemeColor]

    public func notebook(_ name: NotebookColor) -> ThemeColor {
        notebook[name] ?? accent
    }
}

/// The notebook colour palette. Each theme supplies its own shade of every entry.
public enum NotebookColor: String, CaseIterable, Sendable {
    case ink, navy, teal, forest, mustard, clay, red, plum, graphite, sand
}

public struct Typography: Sendable {
    public struct Style: Sendable {
        public var size: Double
        public var weight: Font.Weight
        public var design: Font.Design
        /// Tracking in points; negative tightens large titles.
        public var tracking: Double

        public init(size: Double, weight: Font.Weight, design: Font.Design = .default, tracking: Double = 0) {
            self.size = size
            self.weight = weight
            self.design = design
            self.tracking = tracking
        }

        public var font: Font { .system(size: size, weight: weight, design: design) }
    }

    public var largeTitle: Style
    public var title: Style
    public var headline: Style
    public var body: Style
    public var caption: Style
    /// Numbers and metadata: page counts, dates, shortcuts.
    public var mono: Style
}

public struct Metrics: Sendable {
    public var radiusSmall: Double
    public var radiusMedium: Double
    public var radiusLarge: Double
    public var spacing: Double
}

extension EnvironmentValues {
    @Entry public var theme: Theme = .graphite
}

extension Text {
    /// Applies a theme type style, including its tracking.
    public func style(_ style: Typography.Style) -> Text {
        font(style.font).tracking(style.tracking)
    }
}
