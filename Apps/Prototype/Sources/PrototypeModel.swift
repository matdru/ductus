import NotebookCore
import PencilKit
import SwiftUI

/// The two directions the prototype compares (see "Direction and fallback" in the design brief).
enum PrototypeStyle: String, CaseIterable, Identifiable {
    case tactile = "Tactile"
    case clean = "Clean"
    var id: Self { self }
}

enum PageNavigation: String, CaseIterable, Identifiable {
    case turn = "Page turn"
    case scroll = "Scroll"
    var id: Self { self }
}

enum PrototypeTool: Hashable {
    case ink(PKInk.InkType)
    case eraser
    case lasso

    @MainActor static let all: [PrototypeTool] = [
        .ink(.fountainPen), .ink(.pen), .ink(.pencil), .ink(.marker), .ink(.monoline), .eraser, .lasso,
    ]
}

/// Everything lives in memory: the prototype is for judging look and feel, not for keeping notes.
@MainActor @Observable
final class PrototypeModel {
    var notebooks: [Notebook] = PrototypeModel.samples()
    var drawings: [UUID: PKDrawing] = [:]
    var style: PrototypeStyle = .tactile
    var navigation: PageNavigation = .turn
    var tool: PrototypeTool = .ink(.fountainPen)
    var inkColor: Color = .black

    /// Tactile opens on page turn, clean on scroll, but either can be switched in the editor.
    func applyStyleDefaults() {
        navigation = style == .tactile ? .turn : .scroll
    }

    var pkTool: PKTool {
        switch tool {
        case .ink(let type): PKInkingTool(type, color: UIColor(inkColor), width: type.defaultWidth)
        case .eraser: PKEraserTool(.vector)
        case .lasso: PKLassoTool()
        }
    }

    func notebook(_ id: UUID) -> Notebook? {
        notebooks.first { $0.id == id }
    }

    func update(_ id: UUID, _ change: (inout Notebook) -> Void) {
        guard let index = notebooks.firstIndex(where: { $0.id == id }) else { return }
        change(&notebooks[index])
    }

    func add(_ notebook: Notebook) {
        notebooks.insert(notebook, at: 0)
    }

    static func samples() -> [Notebook] {
        func sample(_ title: String, _ cover: Cover, _ paper: Paper) -> Notebook {
            var notebook = Notebook(title: title, cover: cover, paper: paper)
            for _ in 0..<4 { notebook.appendPage() }
            return notebook
        }
        return [
            sample("Daily Notes", Cover(material: .cloth, colorName: "navy"), Paper(type: .fineLined, color: .ivory)),
            sample("Sketches", Cover(material: .linen, colorName: "sand"), Paper(type: .blank, color: .cream)),
            sample("Maths", Cover(material: .plain, colorName: "mustard"), Paper(type: .squared, color: .white)),
            sample(
                "Bullet Journal", Cover(material: .leather, colorName: "forest"), Paper(type: .dotGrid, color: .ivory)),
            sample("Meeting Notes", Cover(material: .kraft, colorName: "kraft"), Paper(type: .legal, color: .canary)),
            sample("Lectures", Cover(material: .cloth, colorName: "oxblood"), Paper(type: .cornell, color: .white)),
            sample(
                "Engineering", Cover(material: .plain, colorName: "charcoal"),
                Paper(type: .engineering, color: .white)),
            sample("Songs", Cover(material: .leather, colorName: "plum"), Paper(type: .music, color: .cream)),
        ]
    }
}
