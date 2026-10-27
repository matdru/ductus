import UIKit

/// How far the canvas zooms. 100% is the page fitting the view's width; fingers can zoom in to 4× that, or out until
/// about two whole pages fit on screen, which landscape needs because the page is tall and the view is wide.
struct ZoomRange: Equatable {
    static let maximumFactor = 4.0
    /// How many whole pages fit on screen when zoomed all the way out.
    static let pagesWhenZoomedOut = 2.0

    let fit: Double
    let minimum: Double
    let maximum: Double

    init(viewSize: CGSize, layout: PageLayout) {
        fit = viewSize.width / layout.contentSize.width
        maximum = fit * Self.maximumFactor
        let pageStride = layout.pageSize.height + PageLayout.gutter
        let zoomedOut = viewSize.height / (Self.pagesWhenZoomedOut * pageStride + PageLayout.gutter)
        minimum = min(zoomedOut, fit)
    }

    /// Insets that keep content smaller than the view centred in it, rather than pinned to the top left.
    static func centringInsets(content: CGSize, bounds: CGSize) -> UIEdgeInsets {
        let horizontal = max((bounds.width - content.width) / 2, 0)
        let vertical = max((bounds.height - content.height) / 2, 0)
        return UIEdgeInsets(top: vertical, left: horizontal, bottom: vertical, right: horizontal)
    }
}
