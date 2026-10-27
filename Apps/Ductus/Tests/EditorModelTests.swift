import Foundation
import NotebookCore
import NotebookStore
import PencilKit
import Testing

@testable import Ductus

@MainActor
struct EditorModelTests {
    let store = NotebookStore(
        root: FileManager.default.temporaryDirectory.appending(path: "EditorModelTests-\(UUID().uuidString)"))

    func stroke(at point: CGPoint) -> PKStroke {
        let points = (0..<5).map { i in
            PKStrokePoint(
                location: CGPoint(x: point.x - 10 + Double(i) * 5, y: point.y), timeOffset: Double(i) * 0.01,
                size: CGSize(width: 3, height: 3), opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        return PKStroke(
            ink: PKInk(.pen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date()))
    }

    /// A library with one three-page notebook, and an editor open on it.
    func openEditor() async throws -> (LibraryModel, EditorModel) {
        let library = LibraryModel(store: store)
        await library.load()
        var notebook = try await library.create(NotebookDraft(title: "Ink"))
        notebook = try await library.appendPage(notebook.id)
        notebook = try await library.appendPage(notebook.id)
        let editor = EditorModel(notebook: notebook, library: library, store: store)
        await editor.load()
        return (library, editor)
    }

    @Test func savesOnlyPagesWithInk() async throws {
        let (library, editor) = try await openEditor()
        let notebook = editor.notebook
        let onSecond = CGPoint(x: 200, y: editor.layout.pageRect(1).minY + 80)
        editor.drawingChanged(PKDrawing(strokes: [stroke(at: onSecond)]))
        #expect(editor.saveState == .unsaved)
        await editor.saveNow()
        #expect(editor.saveState == .saved)

        #expect(try await store.pageData(page: notebook.pages[0].id, in: notebook.id) == nil)
        let saved = try #require(try await store.pageData(page: notebook.pages[1].id, in: notebook.id))
        #expect(try PKDrawing(data: saved).strokes.count == 1)
        #expect(try await store.thumbnailData(page: notebook.pages[1].id, in: notebook.id) != nil)
        let edited = try #require(library.notebooks.first { $0.id == notebook.id })
        #expect(edited.modifiedAt > notebook.modifiedAt)
        #expect(edited.pages[1].modifiedAt > notebook.pages[1].modifiedAt)
    }

    @Test func reopeningShowsTheSameInk() async throws {
        let (library, editor) = try await openEditor()
        let onThird = CGPoint(x: 300, y: editor.layout.pageRect(2).minY + 400)
        editor.drawingChanged(PKDrawing(strokes: [stroke(at: onThird), stroke(at: CGPoint(x: 120, y: 120))]))
        await editor.saveNow()

        let reopened = EditorModel(notebook: editor.notebook, library: library, store: store)
        await reopened.load()
        #expect(reopened.drawing.strokes.count == 2)
        let centres = reopened.drawing.strokes.map { $0.renderBounds.midY }.sorted()
        #expect(abs(centres[1] - onThird.y) < 1)
    }

    @Test func erasingAPageRemovesItsFile() async throws {
        let (_, editor) = try await openEditor()
        let page = editor.notebook.pages[0].id
        editor.drawingChanged(PKDrawing(strokes: [stroke(at: CGPoint(x: 150, y: 150))]))
        await editor.saveNow()
        editor.drawingChanged(PKDrawing())
        await editor.saveNow()
        #expect(try await store.pageData(page: page, in: editor.notebook.id) == nil)
    }

    @Test func aDamagedPageIsNotOverwrittenByOtherEdits() async throws {
        let (library, first) = try await openEditor()
        let damaged = first.notebook.pages[0].id
        try await store.savePage(Data([0xDE, 0xAD]), page: damaged, in: first.notebook.id)

        let editor = EditorModel(notebook: first.notebook, library: library, store: store)
        await editor.load()
        #expect(editor.unreadablePages == [damaged])
        let onSecond = CGPoint(x: 200, y: editor.layout.pageRect(1).minY + 80)
        editor.drawingChanged(PKDrawing(strokes: [stroke(at: onSecond)]))
        await editor.saveNow()
        #expect(try await store.pageData(page: damaged, in: editor.notebook.id) == Data([0xDE, 0xAD]))
    }

    @Test func addingAPageGrowsTheCanvasAndPersists() async throws {
        let (library, editor) = try await openEditor()
        try await editor.appendPage()
        #expect(editor.layout.pageCount == 4)
        #expect(library.notebooks.first?.pages.count == 4)
        #expect(await store.loadLibrary().notebooks.first?.pages.count == 4)
    }

    @Test func writingAfterAPageIsAddedLandsOnIt() async throws {
        let (_, editor) = try await openEditor()
        try await editor.appendPage()
        let onFourth = CGPoint(x: 200, y: editor.layout.pageRect(3).minY + 50)
        editor.drawingChanged(PKDrawing(strokes: [stroke(at: onFourth)]))
        await editor.saveNow()
        let page = editor.notebook.pages[3].id
        #expect(try await store.pageData(page: page, in: editor.notebook.id) != nil)
    }

    // MARK: Last page viewed

    @Test func reopensAtTheLastPageViewed() async throws {
        let (library, editor) = try await openEditor()
        let edited = editor.notebook.modifiedAt
        editor.currentPage = 2
        await editor.saveNow()

        let notebook = try #require(library.notebooks.first { $0.id == editor.notebook.id })
        // Looking at a page isn't an edit: the notebook keeps its place in Recent.
        #expect(notebook.modifiedAt == edited)
        let reopened = EditorModel(notebook: notebook, library: library, store: store)
        await reopened.load()
        #expect(reopened.currentPage == 2)
    }

    @Test func opensAtTheFirstPageWhenThatSettingIsOff() async throws {
        let (library, editor) = try await openEditor()
        editor.currentPage = 2
        await editor.saveNow()

        let notebook = try #require(library.notebooks.first { $0.id == editor.notebook.id })
        let reopened = EditorModel(notebook: notebook, library: library, store: store, opensAtLastPage: false)
        await reopened.load()
        #expect(reopened.currentPage == 0)
    }
}
