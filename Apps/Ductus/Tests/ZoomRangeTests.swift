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
