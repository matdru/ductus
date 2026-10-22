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

    init(allowsFingerDrawing: Bool = FeelLabModel.isSimulator) {
        pencilKitSurface.allowsFingerDrawing = allowsFingerDrawing
        customSurface.allowsFingerDrawing = allowsFingerDrawing
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
