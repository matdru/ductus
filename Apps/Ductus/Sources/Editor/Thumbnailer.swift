import NotebookCore
import Paper
import PencilKit
import UIKit

/// Renders a page preview (paper plus ink) for the library. Safe to call off the main thread.
enum Thumbnailer {
    /// Thumbnail width in pixels.
    static let width = 360.0

    static func png(drawingData: Data, paper: NotebookCore.Paper, size: PageSize) -> Data? {
        guard let drawing = try? PKDrawing(data: drawingData) else { return nil }
        let pageSize = CGSize(width: size.width, height: size.height)
        let scale = width / pageSize.width
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: width, height: (pageSize.height * scale).rounded()), format: format)
        let image = renderer.image { context in
            context.cgContext.scaleBy(x: scale, y: scale)
            PaperRenderer.draw(PaperLayout(paper: paper, size: size), in: context.cgContext, pageSize: pageSize)
            // Page drawings are in canvas units (2 per page point), with the origin at the page's top left.
            let canvasRect = CGRect(
                x: 0, y: 0, width: pageSize.width * PageLayout.unitsPerPoint,
                height: pageSize.height * PageLayout.unitsPerPoint)
            let ink = drawing.image(from: canvasRect, scale: scale / PageLayout.unitsPerPoint)
            ink.draw(in: CGRect(origin: .zero, size: pageSize))
        }
        return image.pngData()
    }
}
