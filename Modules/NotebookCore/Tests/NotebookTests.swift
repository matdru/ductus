import Foundation
import Testing

@testable import NotebookCore

struct NotebookTests {
    let start = Date(timeIntervalSinceReferenceDate: 1_000)
    let later = Date(timeIntervalSinceReferenceDate: 2_000)

    func notebook() -> Notebook {
        Notebook(title: "Ideas", createdAt: start)
    }

    @Test func newNotebookHasOneBlankPage() throws {
        let notebook = notebook()
        #expect(notebook.pages.count == 1)
        let page = try #require(notebook.pages.first)
        #expect(page.paperOverride == nil)
        #expect(page.createdAt == start)
        #expect(notebook.modifiedAt == start)
    }

    @Test func appendAndInsertPagesKeepOrder() {
        var notebook = notebook()
        let first = notebook.pages[0].id
        let appended = notebook.appendPage(now: later)
        let inserted = notebook.insertPage(at: 1, now: later)
        #expect(notebook.pages.map(\.id) == [first, inserted.id, appended.id])
        #expect(notebook.modifiedAt == later)
    }

    @Test func insertIndexIsClamped() {
        var notebook = notebook()
        let page = notebook.insertPage(at: 99, now: later)
        #expect(notebook.pages.last?.id == page.id)
    }

    @Test func movePageReorders() {
        var notebook = notebook()
        let a = notebook.pages[0].id
        let b = notebook.appendPage(now: start).id
        let c = notebook.appendPage(now: start).id
        notebook.movePage(from: 0, to: 2, now: later)
        #expect(notebook.pages.map(\.id) == [b, c, a])
        notebook.movePage(from: 2, to: 0, now: later)
        #expect(notebook.pages.map(\.id) == [a, b, c])
        #expect(notebook.modifiedAt == later)
    }

    @Test func moveWithBadIndexIsIgnored() {
        var notebook = notebook()
        let before = notebook
        notebook.movePage(from: 0, to: 5, now: later)
        notebook.movePage(from: -1, to: 0, now: later)
        #expect(notebook == before)
    }

    @Test func deletePageRemovesItAndClearsLastViewed() {
        var notebook = notebook()
        let second = notebook.appendPage(now: start)
        notebook.lastViewedPageID = second.id
        let deleted = notebook.deletePage(id: second.id, now: later)
        #expect(deleted)
        #expect(notebook.pages.map(\.id) == [notebook.pages[0].id])
        #expect(notebook.lastViewedPageID == nil)
        #expect(notebook.modifiedAt == later)
    }

    @Test func lastPageCannotBeDeleted() {
        var notebook = notebook()
        let deleted = notebook.deletePage(id: notebook.pages[0].id, now: later)
        #expect(!deleted)
        #expect(notebook.pages.count == 1)
        #expect(notebook.modifiedAt == start)
    }

    @Test func markingAPageEditedUpdatesBothDates() throws {
        var notebook = notebook()
        let id = notebook.pages[0].id
        notebook.markPageEdited(id, at: later)
        #expect(notebook.pages[0].modifiedAt == later)
        #expect(notebook.modifiedAt == later)
    }

    @Test func pageSizesArePortraitInPoints() {
        // A5 is 148 × 210 mm; 1 pt = 1/72 inch.
        #expect(abs(PageSize.a5.width - 419.53) < 0.01)
        #expect(abs(PageSize.a5.height - 595.28) < 0.01)
        #expect(PageSize.letter.width == 612 && PageSize.letter.height == 792)
        for size in PageSize.allCases { #expect(size.height > size.width) }
    }

    @Test func pageUsesNotebookPaperUnlessOverridden() {
        var notebook = notebook()
        notebook.paper = Paper(type: .dotGrid, color: .ivory)
        #expect(notebook.paper(for: notebook.pages[0]) == notebook.paper)
        var page = notebook.pages[0]
        page.paperOverride = Paper(type: .squared, color: .white)
        #expect(notebook.paper(for: page) == Paper(type: .squared, color: .white))
    }

    @Test func touchBumpsModifiedDate() {
        var notebook = notebook()
        notebook.touch(later)
        #expect(notebook.modifiedAt == later)
    }
}
