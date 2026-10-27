import CoreGraphics
import NotebookCore
import Testing
import UIKit

@testable import Ductus

struct ZoomRangeTests {
    let layout = PageLayout(size: .a5, pageCount: 3)
    let landscape = CGSize(width: 1376, height: 950)
    let portrait = CGSize(width: 1032, height: 1300)

    @Test func fitIsPageWidth() {
        let range = ZoomRange(viewSize: landscape, layout: layout)
        #expect(abs(range.fit - landscape.width / layout.contentSize.width) < 0.0001)
        #expect(abs(range.maximum - range.fit * 4) < 0.0001)
    }

    @Test func landscapeZoomsOutPastAWholePage() {
        let range = ZoomRange(viewSize: landscape, layout: layout)
        let wholePage = landscape.height / (layout.pageSize.height + 2 * PageLayout.gutter)
        #expect(range.minimum < wholePage)
        #expect(range.minimum < range.fit / 2)
        // Zoomed all the way out, about two pages fit on screen.
        let pagesOnScreen = landscape.height / (range.minimum * (layout.pageSize.height + PageLayout.gutter))
        #expect(pagesOnScreen > 1.8 && pagesOnScreen < 2.5)
    }

    @Test func portraitAlsoZoomsOut() {
        let range = ZoomRange(viewSize: portrait, layout: layout)
        #expect(range.minimum < range.fit * 0.6)
    }

    @Test func landscapeOpensAt80Percent() {
        let range = ZoomRange(viewSize: landscape, layout: layout)
        #expect(abs(range.initial - range.fit * 0.8) < 0.0001)
    }

    @Test func portraitOpensAtPageWidth() {
        let range = ZoomRange(viewSize: portrait, layout: layout)
        #expect(range.initial == range.fit)
    }

    @Test func initialZoomNeverGoesBelowTheMinimum() {
        // A very short, wide view: zoomed all the way out is above 80%.
        let range = ZoomRange(viewSize: CGSize(width: 1400, height: 3000), layout: PageLayout(size: .a5, pageCount: 1))
        #expect(range.initial >= range.minimum)
        let wide = ZoomRange(viewSize: CGSize(width: 3000, height: 300), layout: layout)
        #expect(wide.initial >= wide.minimum)
    }

    @Test func opensAtTheStartingZoom() {
        let range = ZoomRange(viewSize: landscape, layout: layout)
        #expect(range.zoom(afterResizingFrom: nil, at: 1) == range.initial)
    }

    @Test func rotatingAtTheStartingZoomTakesTheNewOrientationsStart() {
        let wide = ZoomRange(viewSize: landscape, layout: layout)
        let tall = ZoomRange(viewSize: portrait, layout: layout)
        #expect(tall.zoom(afterResizingFrom: wide, at: wide.initial) == tall.initial)
        #expect(wide.zoom(afterResizingFrom: tall, at: tall.initial) == wide.initial)
    }

    /// Zoom is kept relative to each orientation's start: 80% in landscape is 100% in portrait.
    @Test func rotatingKeepsZoomRelativeToTheStart() {
        let wide = ZoomRange(viewSize: landscape, layout: layout)
        let tall = ZoomRange(viewSize: portrait, layout: layout)
        // 120% of page width in landscape (1.5× its start) is 150% in portrait.
        let zoom = tall.zoom(afterResizingFrom: wide, at: wide.fit * 1.2)
        #expect(abs(zoom / tall.fit - 1.5) < 0.0001)
        // And back again.
        let back = wide.zoom(afterResizingFrom: tall, at: zoom)
        #expect(abs(back / wide.fit - 1.2) < 0.0001)
    }

    @Test func narrowContentIsCentred() {
        let insets = ZoomRange.centringInsets(content: CGSize(width: 400, height: 3000), bounds: landscape)
        #expect(abs(insets.left - (landscape.width - 400) / 2) < 0.0001)
        #expect(insets.left == insets.right)
        #expect(insets.top == 0 && insets.bottom == 0)
    }

    @Test func shortContentIsCentredVertically() {
        let insets = ZoomRange.centringInsets(content: CGSize(width: 2000, height: 500), bounds: landscape)
        #expect(insets.left == 0)
        #expect(abs(insets.top - (landscape.height - 500) / 2) < 0.0001)
    }
}
