public struct InkColor: Sendable, Codable, Equatable {
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

    public static let black = InkColor(red: 0, green: 0, blue: 0)
}

public struct InkTool: Sendable, Codable, Equatable {
    public enum Kind: String, Sendable, Codable {
        case pen
        case highlighter
        case fountainPen
    }

    public var kind: Kind
    public var color: InkColor
    /// Nominal stroke width in canvas points.
    public var width: Double

    public init(kind: Kind, color: InkColor, width: Double) {
        self.kind = kind
        self.color = color
        self.width = width
    }

    public static let defaultPen = InkTool(kind: .pen, color: .black, width: 3)
    /// `width` is the nominal thick width; the custom engine's nib parameters govern how it renders.
    public static let fountainPen = InkTool(kind: .fountainPen, color: .black, width: 8.9)
}
