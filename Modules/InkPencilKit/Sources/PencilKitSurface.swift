import InkCore
import PencilKit
import UIKit

/// PencilKit-backed engine. Palm rejection, hover and Pencil hardware handling come from PKCanvasView.
@MainActor
public final class PencilKitSurface: UIView, InkSurface {
    public let canvasView = PKCanvasView()

    public var allowsFingerDrawing = false {
        didSet { canvasView.drawingPolicy = allowsFingerDrawing ? .anyInput : .pencilOnly }
    }

    public override init(frame: CGRect = .zero) {
        super.init(frame: frame)
        canvasView.frame = bounds
        canvasView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        canvasView.drawingPolicy = .pencilOnly
        canvasView.backgroundColor = .white
        canvasView.isOpaque = true
        // Match the custom engine's white page; stops PencilKit inverting ink in dark mode.
        canvasView.overrideUserInterfaceStyle = .light
        addSubview(canvasView)
        setTool(.defaultPen)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    public func clear() {
        canvasView.drawing = PKDrawing()
    }

    public func undo() {
        var drawing = canvasView.drawing
        guard !drawing.strokes.isEmpty else { return }
        drawing.strokes.removeLast()
        canvasView.drawing = drawing
    }

    public func setTool(_ tool: InkTool) {
        canvasView.tool = PKInkingTool(
            tool.kind == .highlighter ? .marker : .pen, color: UIColor(tool.color), width: tool.width)
    }

    public func load(_ strokes: [Stroke]) {
        canvasView.drawing = PKDrawing(strokes: strokes.compactMap(StrokeConversion.pkStroke(from:)))
    }

    public func exportStrokes() -> [Stroke] {
        canvasView.drawing.strokes.map { StrokeConversion.stroke(from: $0) }
    }
}
