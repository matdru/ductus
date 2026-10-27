import Foundation
import NotebookCore
import NotebookStore

/// Which notebooks the library shows.
enum LibrarySection: Hashable {
    case all, recent, pinned
    case shelf(UUID)
}

/// What the new-notebook sheet produces.
struct NotebookDraft {
    var title = ""
    var colorName = "ink"
    var paper = Paper.default
    var size = PageSize.a5
    var shelfID: UUID?
}

/// The library's state and every change to it. Each change is saved before the in-memory copy updates, so the
/// screen never shows something that isn't on disk.
@MainActor @Observable
final class LibraryModel {
    static let recentLimit = 12

    private(set) var notebooks: [Notebook] = []
    private(set) var shelves: [Shelf] = []
    /// Notebooks on disk that couldn't be opened; left untouched.
    private(set) var unreadableCount = 0
    private(set) var isLoaded = false
    var section: LibrarySection = .all
    var searchText = ""
    /// How sections list their notebooks; Recent is always most recently edited first.
    var sort = AppSettings.NotebookSort.lastEdited

    let store: NotebookStore

    init(store: NotebookStore) {
        self.store = store
    }

    func load() async {
        let library = await store.loadLibrary()
        notebooks = library.notebooks
        unreadableCount = library.unreadable.count
        shelves = (try? await store.loadShelves()) ?? []
        isLoaded = true
    }

    // MARK: Reading

    /// The current section, filtered by search, in the chosen order.
    var visibleNotebooks: [Notebook] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let matching = notebooks(in: section).filter { query.isEmpty || $0.title.localizedStandardContains(query) }
        return matching
    }

    func notebooks(in section: LibrarySection) -> [Notebook] {
        if section == .recent {
            return Array(notebooks.sorted { $0.modifiedAt > $1.modifiedAt }.prefix(Self.recentLimit))
        }
        let sorted = notebooks.sorted(by: sort.areInIncreasingOrder)
        switch section {
        case .all, .recent: return sorted
        case .pinned: return sorted.filter(\.isPinned)
        case .shelf(let id): return sorted.filter { $0.shelfID == id }
        }
    }

    func count(in section: LibrarySection) -> Int {
        notebooks(in: section).count
    }

    /// The thumbnail of the notebook's most recently edited page that has one.
    func thumbnail(for notebook: Notebook) async -> Data? {
        for page in notebook.pages.sorted(by: { $0.modifiedAt > $1.modifiedAt }).prefix(8) {
            if let data = try? await store.thumbnailData(page: page.id, in: notebook.id) { return data }
        }
        return nil
    }

    func shelf(_ id: UUID?) -> Shelf? {
        shelves.first { $0.id == id }
    }

    // MARK: Notebooks

    @discardableResult
    func create(_ draft: NotebookDraft) async throws -> Notebook {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        var notebook = Notebook(
            title: title.isEmpty ? "Untitled" : title, cover: Cover(material: .plain, colorName: draft.colorName),
            paper: draft.paper, size: draft.size)
        notebook.shelfID = draft.shelfID
        try await store.save(notebook)
        notebooks.append(notebook)
        return notebook
    }

    func rename(_ id: UUID, to title: String) async throws {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        try await update(id) { $0.title = title }
    }

    func setColor(_ id: UUID, to colorName: String) async throws {
        try await update(id) { $0.cover.colorName = colorName }
    }

    func setPaper(_ id: UUID, to paper: Paper) async throws {
        try await update(id) { $0.paper = paper }
    }

    func togglePin(_ id: UUID) async throws {
        try await update(id) { $0.isPinned.toggle() }
    }

    func move(_ id: UUID, to shelfID: UUID?) async throws {
        try await update(id) { $0.shelfID = shelfID }
    }

    @discardableResult
    func duplicate(_ id: UUID) async throws -> Notebook {
        guard let original = notebooks.first(where: { $0.id == id }) else { throw LibraryError.notFound }
        let (copy, pageMap) = original.duplicated()
        try await store.save(copy)
        for (page, copiedPage) in pageMap {
            try await store.copyPageData(page: page, from: original.id, to: copiedPage, in: copy.id)
        }
        notebooks.append(copy)
        return copy
    }

    /// Adds a blank page at the end and returns the updated notebook.
    @discardableResult
    func appendPage(_ id: UUID) async throws -> Notebook {
        try await update(id) { $0.appendPage() }
        guard let notebook = notebooks.first(where: { $0.id == id }) else { throw LibraryError.notFound }
        return notebook
    }

    /// Removes a page and its files, and returns the updated notebook.
    @discardableResult
    func deletePage(_ page: UUID, in id: UUID) async throws -> Notebook {
        try await update(id) { _ = $0.deletePage(id: page) }
        try await store.deletePageData(page: page, in: id)
        guard let notebook = notebooks.first(where: { $0.id == id }) else { throw LibraryError.notFound }
        return notebook
    }

    /// Records that these pages' ink changed (the notebook's and each page's modified date).
    func markEdited(_ id: UUID, pages: [UUID]) async throws {
        let now = Date()
        try await update(id) { notebook in
            for page in pages { notebook.markPageEdited(page, at: now) }
        }
    }

    /// Remembers the page the notebook was left open at. Looking isn't editing, so the modified date stays.
    func setLastViewedPage(_ page: UUID, in id: UUID) async throws {
        guard let index = notebooks.firstIndex(where: { $0.id == id }) else { throw LibraryError.notFound }
        guard notebooks[index].lastViewedPageID != page else { return }
        var notebook = notebooks[index]
        notebook.lastViewedPageID = page
        try await store.save(notebook)
        notebooks[index] = notebook
    }

    func delete(_ id: UUID) async throws {
        try await store.delete(notebook: id)
        notebooks.removeAll { $0.id == id }
    }

    // MARK: Shelves

    @discardableResult
    func createShelf(name: String, colorName: String) async throws -> Shelf {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let shelf = Shelf(name: name.isEmpty ? "New shelf" : name, colorName: colorName)
        try await store.saveShelves(shelves + [shelf])
        shelves.append(shelf)
        return shelf
    }

    /// Removes the shelf; its notebooks stay in the library, unshelved.
    func deleteShelf(_ id: UUID) async throws {
        for notebook in notebooks where notebook.shelfID == id {
            try await move(notebook.id, to: nil)
        }
        let remaining = shelves.filter { $0.id != id }
        try await store.saveShelves(remaining)
        shelves = remaining
        if section == .shelf(id) { section = .all }
    }

    private func update(_ id: UUID, _ change: (inout Notebook) -> Void) async throws {
        guard let index = notebooks.firstIndex(where: { $0.id == id }) else { throw LibraryError.notFound }
        var notebook = notebooks[index]
        change(&notebook)
        notebook.touch()
        try await store.save(notebook)
        notebooks[index] = notebook
    }
}

extension AppSettings.NotebookSort {
    func areInIncreasingOrder(_ a: Notebook, _ b: Notebook) -> Bool {
        switch self {
        case .lastEdited: a.modifiedAt > b.modifiedAt
        case .created: a.createdAt > b.createdAt
        case .title: a.title.localizedStandardCompare(b.title) == .orderedAscending
        }
    }
}

enum LibraryError: Error {
    case notFound
}
