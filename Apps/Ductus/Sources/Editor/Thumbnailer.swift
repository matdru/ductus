import NotebookCore
import Paper
import PencilKit
import UIKit

/// Renders a page's library preview: not the whole page shrunk (handwriting would be unreadable), but a close-up of
/// the last lines written on it, at about the size they are on paper. Safe to call off the main thread.
enum Thumbnailer {
    /// Width over height, roughly a library card's preview area.
    static let aspect = 2.4
    /// How much of the page the crop shows across, in page points: close to the card's own width, so writing is
    /// shown near life size.
    static let cropWidth = 280.0
    /// Thumbnail width in pixels.
    static let width = 720.0

    /// Where a stroke is (canvas units, page coordinates) and when it was written.
    struct Ink {
        var bounds: CGRect
        var created: Date
    }

    static func png(drawingData: Data, paper: NotebookCore.Paper, size: PageSize) -> Data? {
        guard let drawing = try? PKDrawing(data: drawingData) else { return nil }
        let pageSize = CGSize(width: size.width, height: size.height)
        let canvasPage = CGSize(
            width: pageSize.width * PageLayout.unitsPerPoint, height: pageSize.height * PageLayout.unitsPerPoint)
        let ink = drawing.strokes.map { Ink(bounds: $0.renderBounds, created: $0.path.creationDate) }
        let crop = crop(for: ink, pageSize: canvasPage)
        // Pixels per canvas unit.
        let scale = width / crop.width
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: width, height: (crop.height * scale).rounded()), format: format)
        let image = renderer.image { context in
            let cg = context.cgContext
            cg.saveGState()
            cg.scaleBy(x: scale * PageLayout.unitsPerPoint, y: scale * PageLayout.unitsPerPoint)
            cg.translateBy(x: -crop.minX / PageLayout.unitsPerPoint, y: -crop.minY / PageLayout.unitsPerPoint)
            PaperRenderer.draw(PaperLayout(paper: paper, size: size), in: cg, pageSize: pageSize)
            cg.restoreGState()
            // PencilKit inverts ink for dark mode; the thumbnail is light paper, so render it as light.
            var ink = UIImage()
            UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
                ink = drawing.image(from: crop, scale: scale)
            }
            ink.draw(in: CGRect(origin: .zero, size: context.format.bounds.size))
        }
        return image.pngData()
    }

    /// The part of the page to show, in canvas units: the most recent strokes that fit in one card-shaped window,
    /// centred, kept on the page. A blank page shows its top left.
    static func crop(for ink: [Ink], pageSize: CGSize) -> CGRect {
        let width = min(cropWidth * PageLayout.unitsPerPoint, pageSize.width)
        let window = CGSize(width: width, height: width / aspect)
        var recent: CGRect?
        for stroke in ink.sorted(by: { $0.created > $1.created }) {
            guard let union = recent?.union(stroke.bounds) else {
                recent = stroke.bounds
                continue
            }
            guard union.width <= window.width, union.height <= window.height else { break }
            recent = union
        }
        guard let recent else { return CGRect(origin: .zero, size: window) }
        let x = min(max(recent.midX - window.width / 2, 0), max(pageSize.width - window.width, 0))
        let y = min(max(recent.midY - window.height / 2, 0), max(pageSize.height - window.height, 0))
        return CGRect(origin: CGPoint(x: x, y: y), size: window)
    }
}
