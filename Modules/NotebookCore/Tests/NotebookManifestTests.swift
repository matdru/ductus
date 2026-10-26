import Foundation
import Testing

@testable import NotebookCore

struct NotebookManifestTests {
    @Test func roundTripsEveryField() throws {
        var notebook = Notebook(title: "Lecture notes", createdAt: Date(timeIntervalSinceReferenceDate: 10))
        notebook.cover = Cover(material: .leather, colorName: "forest")
        notebook.paper = Paper(type: .legal, color: .canary)
        notebook.size = .letter
        notebook.isPinned = true
        var page = notebook.appendPage(now: Date(timeIntervalSinceReferenceDate: 20))
        page.paperOverride = Paper(type: .music, color: .white)
        notebook.replacePage(page)
        notebook.lastViewedPageID = page.id

        let decoded = try NotebookManifest.decode(NotebookManifest.encode(notebook))
        #expect(decoded == notebook)
    }

    @Test func datesRoundTripExactly() throws {
        for interval in [0.1, 1_000.123_456_789, 783_216_000.987_654_321, -12.345] {
            let date = Date(timeIntervalSinceReferenceDate: interval)
            let decoded = try NotebookManifest.decode(NotebookManifest.encode(Notebook(title: "t", createdAt: date)))
            #expect(decoded.createdAt == date)
        }
    }

    @Test func encodedManifestCarriesSchemaVersion() throws {
        let data = try NotebookManifest.encode(Notebook(title: "x"))
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(object["schemaVersion"] as? Int == NotebookManifest.schemaVersion)
    }

    @Test func missingFieldsTakeDefaults() throws {
        let id = UUID()
        let json = """
            {"schemaVersion": 1, "notebook": {"id": "\(id.uuidString)"}}
            """
        let notebook = try NotebookManifest.decode(Data(json.utf8))
        #expect(notebook.id == id)
        #expect(notebook.title == "Untitled")
        #expect(notebook.cover == .default)
        #expect(notebook.paper == .default)
        #expect(notebook.size == .a5)
        #expect(!notebook.isPinned)
        #expect(notebook.pages.count == 1)
    }

    @Test func unknownCatalogueValuesFallBackToDefaults() throws {
        let json = """
            {"schemaVersion": 1, "notebook": {"id": "\(UUID().uuidString)", "title": "Future",
             "paper": {"type": "hexGrid", "color": "lavender"},
             "cover": {"material": "cork", "colorName": "teal"}, "size": "b5"}}
            """
        let notebook = try NotebookManifest.decode(Data(json.utf8))
        #expect(notebook.title == "Future")
        #expect(notebook.paper == .default)
        #expect(notebook.cover == Cover(material: Cover.default.material, colorName: "teal"))
        #expect(notebook.size == .a5)
    }

    @Test func newerSchemaIsRefusedRatherThanSilentlyDowngraded() {
        let json = """
            {"schemaVersion": 99, "notebook": {"id": "\(UUID().uuidString)"}}
            """
        #expect(throws: NotebookManifest.Error.unsupportedVersion(99)) {
            try NotebookManifest.decode(Data(json.utf8))
        }
    }

    @Test func missingIDIsAnError() {
        let json = #"{"schemaVersion": 1, "notebook": {"title": "No id"}}"#
        #expect(throws: (any Swift.Error).self) { try NotebookManifest.decode(Data(json.utf8)) }
    }
}
