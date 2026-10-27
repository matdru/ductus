import Foundation
import NotebookCore
import NotebookStore
import Testing

@testable import Ductus

@MainActor
struct LibraryModelTests {
    let store = NotebookStore(
        root: FileManager.default.temporaryDirectory.appending(path: "LibraryModelTests-\(UUID().uuidString)"))

    func loadedModel() async -> LibraryModel {
        let model = LibraryModel(store: store)
        await model.load()
        return model
    }

    func draft(_ title: String, shelf: UUID? = nil) -> NotebookDraft {
        NotebookDraft(
            title: title, colorName: "teal", paper: Paper(type: .dotGrid, color: .ivory), size: .a5, shelfID: shelf)
    }

    @Test func createdNotebooksPersistNewestFirst() async throws {
        let model = await loadedModel()
        try await model.create(draft("First"))
        try await model.create(draft("Second"))
        #expect(model.visibleNotebooks.map(\.title) == ["Second", "First"])
        let reloaded = await loadedModel()
        #expect(reloaded.visibleNotebooks.map(\.title) == ["Second", "First"])
        #expect(reloaded.notebooks.first?.cover.colorName == "teal")
    }

    @Test func blankTitleBecomesUntitled() async throws {
        let model = await loadedModel()
        let notebook = try await model.create(draft("   "))
        #expect(notebook.title == "Untitled")
    }

    @Test func renameRecolourRepaperAndPinPersist() async throws {
        let model = await loadedModel()
        let id = try await model.create(draft("Old")).id
        try await model.rename(id, to: "New")
        try await model.setColor(id, to: "plum")
        try await model.setPaper(id, to: Paper(type: .squared, color: .white))
        try await model.togglePin(id)
        let notebook = try #require(await loadedModel().notebooks.first)
        #expect(notebook.title == "New")
        #expect(notebook.cover.colorName == "plum")
        #expect(notebook.paper == Paper(type: .squared, color: .white))
        #expect(notebook.isPinned)
    }

    @Test func deleteRemovesTheNotebookForGood() async throws {
        let model = await loadedModel()
        let id = try await model.create(draft("Doomed")).id
        try await model.delete(id)
        #expect(model.notebooks.isEmpty)
        #expect(await loadedModel().notebooks.isEmpty)
    }

    @Test func duplicateCopiesInk() async throws {
        let model = await loadedModel()
        let original = try await model.create(draft("Ideas"))
        try await store.savePage(Data([1, 2, 3]), page: original.pages[0].id, in: original.id)
        let copy = try await model.duplicate(original.id)
        #expect(copy.title == "Ideas copy")
        #expect(try await store.pageData(page: copy.pages[0].id, in: copy.id) == Data([1, 2, 3]))
        #expect(model.notebooks.count == 2)
    }

    @Test func sectionsFilterAndCount() async throws {
        let model = await loadedModel()
        let shelf = try await model.createShelf(name: "Work", colorName: "ink")
        let shelved = try await model.create(draft("Shelved", shelf: shelf.id))
        let pinned = try await model.create(draft("Pinned"))
        try await model.togglePin(pinned.id)
        try await model.create(draft("Loose"))

        #expect(model.count(in: .all) == 3)
        model.section = .pinned
        #expect(model.visibleNotebooks.map(\.id) == [pinned.id])
        model.section = .shelf(shelf.id)
        #expect(model.visibleNotebooks.map(\.id) == [shelved.id])
        #expect(model.count(in: .shelf(shelf.id)) == 1)
    }

    @Test func searchMatchesTitlesIgnoringCase() async throws {
        let model = await loadedModel()
        try await model.create(draft("Meeting Notes"))
        try await model.create(draft("Maths"))
        model.searchText = "meet"
        #expect(model.visibleNotebooks.map(\.title) == ["Meeting Notes"])
    }

    @Test func movingAndDeletingShelvesPersist() async throws {
        let model = await loadedModel()
        let shelf = try await model.createShelf(name: "University", colorName: "mustard")
        let id = try await model.create(draft("Lectures")).id
        try await model.move(id, to: shelf.id)
        #expect(await loadedModel().notebooks.first?.shelfID == shelf.id)

        model.section = .shelf(shelf.id)
        try await model.deleteShelf(shelf.id)
        let reloaded = await loadedModel()
        #expect(reloaded.shelves.isEmpty)
        #expect(reloaded.notebooks.first?.shelfID == nil)
        #expect(model.section == .all)
    }

    @Test func appendPageAndMarkEditedPersist() async throws {
        let model = await loadedModel()
        let id = try await model.create(draft("Pages")).id
        let grown = try await model.appendPage(id)
        #expect(grown.pages.count == 2)
        let page = grown.pages[1].id
        let before = grown.modifiedAt
        try await model.markEdited(id, pages: [page])
        let reloaded = try #require(await loadedModel().notebooks.first)
        #expect(reloaded.pages.count == 2)
        #expect(reloaded.modifiedAt > before)
        #expect(reloaded.pages[1].modifiedAt > grown.pages[1].modifiedAt)
    }

    // MARK: Sorting

    @Test func sortsByTitleOrCreationDate() async throws {
        let model = await loadedModel()
        let banana = try await model.create(draft("banana"))
        try await model.create(draft("Apple"))
        try await model.create(draft("cherry"))
        try await model.rename(banana.id, to: "Banana")

        #expect(model.visibleNotebooks.map(\.title) == ["Banana", "cherry", "Apple"])
        model.sort = .title
        #expect(model.visibleNotebooks.map(\.title) == ["Apple", "Banana", "cherry"])
        model.sort = .created
        #expect(model.visibleNotebooks.map(\.title) == ["cherry", "Apple", "Banana"])
    }

    @Test func recentStaysInEditOrderWhateverTheSort() async throws {
        let model = await loadedModel()
        try await model.create(draft("Apple"))
        try await model.create(draft("Banana"))
        model.sort = .title
        #expect(model.notebooks(in: .recent).map(\.title) == ["Banana", "Apple"])
    }
}
