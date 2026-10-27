import DesignSystem
import Foundation
import NotebookCore
import PencilKit
import UIKit

/// The editor's tools: four inks, the eraser and the lasso, with one colour and one size that every ink uses.
/// Remembered for the whole app, so every notebook opens with the tool you last had in hand.
struct Toolbox: Codable, Equatable {
    enum Tool: Codable, Hashable {
        case ink(Ink)
        case eraser, lasso
    }

    /// The PencilKit inks in the toolbar.
    enum Ink: String, CatalogueValue {
        case fountainPen, pen, pencil, marker
        static let fallback = Ink.pen

        var inkType: PKInk.InkType {
            switch self {
            case .fountainPen: .fountainPen
            case .pen: .pen
            case .pencil: .pencil
            case .marker: .marker
            }
        }

        var name: String {
            switch self {
            case .fountainPen: "Fountain pen"
            case .pen: "Pen"
            case .pencil: "Pencil"
            case .marker: "Highlighter"
            }
        }

        var symbol: String {
            switch self {
            case .fountainPen: "pencil.tip"
            case .pen: "pencil"
            case .pencil: "pencil.line"
            case .marker: "highlighter"
            }
        }

        var widthRange: ClosedRange<Double> {
            let range = inkType.validWidthRange
            return Double(range.lowerBound)...Double(range.upperBound)
        }
    }

    /// Fine, medium or bold, tuned to each ink's own width range.
    enum Size: String, CatalogueValue {
        case fine, medium, bold
        static let fallback = Size.medium

        var name: String {
            switch self {
            case .fine: "Fine"
            case .medium: "Medium"
            case .bold: "Bold"
            }
        }

        /// In canvas units (two per page point), as PencilKit takes it.
        func width(for ink: Ink) -> Double {
            let fraction =
                switch self {
                case .fine: 0.06
                case .medium: 0.15
                case .bold: 0.35
                }
            let range = ink.widthRange
            return range.lowerBound + fraction * (range.upperBound - range.lowerBound)
        }
    }

    /// Ink colours. Ink is content, so these don't change with the app theme.
    enum Swatch: CaseIterable {
        case black, navy, blue, red, green, yellow

        var hex: UInt32 {
            switch self {
            case .black: 0x141414
            case .navy: 0x1F2E4D
            case .blue: 0x2457C5
            case .red: 0xB3261E
            case .green: 0x2E6B3F
            case .yellow: 0xF2D64B
            }
        }

        var name: String {
            switch self {
            case .black: "Black"
            case .navy: "Navy"
            case .blue: "Blue"
            case .red: "Red"
            case .green: "Green"
            case .yellow: "Yellow"
            }
        }
    }

    enum Eraser: String, CatalogueValue {
        /// Removes whole strokes.
        case stroke
        /// Rubs out only the part of a stroke it touches.
        case pixel
        static let fallback = Eraser.stroke

        var name: String { self == .stroke ? "Whole strokes" : "Pixels" }
    }

    /// `0xRRGGBB`.
    var color = Swatch.black.hex
    var size = Size.medium
    var eraser = Eraser.stroke
    private(set) var selection = Tool.ink(.fountainPen)
    /// The tool in hand before this one, for the Pencil's double-tap.
    private(set) var previous = Tool.ink(.fountainPen)

    var colorName: String { Swatch.allCases.first { $0.hex == color }?.name ?? "Custom" }

    var pkTool: PKTool {
        switch selection {
        case .ink(let ink):
            let base = RGBA(hex: color).uiColor
            return PKInkingTool(
                ink.inkType, color: ink == .marker ? base.withAlphaComponent(0.9) : base, width: size.width(for: ink))
        case .eraser: return PKEraserTool(eraser == .pixel ? .bitmap : .vector)
        case .lasso: return PKLassoTool()
        }
    }

    mutating func select(_ tool: Tool) {
        guard tool != selection else { return }
        previous = selection
        selection = tool
    }

    /// A tap in the toolbar: picks the tool up, or, for the eraser already in hand, switches its mode.
    mutating func tap(_ tool: Tool) {
        if tool == .eraser && selection == .eraser {
            eraser = eraser == .stroke ? .pixel : .stroke
        } else {
            select(tool)
        }
    }

    /// A double-tap or squeeze on the Pencil: to the eraser and back, or to the previous tool.
    mutating func pencilTapped(_ action: PencilTapAction) {
        switch action {
        case .switchEraser where selection != .eraser: select(.eraser)
        case .switchEraser, .switchPrevious: select(previous == selection ? .ink(.fountainPen) : previous)
        case .ignore: break
        }
    }
}

extension Toolbox {
    private enum CodingKeys: String, CodingKey {
        case color, size, eraser, selection, previous
    }

    /// Anything missing or unreadable takes its default, so toolboxes from older or newer versions load.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? container.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        let defaults = Toolbox()
        color = value(.color, defaults.color)
        size = value(.size, defaults.size)
        eraser = value(.eraser, defaults.eraser)
        selection = value(.selection, defaults.selection)
        previous = value(.previous, selection)
    }
}

/// What a double-tap (or squeeze) on the Pencil does, following the user's choice in iPadOS Settings.
enum PencilTapAction: Equatable {
    case switchEraser, switchPrevious, ignore

    init(_ preferred: UIPencilPreferredAction) {
        switch preferred {
        case .switchEraser: self = .switchEraser
        case .switchPrevious: self = .switchPrevious
        // The colour palette and ink attributes: Ductus has no palette to show from the Pencil yet.
        default: self = .ignore
        }
    }
}
