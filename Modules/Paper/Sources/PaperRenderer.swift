import CoreGraphics
import NotebookCore

/// Draws a `PaperLayout` with Core Graphics. Vector all the way, so it's crisp at any zoom.
public enum PaperRenderer {
    /// Draws the page into `context`, whose user space is page points with a top-left origin. Only marks that
    /// intersect `dirty` (page points) are drawn, so tiled views redraw cheaply.
    public static func draw(_ layout: PaperLayout, in context: CGContext, pageSize: CGSize, dirty: CGRect? = nil) {
        let clip = dirty ?? CGRect(origin: .zero, size: pageSize)
        context.setFillColor(cgColor(layout.background, alpha: 1))
        context.fill(clip.intersection(CGRect(origin: .zero, size: pageSize)))
        context.setLineCap(.butt)
        for line in layout.lines {
            let box = CGRect(
                x: min(line.start.x, line.end.x), y: min(line.start.y, line.end.y),
                width: abs(line.end.x - line.start.x), height: abs(line.end.y - line.start.y)
            ).insetBy(dx: -line.weight, dy: -line.weight)
            guard box.intersects(clip) else { continue }
            context.setStrokeColor(cgColor(line.color.hex, alpha: line.color.alpha))
            context.setLineWidth(line.weight)
            context.move(to: line.start)
            context.addLine(to: line.end)
            context.strokePath()
        }
        for dot in layout.dots {
            let box = CGRect(
                x: dot.center.x - dot.radius, y: dot.center.y - dot.radius, width: dot.radius * 2,
                height: dot.radius * 2)
            guard box.intersects(clip) else { continue }
            context.setFillColor(cgColor(dot.color.hex, alpha: dot.color.alpha))
            context.fillEllipse(in: box)
        }
    }

    /// The whole page as an image, `scale` pixels per page point (thumbnails, tests).
    public static func image(paper: Paper, size: PageSize, scale: Double) -> CGImage? {
        let pixelWidth = Int((size.width * scale).rounded(.up))
        let pixelHeight = Int((size.height * scale).rounded(.up))
        guard
            let context = CGContext(
                data: nil, width: pixelWidth, height: pixelHeight, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        // Flip to a top-left origin in page points.
        context.translateBy(x: 0, y: Double(pixelHeight))
        context.scaleBy(x: scale, y: -scale)
        draw(
            PaperLayout(paper: paper, size: size), in: context, pageSize: CGSize(width: size.width, height: size.height)
        )
        return context.makeImage()
    }

    public static func cgColor(_ hex: UInt32, alpha: Double) -> CGColor {
        CGColor(
            srgbRed: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255, alpha: alpha)
    }
}
