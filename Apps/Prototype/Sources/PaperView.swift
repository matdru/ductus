import NotebookCore
import SwiftUI

/// A sheet of paper at any display size. Spacing is specified in millimetres on the physical page and scaled,
/// so an A5 page shows the same number of lines however large it's drawn.
struct PaperView: View {
    let paper: Paper
    let size: PageSize
    var showsGrain = true

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / size.width
            ZStack {
                paper.color.color
                if showsGrain {
                    Image(uiImage: PaperGrain.tile)
                        .resizable(resizingMode: .tile)
                        .opacity(paper.color.isDark ? 0.25 : 0.55)
                        .blendMode(paper.color.isDark ? .screen : .multiply)
                }
                Canvas { context, canvasSize in
                    PaperRules(paper: paper, scale: scale).draw(in: &context, size: canvasSize)
                }
            }
        }
        .aspectRatio(size.width / size.height, contentMode: .fit)
    }
}

/// Rules, dots and grids for each paper type. All measurements are millimetres on the physical page.
private struct PaperRules {
    let paper: Paper
    /// Display points per page point.
    let scale: Double

    func mm(_ millimetres: Double) -> Double { PageSize.points(millimetres: millimetres) * scale }

    var ruleColor: Color {
        switch paper.type {
        case .classicLined, .legal: Color(hex: 0x8DB3DA).opacity(0.75)
        case .engineering: Color(hex: 0x5E9E6E).opacity(0.55)
        default:
            if paper.color.isDark { Color.white.opacity(0.22) } else { Color(hex: 0x6E6A62).opacity(0.32) }
        }
    }

    let marginRed = Color(hex: 0xD9626B).opacity(0.7)

    func draw(in context: inout GraphicsContext, size: CGSize) {
        let line = max(0.5, mm(0.12))
        switch paper.type {
        case .classicLined:
            rules(in: &context, size: size, spacing: mm(7.1), top: mm(25), width: line)
            vertical(in: &context, x: mm(32), size: size, color: marginRed, width: line * 1.2)
        case .fineLined:
            rules(in: &context, size: size, spacing: mm(6), top: mm(18), width: line, inset: mm(10))
        case .legal:
            rules(in: &context, size: size, spacing: mm(8.7), top: mm(30), width: line)
            vertical(in: &context, x: mm(30), size: size, color: marginRed, width: line)
            vertical(in: &context, x: mm(31.5), size: size, color: marginRed, width: line)
        case .dotGrid:
            dots(in: &context, size: size, spacing: mm(5), radius: max(0.6, mm(0.22)))
        case .squared:
            grid(in: &context, size: size, spacing: mm(5), width: line * 0.8, every: 0)
            vertical(in: &context, x: mm(20), size: size, color: marginRed, width: line)
        case .engineering:
            grid(in: &context, size: size, spacing: mm(5), width: line * 0.7, every: 5)
        case .cornell:
            rules(in: &context, size: size, spacing: mm(7.1), top: mm(25), width: line)
            vertical(in: &context, x: mm(50), size: size, color: ruleColor, width: line * 1.6)
            let summary = size.height - mm(45)
            context.fill(
                Path(CGRect(x: 0, y: summary, width: size.width, height: size.height - summary)),
                with: .color(paper.color.color))
            context.stroke(
                Path { $0.addLines([CGPoint(x: 0, y: summary), CGPoint(x: size.width, y: summary)]) },
                with: .color(ruleColor), lineWidth: line * 1.6)
        case .music:
            staves(in: &context, size: size, line: line)
        case .blank:
            break
        }
    }

    private func rules(
        in context: inout GraphicsContext, size: CGSize, spacing: Double, top: Double, width: Double,
        inset: Double = 0
    ) {
        var path = Path()
        var y = top
        while y < size.height - spacing / 2 {
            path.addLines([CGPoint(x: inset, y: y), CGPoint(x: size.width - inset, y: y)])
            y += spacing
        }
        context.stroke(path, with: .color(ruleColor), lineWidth: width)
    }

    private func vertical(in context: inout GraphicsContext, x: Double, size: CGSize, color: Color, width: Double) {
        context.stroke(
            Path { $0.addLines([CGPoint(x: x, y: 0), CGPoint(x: x, y: size.height)]) },
            with: .color(color), lineWidth: width)
    }

    private func dots(in context: inout GraphicsContext, size: CGSize, spacing: Double, radius: Double) {
        var path = Path()
        var y = spacing
        while y < size.height {
            var x = spacing
            while x < size.width {
                path.addEllipse(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
                x += spacing
            }
            y += spacing
        }
        context.fill(path, with: .color(ruleColor.opacity(1.6)))
    }

    private func grid(in context: inout GraphicsContext, size: CGSize, spacing: Double, width: Double, every: Int) {
        var minor = Path()
        var major = Path()
        func add(_ points: [CGPoint], index: Int) {
            if every > 0 && index % every == 0 { major.addLines(points) } else { minor.addLines(points) }
        }
        for (index, x) in stride(from: 0.0, through: size.width, by: spacing).enumerated() {
            add([CGPoint(x: x, y: 0), CGPoint(x: x, y: size.height)], index: index)
        }
        for (index, y) in stride(from: 0.0, through: size.height, by: spacing).enumerated() {
            add([CGPoint(x: 0, y: y), CGPoint(x: size.width, y: y)], index: index)
        }
        context.stroke(minor, with: .color(ruleColor), lineWidth: width)
        context.stroke(major, with: .color(ruleColor.opacity(1.5)), lineWidth: width * 1.8)
    }

    private func staves(in context: inout GraphicsContext, size: CGSize, line: Double) {
        var path = Path()
        var top = mm(22)
        let gap = mm(2)
        while top + gap * 4 < size.height - mm(15) {
            for index in 0..<5 {
                let y = top + gap * Double(index)
                path.addLines([CGPoint(x: mm(12), y: y), CGPoint(x: size.width - mm(12), y: y)])
            }
            top += mm(18)
        }
        context.stroke(path, with: .color(ruleColor.opacity(1.4)), lineWidth: line)
    }
}

/// A small tile of random speckles, generated once, multiplied over the paper colour to suggest grain.
enum PaperGrain {
    static let tile: UIImage = {
        let side = 192.0
        var generator = SystemRandomNumberGenerator()
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { context in
            for _ in 0..<2_400 {
                let x = Double.random(in: 0..<side, using: &generator)
                let y = Double.random(in: 0..<side, using: &generator)
                let shade = Double.random(in: 0.55...0.9, using: &generator)
                UIColor(white: shade, alpha: Double.random(in: 0.04...0.12, using: &generator)).setFill()
                let dot = Double.random(in: 0.4...1.3, using: &generator)
                context.fill(CGRect(x: x, y: y, width: dot, height: dot))
            }
        }
    }()
}
