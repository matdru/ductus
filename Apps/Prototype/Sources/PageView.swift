import NotebookCore
import PencilKit
import SwiftUI

/// Ink is stored in page coordinates (2 canvas points per page point) and zoomed to whatever size the page is
/// shown at, so it stays crisp and lines up in both page-turn and scroll layouts.
enum PageGeometry {
    static let canvasPointsPerPagePoint = 2.0

    static func canvasSize(_ size: PageSize) -> CGSize {
        CGSize(width: size.width * canvasPointsPerPagePoint, height: size.height * canvasPointsPerPagePoint)
    }
}

/// One sheet: paper with a PencilKit canvas on top, plus a soft edge and shadow.
struct PageView: View {
    let model: PrototypeModel
    let notebook: Notebook
    let page: Page

    var body: some View {
        ZStack {
            PaperView(paper: notebook.paper(for: page), size: notebook.size)
            // Reading the tool here makes SwiftUI refresh the canvas when it changes.
            PageCanvas(
                model: model, pageID: page.id, canvasSize: PageGeometry.canvasSize(notebook.size), tool: model.pkTool)
        }
        .aspectRatio(notebook.size.width / notebook.size.height, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 2))
        .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
    }
}

/// A transparent `PKCanvasView` showing one page's drawing from the model.
struct PageCanvas: UIViewRepresentable {
    let model: PrototypeModel
    let pageID: UUID
    let canvasSize: CGSize
    let tool: PKTool

    func makeCoordinator() -> Coordinator { Coordinator(model: model, pageID: pageID) }

    func makeUIView(context: Context) -> ZoomingCanvasView {
        let canvas = ZoomingCanvasView(canvasSize: canvasSize)
        canvas.drawing = model.drawings[pageID] ?? PKDrawing()
        canvas.delegate = context.coordinator
        #if targetEnvironment(simulator)
            canvas.drawingPolicy = .anyInput
        #else
            canvas.drawingPolicy = .pencilOnly
        #endif
        canvas.tool = tool
        return canvas
    }

    func updateUIView(_ canvas: ZoomingCanvasView, context: Context) {
        canvas.tool = tool
    }

    @MainActor
    final class Coordinator: NSObject, PKCanvasViewDelegate {
        let model: PrototypeModel
        let pageID: UUID

        init(model: PrototypeModel, pageID: UUID) {
            self.model = model
            self.pageID = pageID
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            model.drawings[pageID] = canvasView.drawing
        }
    }
}

/// Keeps a fixed-size canvas zoomed to fill its bounds; PencilKit re-renders vector ink at every zoom.
final class ZoomingCanvasView: PKCanvasView {
    private let canvasSize: CGSize

    init(canvasSize: CGSize) {
        self.canvasSize = canvasSize
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        isScrollEnabled = false
        showsVerticalScrollIndicator = false
        showsHorizontalScrollIndicator = false
        contentInsetAdjustmentBehavior = .never
        overrideUserInterfaceStyle = .light
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0 else { return }
        let zoom = bounds.width / canvasSize.width
        if minimumZoomScale != zoom || maximumZoomScale != zoom {
            minimumZoomScale = zoom
            maximumZoomScale = zoom
            zoomScale = zoom
            contentSize = CGSize(width: canvasSize.width * zoom, height: canvasSize.height * zoom)
            contentOffset = .zero
        }
    }
}
