import Foundation
import Testing

@testable import NotebookCore

struct ShelfTests {
    @Test func libraryManifestRoundTrips() throws {
        let shelves = [Shelf(name: "Work", colorName: "ink"), Shelf(name: "University", colorName: "mustard")]
        let decoded = try LibraryManifest.decode(LibraryManifest.encode(shelves))
        #expect(decoded == shelves)
    }

    @Test func libraryManifestToleratesMissingFields() throws {
        let id = UUID()
        let json = #"{"schemaVersion": 1, "shelves": [{"id": "\#(id.uuidString)"}]}"#
        let shelves = try LibraryManifest.decode(Data(json.utf8))
        #expect(shelves == [Shelf(id: id, name: "Shelf", colorName: "graphite")])
    }

    @Test func newerLibraryManifestIsRefused() {
        let json = #"{"schemaVersion": 7, "shelves": []}"#
        #expect(throws: LibraryManifest.Error.unsupportedVersion(7)) { try LibraryManifest.decode(Data(json.utf8)) }
    }

    @Test func notebookShelfRoundTripsAndDefaultsToNone() throws {
        var notebook = Notebook(title: "Work log")
        #expect(notebook.shelfID == nil)
        let shelf = UUID()
        notebook.shelfID = shelf
        #expect(try NotebookManifest.decode(NotebookManifest.encode(notebook)).shelfID == shelf)
    }

    @Test func duplicateGetsFreshIDsAndKeepsTheLook() {
        var original = Notebook(title: "Ideas", createdAt: Date(timeIntervalSinceReferenceDate: 1))
        original.appendPage()
        original.cover = Cover(material: .cloth, colorName: "teal")
        original.isPinned = true
        original.shelfID = UUID()
        let later = Date(timeIntervalSinceReferenceDate: 99)

        let (copy, pageMap) = original.duplicated(now: later)

        #expect(copy.id != original.id)
        #expect(copy.title == "Ideas copy")
        #expect(copy.cover == original.cover && copy.paper == original.paper && copy.size == original.size)
        #expect(copy.shelfID == original.shelfID)
        #expect(!copy.isPinned)
        #expect(copy.createdAt == later && copy.modifiedAt == later)
        #expect(copy.pages.count == original.pages.count)
        #expect(Set(copy.pages.map(\.id)).isDisjoint(with: original.pages.map(\.id)))
        for (old, new) in zip(original.pages, copy.pages) { #expect(pageMap[old.id] == new.id) }
    }

    @Test func paperColoursHaveHexValues() {
        #expect(PaperColor.ivory.hex == 0xFBF7EC)
        #expect(Set(PaperColor.allCases.map(\.hex)).count == PaperColor.allCases.count)
    }
}
