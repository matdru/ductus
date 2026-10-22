import Foundation
import InkCore
import InkMetal
import InkPencilKit
import Observation
import PencilKit
import UIKit

enum Engine: String, CaseIterable, Identifiable {
    case pencilKit = "PencilKit"
    case custom = "Custom"
    var id: Self { self }
}

enum CustomTool: CaseIterable, Hashable {
    case pen
    case fountainPen

    var displayName: String {
        switch self {
        case .pen: "Pen"
        case .fountainPen: "Fountain"
        }
    }

    var systemImage: String {
        switch self {
        case .pen: "pencil.tip"
        case .fountainPen: "pencil.and.scribble"
        }
    }

    var inkTool: InkTool {
        switch self {
        case .pen: .defaultPen
        case .fountainPen: .fountainPen
        }
    }
}

enum ComparisonMode: String, CaseIterable, Identifiable {
    case single = "Single"
    case split = "Split"
    case replay = "Replay"
    case blind = "Blind A/B"
    var id: Self { self }
    var isAvailable: Bool { self == .single }
}

/// Both engines stay alive so switching keeps each engine's ink.
@MainActor
@Observable
final class FeelLabModel {
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
            true
        #else
            false
        #endif
    }

    var engine: Engine = .custom
    var mode: ComparisonMode = .single
    var pencilKitTool: PencilKitTool = .ink(.pen) {
        didSet { pencilKitSurface.selectedTool = pencilKitTool }
    }
    let pencilKitSurface = PencilKitSurface()
    let customSurface = CustomSurface()
    var customTool: CustomTool = .fountainPen {
        didSet { customSurface.setTool(customTool.inkTool) }
    }

    init(allowsFingerDrawing: Bool = FeelLabModel.isSimulator) {
        pencilKitSurface.allowsFingerDrawing = allowsFingerDrawing
        customSurface.allowsFingerDrawing = allowsFingerDrawing
        customSurface.setTool(customTool.inkTool)
    }

    /// Saves the PencilKit page's raw points as JSON and returns the file. On device, pull it with
    /// `xcrun devicectl device copy from --domain-type appDataContainer --domain-identifier app.ductus.feellab`.
    func exportPencilKitStrokes(to directory: URL = .documentsDirectory, now: Date = .now) throws -> URL {
        let dump = StrokeDump(drawing: pencilKitSurface.canvasView.drawing)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let stamp = now.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false))
        let url = directory.appending(path: "strokes-\(stamp.replacingOccurrences(of: ":", with: "")).json")
        try encoder.encode(dump).write(to: url)
        return url
    }

    var activeSurface: any InkSurface {
        switch engine {
        case .pencilKit: pencilKitSurface
        case .custom: customSurface
        }
    }

    var activeView: UIView {
        switch engine {
        case .pencilKit: pencilKitSurface
        case .custom: customSurface
        }
    }
}

extension PencilKitTool {
    var displayName: String {
        switch self {
        case .ink(.pen): "Pen"
        case .ink(.pencil): "Pencil"
        case .ink(.marker): "Marker"
        case .ink(.monoline): "Monoline"
        case .ink(.fountainPen): "Fountain"
        case .ink(.watercolor): "Watercolor"
        case .ink(.crayon): "Crayon"
        case .ink(.reed): "Reed"
        case .ink(let type): type.rawValue
        case .eraser(.vector): "Stroke Eraser"
        case .eraser: "Eraser"
        }
    }

    var systemImage: String {
        switch self {
        case .ink(.pencil): "pencil"
        case .ink(.marker): "highlighter"
        case .ink(.monoline): "scribble"
        case .ink(.fountainPen): "pencil.and.scribble"
        case .ink(.watercolor): "paintbrush"
        case .ink(.crayon): "pencil.line"
        case .ink(.reed): "paintbrush.pointed"
        case .ink: "pencil.tip"
        case .eraser(.vector): "eraser.line.dashed"
        case .eraser: "eraser"
        }
    }
}
