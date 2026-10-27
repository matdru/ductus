import DesignSystem
import PencilKit
import UIKit

/// The editor's tools: a few PencilKit inks, the eraser and the lasso, plus an ink colour.
struct EditorTool: Hashable {
    enum Kind: Hashable, CaseIterable {
        case fountainPen, pen, pencil, marker, eraser, lasso
    }

    var kind: Kind
    var color: InkColor

    static let `default` = EditorTool(kind: .fountainPen, color: .black)

    /// Ink colours. Ink is content, so these don't change with the app theme.
    enum InkColor: String, Hashable, CaseIterable {
        case black, navy, blue, red, green

        var uiColor: UIColor {
            let hex: UInt32 =
                switch self {
                case .black: 0x141414
                case .navy: 0x1F2E4D
                case .blue: 0x2457C5
                case .red: 0xB3261E
                case .green: 0x2E6B3F
                }
            return RGBA(hex: hex).uiColor
        }
    }

    var pkTool: PKTool {
        switch kind {
        case .fountainPen: PKInkingTool(.fountainPen, color: color.uiColor)
        case .pen: PKInkingTool(.pen, color: color.uiColor)
        case .pencil: PKInkingTool(.pencil, color: color.uiColor)
        case .marker: PKInkingTool(.marker, color: color.uiColor.withAlphaComponent(0.9))
        case .eraser: PKEraserTool(.vector)
        case .lasso: PKLassoTool()
        }
    }
}

extension EditorTool.Kind {
    var name: String {
        switch self {
        case .fountainPen: "Fountain pen"
        case .pen: "Pen"
        case .pencil: "Pencil"
        case .marker: "Highlighter"
        case .eraser: "Eraser"
        case .lasso: "Lasso"
        }
    }

    var systemImage: String {
        switch self {
        case .fountainPen: "pencil.tip"
        case .pen: "pencil"
        case .pencil: "pencil.and.scribble"
        case .marker: "highlighter"
        case .eraser: "eraser"
        case .lasso: "lasso"
        }
    }
}

/// What a double-tap (or squeeze) on the Pencil does, following the user's choice in iPadOS Settings.
enum PencilTapAction: Equatable {
    case switchEraser, switchPrevious, ignore

    init(_ preferred: UIPencilPreferredAction) {
        switch preferred {
        case .switchEraser: self = .switchEraser
        case .switchPrevious: self = .switchPrevious
        // The colour palette and ink attributes arrive with the ink toolbar (DRU-36).
        default: self = .ignore
        }
    }
}

extension EditorTool.Kind {
    /// The tool after a Pencil tap, given the tool used before this one.
    func afterPencilTap(_ action: PencilTapAction, previous: EditorTool.Kind) -> EditorTool.Kind {
        switch action {
        case .switchEraser where self != .eraser: .eraser
        case .switchEraser, .switchPrevious: previous == self ? EditorTool.default.kind : previous
        case .ignore: self
        }
    }
}
