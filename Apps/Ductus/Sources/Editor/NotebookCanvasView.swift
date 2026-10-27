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
    fileprivate(set) var canUndo = false
    fileprivate(set) var canRedo = false
    fileprivate weak var canvas: NotebookCanvas?

    func undo() { canvas?.undo(source: "button") }
    func redo() { canvas?.redo(source: "button") }
    func scroll(toPage index: Int) { canvas?.scroll(toPage: index, animated: true) }
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
final class NotebookCanvas: NSObject, PKCanvasViewDelegate, UIPencilInteractionDelegate {
    let canvas = LayoutReportingCanvasView()
    private let underlay = PaperUnderlayView()
    private let model: EditorModel
    private let controller: CanvasController
    private var layout: PageLayout
    private var appliedRevision = -1
    private var isApplyingModel = false
    private var zoom: ZoomRange?
    private var fingerTap: FingerTap?

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
        controller.canvas = self
        canvas.onLayout = { [weak self] in self?.layoutChanged() }
        canvas.addInteraction(UIPencilInteraction(delegate: self))
        fingerTap = FingerTap(
            on: canvas, undo: { [weak self] in self?.undo(source: "twoFingerTap") },
            redo: { [weak self] in self?.redo(source: "threeFingerTap") })
        for name in [
            NSNotification.Name.NSUndoManagerDidCloseUndoGroup, .NSUndoManagerDidUndoChange,
            .NSUndoManagerDidRedoChange,
            .NSUndoManagerCheckpoint,
        ] {
            NotificationCenter.default.addObserver(self, selector: #selector(undoStateChanged), name: name, object: nil)
        }
    }

    // MARK: Undo

    /// Undoes the last change; if it was off screen, scrolls there so it's never a surprise on an unseen page.
    func undo(source: String) { reveal("undo", source: source) { $0.undo() } }
    func redo(source: String) { reveal("redo", source: source) { $0.redo() } }

    private func reveal(_ name: String, source: String, _ step: (UndoManager) -> Void) {
        guard let undoManager = canvas.undoManager else { return }
        let before = canvas.drawing
        let available = name == "undo" ? undoManager.canUndo : undoManager.canRedo
        let action = name == "undo" ? undoManager.undoActionName : undoManager.redoActionName
        step(undoManager)
        let change = DrawingChange.bounds(from: before, to: canvas.drawing)
        TouchRecorder.event(
            name,
            [
                "source": source, "available": String(available), "action": action,
                "changed": change.map { "\(Int($0.minX)),\(Int($0.minY)) \(Int($0.width))×\(Int($0.height))" }
                    ?? "none",
            ])
        guard let change else { return }
        let zoom = canvas.zoomScale
        let visible = CGRect(
            x: canvas.contentOffset.x / zoom, y: canvas.contentOffset.y / zoom, width: canvas.bounds.width / zoom,
            height: canvas.bounds.height / zoom)
        guard !visible.intersects(change) else { return }
        let inset = canvas.contentInset
        let x = min(
            max(change.midX * zoom - canvas.bounds.width / 2, -inset.left),
            max(canvas.contentSize.width - canvas.bounds.width + inset.right, -inset.left))
        let y = min(
            max(change.midY * zoom - canvas.bounds.height / 2, -inset.top),
            max(canvas.contentSize.height - canvas.bounds.height + inset.bottom, -inset.top))
        canvas.setContentOffset(CGPoint(x: x, y: y), animated: true)
    }

    @objc private func undoStateChanged(_ notification: Notification) {
        guard let undoManager = canvas.undoManager, notification.object as? UndoManager === undoManager else { return }
        if model.undoManager !== undoManager { model.undoManager = undoManager }
        controller.canUndo = undoManager.canUndo
        controller.canRedo = undoManager.canRedo
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
        if let undoManager = canvas.undoManager, model.undoManager !== undoManager { model.undoManager = undoManager }
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

    func scroll(toPage index: Int, animated: Bool) {
        let top = (layout.pageRect(index).minY - PageLayout.gutter / 2) * canvas.zoomScale
        let minOffset = -canvas.contentInset.top
        let maxOffset = max(canvas.contentSize.height - canvas.bounds.height + canvas.contentInset.bottom, minOffset)
        canvas.setContentOffset(
            CGPoint(x: canvas.contentOffset.x, y: min(max(top, minOffset), maxOffset)), animated: animated)
    }

    // MARK: PKCanvasViewDelegate

    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        guard !isApplyingModel else { return }
        TouchRecorder.event("drawingChanged", ["strokes": String(canvasView.drawing.strokes.count)])
        model.drawingChanged(canvasView.drawing)
    }

    // MARK: UIPencilInteractionDelegate

    func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveTap tap: UIPencilInteraction.Tap) {
        let action = PencilTapAction(UIPencilInteraction.preferredTapAction)
        model.pencilTapped(action)
        TouchRecorder.event("pencilTap", ["action": "\(action)", "tool": "\(model.tool.kind)"])
    }

    // MARK: UIScrollViewDelegate

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
