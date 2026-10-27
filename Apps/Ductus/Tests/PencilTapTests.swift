import Foundation
import NotebookCore
import NotebookStore
import Testing

@testable import Ductus

struct PencilTapTests {
    @Test func switchEraserGoesToTheEraserFromAnyTool() {
        #expect(EditorTool.Kind.fountainPen.afterPencilTap(.switchEraser, previous: .pen) == .eraser)
        #expect(EditorTool.Kind.lasso.afterPencilTap(.switchEraser, previous: .pen) == .eraser)
    }

    @Test func switchEraserGoesBackToTheLastTool() {
        #expect(EditorTool.Kind.eraser.afterPencilTap(.switchEraser, previous: .marker) == .marker)
    }

    @Test func fromTheEraserWithNoOtherToolItFallsBackToTheDefaultPen() {
        #expect(EditorTool.Kind.eraser.afterPencilTap(.switchEraser, previous: .eraser) == EditorTool.default.kind)
    }

    @Test func switchPreviousSwapsWithTheLastTool() {
        #expect(EditorTool.Kind.pencil.afterPencilTap(.switchPrevious, previous: .pen) == .pen)
        #expect(EditorTool.Kind.pen.afterPencilTap(.switchPrevious, previous: .pencil) == .pencil)
    }

    @Test func ignoreLeavesTheToolAlone() {
        #expect(EditorTool.Kind.pen.afterPencilTap(.ignore, previous: .eraser) == .pen)
    }

    @MainActor @Test func modelRemembersThePreviousTool() async {
        let store = NotebookStore(
            root: FileManager.default.temporaryDirectory.appending(path: "PencilTapTests-\(UUID().uuidString)"))
        let library = LibraryModel(store: store)
        let model = EditorModel(notebook: Notebook(title: "T"), library: library, store: store)
        model.tool.kind = .pencil
        model.pencilTapped(.switchEraser)
        #expect(model.tool.kind == .eraser)
        model.pencilTapped(.switchEraser)
        #expect(model.tool.kind == .pencil)
        #expect(model.tool.color == EditorTool.default.color)
    }
}
