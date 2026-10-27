import NotebookCore
import PencilKit
import Testing

@testable import Ductus

@MainActor
struct PageLayoutTests {
    let layout = PageLayout(size: .a5, pageCount: 3)

    /// A short horizontal stroke centred on `point` (canvas units).
    func stroke(at point: CGPoint) -> PKStroke {
        let points = (0..<5).map { i in
            PKStrokePoint(
                location: CGPoint(x: point.x - 10 + Double(i) * 5, y: point.y), timeOffset: Double(i) * 0.01,
                size: CGSize(width: 3, height: 3), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKStroke(
            ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date()))
    }

    @Test func pagesStackVerticallyWithGutters() {
        let page = layout.pageSize
        #expect(abs(page.width - PageSize.a5.width * 2) < 0.001)
        let first = layout.pageRect(0)
        let second = layout.pageRect(1)
        #expect(first.minX == PageLayout.gutter && first.minY == PageLayout.gutter)
        #expect(abs(second.minY - (first.maxY + PageLayout.gutter)) < 0.001)
        #expect(abs(layout.contentSize.height - (layout.pageRect(2).maxY + PageLayout.gutter)) < 0.001)
        #expect(abs(layout.contentSize.width - (page.width + 2 * PageLayout.gutter)) < 0.001)
    }

    @Test func pageIndexAtYIsClamped() {
        #expect(layout.pageIndex(at: -100) == 0)
        #expect(layout.pageIndex(at: layout.pageRect(1).midY) == 1)
        #expect(layout.pageIndex(at: layout.pageRect(1).maxY + PageLayout.gutter / 4) == 1)
        #expect(layout.pageIndex(at: 1e9) == 2)
    }

    @Test func splitPutsEachStrokeOnItsPageInPageCoordinates() throws {
        let onSecond = CGPoint(x: 200, y: layout.pageRect(1).minY + 100)
        let drawing = PKDrawing(strokes: [stroke(at: onSecond)])
        let pages = layout.split(drawing)
        #expect(pages.count == 3)
        #expect(pages[0].strokes.isEmpty && pages[2].strokes.isEmpty)
        let local = try #require(pages[1].strokes.first).renderBounds
        #expect(abs(local.midY - 100) < 1)
        #expect(abs(local.midX - (200 - PageLayout.gutter)) < 1)
    }

    @Test func combineThenSplitRoundTrips() {
        let pageDrawings = [
            PKDrawing(strokes: [stroke(at: CGPoint(x: 50, y: 60))]),
            PKDrawing(),
            PKDrawing(strokes: [stroke(at: CGPoint(x: 300, y: 500)), stroke(at: CGPoint(x: 100, y: 40))]),
        ]
        let roundTripped = layout.split(layout.combine(pageDrawings))
        for (before, after) in zip(pageDrawings, roundTripped) {
            #expect(before.strokes.count == after.strokes.count)
            for (a, b) in zip(before.strokes, after.strokes) {
                #expect(abs(a.renderBounds.midX - b.renderBounds.midX) < 0.5)
                #expect(abs(a.renderBounds.midY - b.renderBounds.midY) < 0.5)
            }
        }
    }

    @Test func strokesCrossingPagesGoWhereTheirCentreIs() {
        let boundary = layout.pageRect(0).maxY
        let drawing = PKDrawing(strokes: [stroke(at: CGPoint(x: 100, y: boundary + 30))])
        #expect(layout.split(drawing)[1].strokes.count == 1)
    }

    @Test func combineIgnoresExtraDrawings() {
        let drawings = Array(repeating: PKDrawing(strokes: [stroke(at: CGPoint(x: 50, y: 50))]), count: 5)
        #expect(layout.combine(drawings).strokes.count == 3)
    }
}
