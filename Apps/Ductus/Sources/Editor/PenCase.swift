import DesignSystem
import Foundation
import NotebookCore
import PencilKit
import UIKit

/// One of your pens: an ink, a colour and a width, like a pen in a pen case.
struct Pen: Codable, Hashable, Identifiable {
    var id = UUID()
    var ink: Ink
    /// `0xRRGGBB`. Ink is content, so it doesn't change with the app theme.
    var color: UInt32
    /// In canvas units (two per page point), as PencilKit takes it.
    var width: Double

    /// The PencilKit inks Ductus offers.
    enum Ink: String, CatalogueValue {
        case fountainPen, pen, pencil, marker, monoline, watercolor, crayon, reed
        static let fallback = Ink.pen

        var inkType: PKInk.InkType {
            switch self {
            case .fountainPen: .fountainPen
            case .pen: .pen
            case .pencil: .pencil
            case .marker: .marker
            case .monoline: .monoline
            case .watercolor: .watercolor
            case .crayon: .crayon
            case .reed: .reed
            }
        }

        var name: String {
            switch self {
            case .fountainPen: "Fountain pen"
            case .pen: "Pen"
            case .pencil: "Pencil"
            case .marker: "Highlighter"
            case .monoline: "Monoline"
            case .watercolor: "Watercolour"
            case .crayon: "Crayon"
            case .reed: "Reed"
            }
        }

        var widthRange: ClosedRange<Double> {
            let range = inkType.validWidthRange
            return Double(range.lowerBound)...Double(range.upperBound)
        }

        var defaultWidth: Double { Double(inkType.defaultWidth) }
    }

    /// The colour palette; anything else is a custom colour.
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

    init(id: UUID = UUID(), ink: Ink, color: UInt32, width: Double? = nil) {
        self.id = id
        self.ink = ink
        self.color = color
        self.width = width ?? ink.defaultWidth
    }

    var clampedWidth: Double { min(max(width, ink.widthRange.lowerBound), ink.widthRange.upperBound) }

    var widthInPoints: Double { clampedWidth / PageLayout.unitsPerPoint }

    var colorName: String { Swatch.allCases.first { $0.hex == color }?.name ?? "Custom" }

    var uiColor: UIColor {
        let base = RGBA(hex: color).uiColor
        return ink == .marker ? base.withAlphaComponent(0.9) : base
    }

    /// Switches ink, keeping the width at the same place in the new ink's range.
    mutating func change(ink newInk: Ink) {
        let old = ink.widthRange
        let fraction = (clampedWidth - old.lowerBound) / (old.upperBound - old.lowerBound)
        let new = newInk.widthRange
        ink = newInk
        width = new.lowerBound + fraction * (new.upperBound - new.lowerBound)
    }

    var pkTool: PKInkingTool { PKInkingTool(ink.inkType, color: uiColor, width: clampedWidth) }

    /// `0xRRGGBB` for a colour from the colour picker; channels outside sRGB are clamped.
    static func hex(of color: UIColor) -> UInt32 {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func byte(_ channel: CGFloat) -> UInt32 { UInt32((min(max(channel, 0), 1) * 255).rounded()) }
        return byte(red) << 16 | byte(green) << 8 | byte(blue)
    }
}

/// Your pens, the eraser and the lasso, and which one is in hand. Remembered for the whole app.
struct PenCase: Codable, Equatable {
    static let maximumPens = 6

    enum Tool: Codable, Hashable {
        case pen(UUID)
        case eraser, lasso
    }

    enum Eraser: String, CatalogueValue {
        /// Removes whole strokes.
        case stroke
        /// Rubs out the part of a stroke it touches.
        case pixel
        static let fallback = Eraser.stroke
    }

    private(set) var pens: [Pen]
    var eraser = Eraser.stroke
    private(set) var selection: Tool
    /// The tool in hand before this one, for the Pencil's double-tap.
    private(set) var previous: Tool

    static let `default`: PenCase = {
        let pens = [
            Pen(ink: .fountainPen, color: Pen.Swatch.black.hex),
            Pen(ink: .pen, color: Pen.Swatch.red.hex, width: 2),
            Pen(ink: .marker, color: Pen.Swatch.yellow.hex),
        ]
        return PenCase(pens: pens, selection: .pen(pens[0].id))
    }()

    /// With no selection, the first pen is in hand.
    init(pens: [Pen], selection: Tool? = nil) {
        let pens = pens.isEmpty ? Self.default.pens : pens
        self.pens = pens
        self.selection = selection ?? .pen(pens[0].id)
        previous = self.selection
        repair()
    }

    var selectedPen: Pen? {
        guard case .pen(let id) = selection else { return nil }
        return pens.first { $0.id == id }
    }

    var canAddPen: Bool { pens.count < Self.maximumPens }
    var canRemovePen: Bool { pens.count > 1 }

    var pkTool: PKTool {
        switch selection {
        case .pen: (selectedPen ?? pens[0]).pkTool
        case .eraser: PKEraserTool(eraser == .pixel ? .bitmap : .vector)
        case .lasso: PKLassoTool()
        }
    }

    mutating func select(_ tool: Tool) {
        guard tool != selection else { return }
        previous = selection
        selection = tool
    }

    /// Adds a copy of the pen in hand (or the last pen) and picks it up.
    @discardableResult
    mutating func addPen() -> Pen {
        var pen = selectedPen ?? pens[pens.count - 1]
        pen.id = UUID()
        guard canAddPen else { return pen }
        pens.append(pen)
        select(.pen(pen.id))
        return pen
    }

    @discardableResult
    mutating func duplicate(_ id: UUID) -> Pen? {
        guard canAddPen, let index = pens.firstIndex(where: { $0.id == id }) else { return nil }
        var copy = pens[index]
        copy.id = UUID()
        pens.insert(copy, at: index + 1)
        return copy
    }

    mutating func remove(_ id: UUID) {
        guard canRemovePen, let index = pens.firstIndex(where: { $0.id == id }) else { return }
        pens.remove(at: index)
        if selection == .pen(id) { selection = .pen(pens[min(index, pens.count - 1)].id) }
        repair()
    }

    mutating func update(_ pen: Pen) {
        guard let index = pens.firstIndex(where: { $0.id == pen.id }) else { return }
        pens[index] = pen
    }

    /// A double-tap or squeeze on the Pencil: to the eraser and back, or to the previous tool.
    mutating func pencilTapped(_ action: PencilTapAction) {
        switch action {
        case .switchEraser where selection != .eraser: select(.eraser)
        case .switchEraser, .switchPrevious: select(previous == selection ? .pen(pens[0].id) : previous)
        case .ignore: break
        }
    }

    /// Points a selection at a pen that no longer exists back to the first pen.
    private mutating func repair() {
        func valid(_ tool: Tool) -> Bool {
            if case .pen(let id) = tool { pens.contains { $0.id == id } } else { true }
        }
        if !valid(selection) { selection = .pen(pens[0].id) }
        if !valid(previous) { previous = .pen(pens[0].id) }
    }
}

extension PenCase {
    private enum CodingKeys: String, CodingKey {
        case pens, eraser, selection, previous
    }

    /// Anything missing or invalid takes its default, so a damaged or newer pen case still loads.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let pens = (try? container.decodeIfPresent([Pen].self, forKey: .pens)) ?? []
        self.init(pens: pens, selection: try? container.decodeIfPresent(Tool.self, forKey: .selection))
        eraser = (try? container.decodeIfPresent(Eraser.self, forKey: .eraser)) ?? .stroke
        previous = (try? container.decodeIfPresent(Tool.self, forKey: .previous)) ?? self.selection
        repair()
    }
}

/// What a double-tap (or squeeze) on the Pencil does, following the user's choice in iPadOS Settings.
enum PencilTapAction: Equatable {
    case switchEraser, switchPrevious, ignore

    init(_ preferred: UIPencilPreferredAction) {
        switch preferred {
        case .switchEraser: self = .switchEraser
        case .switchPrevious: self = .switchPrevious
        // The colour palette and ink attributes: Ductus has no palette to show yet.
        default: self = .ignore
        }
    }
}
