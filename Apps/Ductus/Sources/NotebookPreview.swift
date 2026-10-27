import DesignSystem
import NotebookCore
import SwiftUI

extension Notebook {
    /// The notebook's colour in the current theme.
    func tint(in theme: Theme) -> ThemeColor {
        theme.colors.notebook(NotebookColor(rawValue: cover.colorName) ?? .ink)
    }
}

extension PaperColor {
    /// Paper is content, so it keeps its own colour in every theme.
    var swatch: Color { RGBA(hex: hex).color }
}

extension PaperType {
    var displayName: String {
        switch self {
        case .classicLined: "Classic Lined"
        case .fineLined: "Fine Lined"
        case .dotGrid: "Dot Grid"
        case .squared: "Squared"
        case .engineering: "Engineering"
        case .legal: "Legal Pad"
        case .blank: "Blank"
        case .cornell: "Cornell"
        case .music: "Music"
        }
    }
}

/// A glimpse of a notebook's paper: colour and rule pattern. Real page thumbnails replace this with DRU-43.
struct PaperGlimpse: View {
    let paper: Paper

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(paper.color.swatch))
            let isDark = paper.color == .charcoal
            let rule = RGBA(hex: isDark ? 0xFFFFFF : 0x000000, alpha: isDark ? 0.18 : 0.14).color
            var path = Path()
            switch paper.type {
            case .classicLined, .fineLined, .legal, .cornell:
                for y in stride(from: 16.0, to: size.height, by: 12) {
                    path.addLines([CGPoint(x: 0, y: y), CGPoint(x: size.width, y: y)])
                }
                context.stroke(path, with: .color(rule), lineWidth: 0.75)
            case .squared, .engineering:
                for x in stride(from: 0.0, to: size.width, by: 9) {
                    path.addLines([CGPoint(x: x, y: 0), CGPoint(x: x, y: size.height)])
                }
                for y in stride(from: 0.0, to: size.height, by: 9) {
                    path.addLines([CGPoint(x: 0, y: y), CGPoint(x: size.width, y: y)])
                }
                context.stroke(path, with: .color(rule), lineWidth: 0.5)
            case .dotGrid:
                for y in stride(from: 9.0, to: size.height, by: 9) {
                    for x in stride(from: 9.0, to: size.width, by: 9) {
                        path.addEllipse(in: CGRect(x: x - 0.8, y: y - 0.8, width: 1.6, height: 1.6))
                    }
                }
                context.fill(path, with: .color(rule.opacity(2)))
            case .music:
                for top in stride(from: 14.0, to: size.height - 12, by: 22) {
                    for line in 0..<5 {
                        let y = top + Double(line) * 2.5
                        path.addLines([CGPoint(x: 6, y: y), CGPoint(x: size.width - 6, y: y)])
                    }
                }
                context.stroke(path, with: .color(rule), lineWidth: 0.5)
            case .blank:
                break
            }
        }
    }
}

/// A recent-notebook card: paper glimpse, colour swatch, title and current page count.
struct NotebookCard: View {
    let notebook: Notebook
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaperGlimpse(paper: notebook.paper)
                .frame(height: 132)
                .overlay(alignment: .bottom) { Rectangle().fill(theme.colors.hairline).frame(height: 1) }
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(notebook.tint(in: theme)).frame(width: 8, height: 8)
                Text(notebook.title).style(theme.typography.headline).foregroundStyle(theme.colors.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("\(notebook.pages.count)p").style(theme.typography.mono).foregroundStyle(
                    theme.colors.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(theme.colors.surface)
        .clipShape(.rect(cornerRadius: theme.metrics.radiusMedium))
        .overlay(RoundedRectangle(cornerRadius: theme.metrics.radiusMedium).stroke(theme.colors.hairline))
        .contentShape(.rect(cornerRadius: theme.metrics.radiusMedium))
    }
}
