import InkCore
import PencilKit
import UIKit

/// PencilKit-backed engine. Palm rejection, hover and Pencil hardware handling come from PKCanvasView.
@MainActor
public final class PencilKitSurface: UIView, InkSurface {
    public let canvasView = PKCanvasView()

    /// PencilKit's built-in inks and erasers, for exploring them in Feel Lab.
    public static let tools: [PencilKitTool] =
        [PKInk.InkType.pen, .pencil, .marker, .monoline, .fountainPen, .watercolor, .crayon, .reed].map(
            PencilKitTool.ink) + [.eraser(.bitmap), .eraser(.vector)]

    /// Pen inks and erasers replace the pen; a highlighter `InkTool` always draws `.marker`.
    public var selectedTool: PencilKitTool = .ink(.pen) {
        didSet { applyTool() }
    }

    private var tool = InkTool.defaultPen

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
        self.tool = tool
        applyTool()
    }

    /// `.pen` keeps the tool's width so it matches the custom engine; other inks use Apple's default width.
    private func applyTool() {
        let inkType: PKInk.InkType
        switch selectedTool {
        case .ink(let selected): inkType = selected
        case .eraser(let eraserType):
            canvasView.tool = PKEraserTool(eraserType)
            return
        }
        let type: PKInk.InkType = tool.kind == .highlighter ? .marker : inkType
        let width = tool.kind == .highlighter || type == .pen ? tool.width : type.defaultWidth
        canvasView.tool = PKInkingTool(type, color: UIColor(tool.color), width: width)
    }

    public func load(_ strokes: [Stroke]) {
        canvasView.drawing = PKDrawing(strokes: strokes.compactMap(StrokeConversion.pkStroke(from:)))
    }

    public func exportStrokes() -> [Stroke] {
        canvasView.drawing.strokes.map { StrokeConversion.stroke(from: $0) }
    }
}

public enum PencilKitTool: Hashable {
    case ink(PKInk.InkType)
    /// `.bitmap` erases the pixels it touches; `.vector` removes whole strokes.
    case eraser(PKEraserTool.EraserType)
}
