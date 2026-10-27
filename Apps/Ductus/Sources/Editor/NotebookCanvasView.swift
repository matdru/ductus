import DesignSystem
import NotebookCore
import Paper
import PencilKit
import SwiftUI
import UIKit

/// Lets SwiftUI chrome drive the canvas (undo, redo, scrolling) and read its zoom and visible page.
@MainActor @Observable
final class CanvasController {
    fileprivate(set) var zoomPercent = 100
    fileprivate weak var canvas: PKCanvasView?
    fileprivate var scrollToPageHandler: ((Int) -> Void)?

    func undo() { canvas?.undoManager?.undo() }
    func redo() { canvas?.undoManager?.redo() }
    func scroll(toPage index: Int) { scrollToPageHandler?(index) }
}

/// The notebook's single tall PencilKit canvas. Fingers scroll and pinch-zoom (see `ZoomRange`); the Pencil writes. Paper is drawn underneath by a tiled layer, redrawn sharp at every zoom.
struct NotebookCanvasView: UIViewRepresentable {
    let model: EditorModel
    let controller: CanvasController
    let gutterColor: ThemeColor
    let hairlineColor: ThemeColor

    func makeCoordinator() -> NotebookCanvas { NotebookCanvas(model: model, controller: controller) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = context.coordinator.canvas
        context.coordinator.apply(gutter: gutterColor, hairline: hairlineColor)
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.sync(tool: model.tool, layout: model.layout, revision: model.revision)
        context.coordinator.apply(gutter: gutterColor, hairline: hairlineColor)
    }
}

/// Owns the PKCanvasView and its paper underlay, and keeps zoom, content size and page tracking in step.
@MainActor
final class NotebookCanvas: NSObject, PKCanvasViewDelegate {
    let canvas = LayoutReportingCanvasView()
    private let underlay = PaperUnderlayView()
    private let model: EditorModel
    private let controller: CanvasController
    private var layout: PageLayout
    private var appliedRevision = -1
    private var isApplyingModel = false
    private var zoom: ZoomRange?

    init(model: EditorModel, controller: CanvasController) {
        self.model = model
        self.controller = controller
        layout = model.layout
        super.init()
        canvas.delegate = self
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.contentInsetAdjustmentBehavior = .never
        canvas.alwaysBounceVertical = true
        // Ink is content: keep PencilKit from inverting it in dark mode; the paper stays light.
        canvas.overrideUserInterfaceStyle = .light
        #if targetEnvironment(simulator)
            canvas.drawingPolicy = .anyInput
        #else
            canvas.drawingPolicy = .pencilOnly
        #endif
        canvas.insertSubview(underlay, at: 0)
        underlay.configure(notebook: model.notebook, layout: layout)
        controller.canvas = canvas
        controller.scrollToPageHandler = { [weak self] index in self?.scroll(toPage: index, animated: true) }
        canvas.onLayout = { [weak self] in self?.layoutChanged() }
    }

    func apply(gutter: ThemeColor, hairline: ThemeColor) {
        underlay.setColors(
            gutter: gutter.uiColor.resolvedColor(with: canvas.superview?.traitCollection ?? canvas.traitCollection),
            hairline: hairline.uiColor.resolvedColor(with: canvas.superview?.traitCollection ?? canvas.traitCollection))
    }

    func sync(tool: EditorTool, layout newLayout: PageLayout, revision: Int) {
        canvas.tool = tool.pkTool
        if newLayout != layout {
            layout = newLayout
            underlay.configure(notebook: model.notebook, layout: layout)
            updateContentSize()
        }
        if revision != appliedRevision {
            appliedRevision = revision
            isApplyingModel = true
            canvas.drawing = model.drawing
            isApplyingModel = false
        }
    }

    private func layoutChanged() {
        guard canvas.bounds.width > 0, canvas.bounds.height > 0 else { return }
        let newZoom = ZoomRange(viewSize: canvas.bounds.size, layout: layout)
        guard newZoom != zoom else {
            centreContent()
            return
        }
        let relative = zoom.map { canvas.zoomScale / $0.fit } ?? 1
        let firstLayout = zoom == nil
        zoom = newZoom
        canvas.minimumZoomScale = newZoom.minimum
        canvas.maximumZoomScale = newZoom.maximum
        canvas.zoomScale = min(max(newZoom.fit * relative, newZoom.minimum), newZoom.maximum)
        updateContentSize()
        if firstLayout { scroll(toPage: model.currentPage, animated: false) }
    }

    private func updateContentSize() {
        let scale = canvas.zoomScale
        let size = CGSize(width: layout.contentSize.width * scale, height: layout.contentSize.height * scale)
        canvas.contentSize = size
        underlay.setZoom(scale)
        controller.zoomPercent = Int((scale / max(zoom?.fit ?? 1, 0.0001) * 100).rounded())
        centreContent()
    }

    /// Zoomed out past the page width, the page sits in the middle of the screen, not against its left edge.
    private func centreContent() {
        let insets = ZoomRange.centringInsets(content: canvas.contentSize, bounds: canvas.bounds.size)
        if insets != canvas.contentInset { canvas.contentInset = insets }
    }

    private func scroll(toPage index: Int, animated: Bool) {
        let top = (layout.pageRect(index).minY - PageLayout.gutter / 2) * canvas.zoomScale
        let minOffset = -canvas.contentInset.top
        let maxOffset = max(canvas.contentSize.height - canvas.bounds.height + canvas.contentInset.bottom, minOffset)
        canvas.setContentOffset(
            CGPoint(x: canvas.contentOffset.x, y: min(max(top, minOffset), maxOffset)), animated: animated)
    }

    // MARK: PKCanvasViewDelegate

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        guard !isApplyingModel else { return }
        model.drawingChanged(canvasView.drawing)
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateContentSize()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let zoom = max(scrollView.zoomScale, 0.0001)
        let centre = (scrollView.contentOffset.y + scrollView.bounds.height / 2) / zoom
        let page = layout.pageIndex(at: centre)
        if page != model.currentPage { model.currentPage = page }
    }
}

/// A PKCanvasView that reports layout passes (size changes, rotation), so zoom can be refitted.
final class LayoutReportingCanvasView: PKCanvasView {
    var onLayout: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}
