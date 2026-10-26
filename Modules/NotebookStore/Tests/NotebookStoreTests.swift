import Foundation
import NotebookCore
import Testing

@testable import NotebookStore

struct NotebookStoreTests {
    let root: URL
    let store: NotebookStore

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "NotebookStoreTests-\(UUID().uuidString)")
        store = NotebookStore(root: root)
    }

    func notebook(_ title: String, modified: TimeInterval = 0) -> Notebook {
        var notebook = Notebook(title: title, createdAt: Date(timeIntervalSinceReferenceDate: modified))
        notebook.markPageEdited(notebook.pages[0].id, at: Date(timeIntervalSinceReferenceDate: modified))
        return notebook
    }

    func package(_ id: UUID) -> URL { root.appending(path: "\(id.uuidString).ductus") }

    @Test func emptyRootGivesEmptyLibrary() async {
        let library = await store.loadLibrary()
        #expect(library.notebooks.isEmpty)
        #expect(library.unreadable.isEmpty)
    }

    @Test func savedNotebooksLoadNewestFirst() async throws {
        let old = notebook("Old", modified: 10)
        let new = notebook("New", modified: 20)
        try await store.save(old)
        try await store.save(new)
        let library = await store.loadLibrary()
        #expect(library.notebooks == [new, old])
    }

    @Test func savingAgainReplacesTheManifest() async throws {
        var notebook = notebook("Draft")
        try await store.save(notebook)
        notebook.title = "Final"
        try await store.save(notebook)
        #expect(await store.loadLibrary().notebooks.map(\.title) == ["Final"])
    }

    @Test func pageDataRoundTripsAndBlankPagesHaveNone() async throws {
        let notebook = notebook("Ink")
        try await store.save(notebook)
        let page = notebook.pages[0].id
        #expect(try await store.pageData(page: page, in: notebook.id) == nil)
        try await store.savePage(Data([1, 2, 3]), page: page, in: notebook.id)
        try await store.savePage(Data([4, 5]), page: page, in: notebook.id)
        #expect(try await store.pageData(page: page, in: notebook.id) == Data([4, 5]))
    }

    @Test func aCorruptPageAffectsOnlyThatPage() async throws {
        var notebook = notebook("Two pages")
        let second = notebook.appendPage()
        try await store.save(notebook)
        try await store.savePage(Data("good".utf8), page: second.id, in: notebook.id)
        let firstFile = package(notebook.id).appending(path: "pages/\(notebook.pages[0].id.uuidString).drawing")
        try Data([0xFF, 0x00]).write(to: firstFile)

        #expect(try await store.pageData(page: second.id, in: notebook.id) == Data("good".utf8))
        #expect(try await store.pageData(page: notebook.pages[0].id, in: notebook.id) == Data([0xFF, 0x00]))
        #expect(await store.loadLibrary().notebooks.map(\.id) == [notebook.id])
    }

    @Test func unreadableManifestsAreReportedAndLeftAlone() async throws {
        let good = notebook("Good")
        try await store.save(good)
        let broken = root.appending(path: "\(UUID().uuidString).ductus")
        try FileManager.default.createDirectory(at: broken, withIntermediateDirectories: true)
        let newer = Data(#"{"schemaVersion": 99, "notebook": {"id": "\#(UUID().uuidString)"}}"#.utf8)
        try newer.write(to: broken.appending(path: "manifest.json"))

        let library = await store.loadLibrary()
        #expect(library.notebooks == [good])
        #expect(library.unreadable.map(\.lastPathComponent) == [broken.lastPathComponent])
        #expect(try Data(contentsOf: broken.appending(path: "manifest.json")) == newer)
    }

    @Test func otherFilesInTheRootAreIgnored() async throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: root.appending(path: ".DS_Store"))
        try FileManager.default.createDirectory(
            at: root.appending(path: "scratch"), withIntermediateDirectories: true)
        let library = await store.loadLibrary()
        #expect(library.notebooks.isEmpty && library.unreadable.isEmpty)
    }

    @Test func writesLeaveNoTemporaryFilesBehind() async throws {
        let notebook = notebook("Clean")
        try await store.save(notebook)
        for _ in 0..<5 {
            try await store.savePage(Data(repeating: 7, count: 4096), page: notebook.pages[0].id, in: notebook.id)
        }
        let pages = try FileManager.default.contentsOfDirectory(
            atPath: package(notebook.id).appending(path: "pages").path)
        #expect(pages == ["\(notebook.pages[0].id.uuidString).drawing"])
        let top = try FileManager.default.contentsOfDirectory(atPath: package(notebook.id).path).sorted()
        #expect(top == ["manifest.json", "pages"])
    }

    @Test func deletingPageDataAndNotebooks() async throws {
        let notebook = notebook("Gone")
        try await store.save(notebook)
        let page = notebook.pages[0].id
        try await store.savePage(Data([1]), page: page, in: notebook.id)
        try await store.deletePageData(page: page, in: notebook.id)
        #expect(try await store.pageData(page: page, in: notebook.id) == nil)
        try await store.deletePageData(page: page, in: notebook.id)  // already gone: no error
        try await store.delete(notebook: notebook.id)
        #expect(await store.loadLibrary().notebooks.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: package(notebook.id).path))
    }
}
