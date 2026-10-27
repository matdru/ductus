import CoreGraphics
import NotebookCore
import PencilKit

/// Where each page sits on the notebook's single tall canvas. Canvas units are 2 per page point, so at fit-to-width
/// on an 11" iPad the zoom is close to 1 and PencilKit's ink widths look as intended.
///
/// Pages are stored separately, each in its own coordinates (canvas units, origin at the page's top left);
/// `combine` and `split` convert between those and the one drawing the canvas edits.
struct PageLayout: Equatable, Sendable {
    static let unitsPerPoint = 2.0
    /// Space around and between pages, in canvas units.
    static let gutter = 40.0

    let pageSize: CGSize
    let pageCount: Int

    init(size: PageSize, pageCount: Int) {
        pageSize = CGSize(width: size.width * Self.unitsPerPoint, height: size.height * Self.unitsPerPoint)
        self.pageCount = max(pageCount, 1)
    }

    func pageRect(_ index: Int) -> CGRect {
        CGRect(
            x: Self.gutter, y: Self.gutter + Double(index) * (pageSize.height + Self.gutter), width: pageSize.width,
            height: pageSize.height)
    }

    var contentSize: CGSize {
        CGSize(width: pageSize.width + 2 * Self.gutter, height: pageRect(pageCount - 1).maxY + Self.gutter)
    }

    /// The page nearest height `y`: each gutter is split halfway between the pages either side.
    func pageIndex(at y: Double) -> Int {
        let index = Int(((y - Self.gutter / 2) / (pageSize.height + Self.gutter)).rounded(.down))
        return min(max(index, 0), pageCount - 1)
    }

    /// One canvas drawing from per-page drawings (index-aligned; extras are ignored).
    func combine(_ pages: [PKDrawing]) -> PKDrawing {
        var combined = PKDrawing()
        for (index, page) in pages.prefix(pageCount).enumerated() {
            let origin = pageRect(index).origin
            combined.append(page.transformed(using: CGAffineTransform(translationX: origin.x, y: origin.y)))
        }
        return combined
    }

    /// Per-page drawings from the canvas drawing. A stroke belongs to the page under its centre.
    func split(_ drawing: PKDrawing) -> [PKDrawing] {
        var strokes = Array(repeating: [PKStroke](), count: pageCount)
        for stroke in drawing.strokes {
            let index = pageIndex(at: stroke.renderBounds.midY)
            let origin = pageRect(index).origin
            var local = stroke
            local.transform = stroke.transform.concatenating(CGAffineTransform(translationX: -origin.x, y: -origin.y))
            strokes[index].append(local)
        }
        return strokes.map { PKDrawing(strokes: $0) }
    }
}
