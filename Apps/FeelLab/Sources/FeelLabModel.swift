import InkCore
import InkMetal
import InkPencilKit
import Observation
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
