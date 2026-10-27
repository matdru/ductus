import CoreGraphics
import NotebookCore

/// A colour for paper markings, `0xRRGGBB` plus alpha. Paper is content, so it ignores the app theme.
public struct PaperInk: Sendable, Hashable {
    public var hex: UInt32
    public var alpha: Double

    public init(hex: UInt32, alpha: Double) {
        self.hex = hex
        self.alpha = alpha
    }
}

public struct PaperLine: Sendable, Hashable {
    public var start: CGPoint
    public var end: CGPoint
    /// Stroke width in page points.
    public var weight: Double
    public var color: PaperInk
}

public struct PaperDot: Sendable, Hashable {
    public var center: CGPoint
    public var radius: Double
    public var color: PaperInk
}

/// Every mark on a sheet of paper, in page points (1/72 inch) with the origin at the top left. Spacing comes from
/// real stationery in millimetres, so a page looks the same at any size it's drawn (paper catalogue, DRU-23).
public struct PaperLayout: Sendable {
    public var background: UInt32
    public var lines: [PaperLine] = []
    public var dots: [PaperDot] = []

    public static let marginRed = PaperInk(hex: 0xD9626B, alpha: 0.7)
    static let hairline = mm(0.12)

    public init(paper: Paper, size: PageSize) {
        background = paper.color.hex
        var builder = Builder(paper: paper, width: size.width, height: size.height)
        builder.build()
        lines = builder.lines
        dots = builder.dots
    }

    static func mm(_ millimetres: Double) -> Double { PageSize.points(millimetres: millimetres) }
}

/// Builds the marks for one paper type.
private struct Builder {
    let paper: Paper
    let width: Double
    let height: Double
    var lines: [PaperLine] = []
    var dots: [PaperDot] = []

    func mm(_ millimetres: Double) -> Double { PaperLayout.mm(millimetres) }
    var isDark: Bool { paper.color == .charcoal }

    /// Rule colour for the paper type; dark paper always gets light rules.
    func rule(_ hex: UInt32, _ alpha: Double) -> PaperInk {
        isDark ? PaperInk(hex: 0xFFFFFF, alpha: 0.22) : PaperInk(hex: hex, alpha: alpha)
    }

    var grey: PaperInk { rule(0x6E6A62, 0.32) }
    var weight: Double { PaperLayout.hairline }

    mutating func build() {
        switch paper.type {
        case .classicLined:
            rules(spacing: mm(7.1), top: mm(25), color: rule(0x8DB3DA, 0.75))
            vertical(x: mm(32), color: PaperLayout.marginRed, weight: weight * 1.2)
        case .fineLined:
            rules(spacing: mm(6), top: mm(18), inset: mm(10), color: grey)
        case .legal:
            rules(spacing: mm(8.7), top: mm(30), color: rule(0x5078BE, 0.4))
            vertical(x: mm(30), color: PaperLayout.marginRed, weight: weight)
            vertical(x: mm(31.5), color: PaperLayout.marginRed, weight: weight)
        case .dotGrid:
            dotGrid(spacing: mm(5))
        case .squared:
            grid(spacing: mm(5), every: 0, color: rule(0x6E6A62, 0.18))
            vertical(x: mm(20), color: PaperLayout.marginRed, weight: weight)
        case .engineering:
            grid(spacing: mm(5), every: 5, color: rule(0x5E9E6E, 0.45))
        case .cornell:
            cornell()
        case .music:
            staves()
        case .blank:
            break
        }
    }

    mutating func rules(spacing: Double, top: Double, inset: Double = 0, bottom: Double? = nil, color: PaperInk) {
        let limit = bottom ?? height - spacing / 2
        for y in stride(from: top, to: limit, by: spacing) {
            lines.append(line(CGPoint(x: inset, y: y), CGPoint(x: width - inset, y: y), weight, color))
        }
    }

    mutating func vertical(x: Double, from top: Double = 0, to bottom: Double? = nil, color: PaperInk, weight: Double) {
        lines.append(line(CGPoint(x: x, y: top), CGPoint(x: x, y: bottom ?? height), weight, color))
    }

    mutating func dotGrid(spacing: Double) {
        let color = rule(0x6E6A62, 0.5)
        for y in stride(from: spacing, to: height, by: spacing) {
            for x in stride(from: spacing, to: width, by: spacing) {
                dots.append(PaperDot(center: CGPoint(x: x, y: y), radius: mm(0.22), color: color))
            }
        }
    }

    /// A square grid; with `every > 0`, every `every`-th line is bold.
    mutating func grid(spacing: Double, every: Int, color: PaperInk) {
        func weight(_ index: Int) -> Double {
            every > 0 && index.isMultiple(of: every) ? self.weight * 1.8 : self.weight * 0.8
        }
        for (index, x) in stride(from: 0.0, through: width, by: spacing).enumerated() {
            lines.append(line(CGPoint(x: x, y: 0), CGPoint(x: x, y: height), weight(index), color))
        }
        for (index, y) in stride(from: 0.0, through: height, by: spacing).enumerated() {
            lines.append(line(CGPoint(x: 0, y: y), CGPoint(x: width, y: y), weight(index), color))
        }
    }

    mutating func cornell() {
        let summary = height - mm(45)
        let color = rule(0x6E6A62, 0.28)
        rules(spacing: mm(7.1), top: mm(25), bottom: summary - mm(3), color: color)
        let divider = rule(0x6E6A62, 0.45)
        vertical(x: mm(50), to: summary, color: divider, weight: weight * 1.6)
        lines.append(line(CGPoint(x: 0, y: summary), CGPoint(x: width, y: summary), weight * 1.6, divider))
    }

    mutating func staves() {
        let gap = mm(2)
        let color = rule(0x6E6A62, 0.45)
        var top = mm(22)
        while top + gap * 4 < height - mm(15) {
            for index in 0..<5 {
                let y = top + gap * Double(index)
                lines.append(line(CGPoint(x: mm(12), y: y), CGPoint(x: width - mm(12), y: y), weight, color))
            }
            top += mm(18)
        }
    }

    func line(_ start: CGPoint, _ end: CGPoint, _ weight: Double, _ color: PaperInk) -> PaperLine {
        PaperLine(start: start, end: end, weight: weight, color: color)
    }
}
