import NotebookCore
import Paper
import UIKit

/// The pages' paper, drawn behind the ink. Its size tracks the zoomed content; a tiled layer draws only visible
/// tiles, on background threads, so tall notebooks stay cheap and lines stay sharp at every zoom.
final class PaperUnderlayView: UIView {
    override static var layerClass: AnyClass { PaperTiledLayer.self }
    // swiftlint:disable:next force_cast
    private var tiledLayer: PaperTiledLayer { layer as! PaperTiledLayer }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isOpaque = true
        tiledLayer.tileSize = CGSize(width: 512, height: 512)
        tiledLayer.levelsOfDetail = 1
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        tiledLayer.contentsScale = window?.screen.scale ?? 2
    }

    func configure(notebook: Notebook, layout: PageLayout) {
        let papers = notebook.pages.map { PaperLayout(paper: notebook.paper(for: $0), size: notebook.size) }
        tiledLayer.update {
            $0.pages = papers
            $0.layout = layout
            $0.pageSize = notebook.size
        }
    }

    func setZoom(_ zoom: Double) {
        tiledLayer.update { $0.zoom = zoom }
    }

    func setColors(gutter: UIColor, hairline: UIColor) {
        tiledLayer.update {
            $0.gutter = gutter.cgColor
            $0.hairline = hairline.cgColor
        }
    }
}

/// Draws paper tiles. CATiledLayer calls `draw(in:)` on background threads, so everything it reads is an immutable
/// snapshot swapped under a lock.
final class PaperTiledLayer: CATiledLayer, @unchecked Sendable {
    struct Snapshot {
        var pages: [PaperLayout] = []
        var layout = PageLayout(size: .a5, pageCount: 1)
        var pageSize = PageSize.a5
        var zoom = 1.0
        var gutter = CGColor(gray: 0.95, alpha: 1)
        var hairline = CGColor(gray: 0.85, alpha: 1)
    }

    private let lock = NSLock()
    private var snapshot = Snapshot()

    override init() {
        super.init()
    }

    /// Core Animation copies layers for presentation; the copy needs the same snapshot.
    override init(layer: Any) {
        super.init(layer: layer)
        if let other = layer as? PaperTiledLayer {
            other.lock.lock()
            snapshot = other.snapshot
            other.lock.unlock()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override class func fadeDuration() -> CFTimeInterval { 0 }

    func update(_ change: (inout Snapshot) -> Void) {
        lock.lock()
        change(&snapshot)
        lock.unlock()
        setNeedsDisplay()
    }

    override func draw(in context: CGContext) {
        lock.lock()
        let state = snapshot
        lock.unlock()
        let dirty = context.boundingBoxOfClipPath
        context.setFillColor(state.gutter)
        context.fill(dirty)
        let pageSize = CGSize(width: state.pageSize.width, height: state.pageSize.height)
        // Layer points per page point.
        let scale = state.zoom * PageLayout.unitsPerPoint
        for (index, paper) in state.pages.enumerated() {
            let rect = state.layout.pageRect(index)
            let onScreen = CGRect(
                x: rect.minX * state.zoom, y: rect.minY * state.zoom, width: rect.width * state.zoom,
                height: rect.height * state.zoom)
            guard onScreen.intersects(dirty) else { continue }
            context.saveGState()
            context.translateBy(x: onScreen.minX, y: onScreen.minY)
            context.scaleBy(x: scale, y: scale)
            let localDirty = dirty.offsetBy(dx: -onScreen.minX, dy: -onScreen.minY)
                .applying(CGAffineTransform(scaleX: 1 / scale, y: 1 / scale))
            PaperRenderer.draw(paper, in: context, pageSize: pageSize, dirty: localDirty)
            context.restoreGState()
            context.setStrokeColor(state.hairline)
            context.setLineWidth(1)
            context.stroke(onScreen.insetBy(dx: -0.5, dy: -0.5))
        }
    }
}
