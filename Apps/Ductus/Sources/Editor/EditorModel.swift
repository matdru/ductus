import Foundation
import NotebookCore
import NotebookStore
import PencilKit

/// An open notebook: its pages combined into one canvas drawing, the current tool, and autosave.
///
/// Autosave runs about a second after the last change (and immediately via `saveNow`, e.g. on backgrounding or
/// closing). It writes only pages whose ink changed, never creates files for blank pages, and never overwrites a
/// page that failed to load unless the person has drawn on it.
@MainActor @Observable
final class EditorModel {
    enum SaveState: Equatable {
        case saved, unsaved, saving
        case failed(String)
    }

    static let autosaveDelay: Duration = .seconds(1)

    private(set) var notebook: Notebook
    private(set) var layout: PageLayout
    private(set) var drawing = PKDrawing()
    private(set) var saveState = SaveState.saved
    /// Pages whose file couldn't be read; they show blank and are left untouched on disk.
    private(set) var unreadablePages: Set<UUID> = []
    private(set) var isLoaded = false
    /// Bumped whenever the model replaces the drawing itself (load, new page), so the canvas knows to take it.
    private(set) var revision = 0
    var tool = EditorTool.default {
        didSet {
            if tool.kind != oldValue.kind { previousToolKind = oldValue.kind }
        }
    }
    /// The tool used before the current one, for the Pencil's double-tap.
    private(set) var previousToolKind = EditorTool.default.kind
    var currentPage = 0
    /// The canvas's undo manager; ink undo is PencilKit's, page changes are registered here too.
    weak var undoManager: UndoManager?
    /// The page add or removal an undo or redo started, if it's still running.
    private(set) var pendingPageChange: Task<Void, Never>?

    private let library: LibraryModel
    private let store: NotebookStore
    /// What's on disk for each page, to skip unchanged pages. `nil` means no file.
    private var savedData: [UUID: Data] = [:]
    private var autosave: Task<Void, Never>?

    init(notebook: Notebook, library: LibraryModel, store: NotebookStore) {
        self.notebook = notebook
        self.library = library
        self.store = store
        layout = PageLayout(size: notebook.size, pageCount: notebook.pages.count)
    }

    func load() async {
        var pages: [PKDrawing] = []
        for page in notebook.pages {
            do {
                if let data = try await store.pageData(page: page.id, in: notebook.id) {
                    pages.append(try PKDrawing(data: data))
                    savedData[page.id] = data
                } else {
                    pages.append(PKDrawing())
                }
            } catch {
                unreadablePages.insert(page.id)
                pages.append(PKDrawing())
            }
        }
        drawing = layout.combine(pages)
        revision += 1
        currentPage = notebook.pages.firstIndex { $0.id == notebook.lastViewedPageID } ?? 0
        isLoaded = true
    }

    /// Called by the canvas after every edit; schedules an autosave.
    func drawingChanged(_ newDrawing: PKDrawing) {
        drawing = newDrawing
        saveState = .unsaved
        autosave?.cancel()
        autosave = Task { [weak self] in
            try? await Task.sleep(for: Self.autosaveDelay)
            guard !Task.isCancelled else { return }
            await self?.saveNow()
        }
    }

    func saveNow() async {
        autosave?.cancel()
        guard saveState == .unsaved else { return }
        saveState = .saving
        let pages = layout.split(drawing)
        var changed: [(page: Page, drawing: PKDrawing)] = []
        do {
            for (page, pageDrawing) in zip(notebook.pages, pages) {
                guard let edited = try await savePage(page, pageDrawing) else { continue }
                changed.append((page, edited))
            }
            if !changed.isEmpty {
                try await library.markEdited(notebook.id, pages: changed.map(\.page.id))
                refreshNotebook()
            }
            saveState = .saved
        } catch {
            saveState = .failed(error.localizedDescription)
        }
        for (page, pageDrawing) in changed where !pageDrawing.strokes.isEmpty {
            await saveThumbnail(for: page, drawing: pageDrawing)
        }
    }

    /// Writes one page if its ink changed; returns the drawing when it did.
    private func savePage(_ page: Page, _ pageDrawing: PKDrawing) async throws -> PKDrawing? {
        let previous = savedData[page.id]
        if pageDrawing.strokes.isEmpty {
            // Blank: nothing to write unless ink was erased (an unreadable page stays as it is).
            guard previous != nil else { return nil }
            try await store.deletePageData(page: page.id, in: notebook.id)
            savedData[page.id] = nil
            return pageDrawing
        }
        let data = pageDrawing.dataRepresentation()
        guard data != previous else { return nil }
        try await store.savePage(data, page: page.id, in: notebook.id)
        savedData[page.id] = data
        unreadablePages.remove(page.id)
        return pageDrawing
    }

    private func saveThumbnail(for page: Page, drawing pageDrawing: PKDrawing) async {
        let data = pageDrawing.dataRepresentation()
        let paper = notebook.paper(for: page)
        let size = notebook.size
        let png = await Task.detached(priority: .utility) {
            Thumbnailer.png(drawingData: data, paper: paper, size: size)
        }.value
        guard let png else { return }
        try? await store.saveThumbnail(png, page: page.id, in: notebook.id)
    }

    /// A double-tap or squeeze on the Pencil: switches to the eraser and back, or to the previous tool.
    func pencilTapped(_ action: PencilTapAction) {
        tool.kind = tool.kind.afterPencilTap(action, previous: previousToolKind)
    }

    /// Adds a blank page at the end of the notebook. Undo removes it again while it's still blank.
    func appendPage() async throws {
        try await addPage()
        undoManager?.registerUndo(withTarget: self) { $0.undoAddPage() }
        undoManager?.setActionName("Add Page")
    }

    /// Undo of adding a page: removes the last page, but only while it's blank, so undo never loses ink.
    /// The inverse is registered straight away (undo managers need it during the undo), the files change after.
    private func undoAddPage() {
        guard notebook.pages.count > 1, let last = notebook.pages.last,
            layout.split(drawing).last?.strokes.isEmpty == true
        else { return }
        undoManager?.registerUndo(withTarget: self) { $0.redoAddPage() }
        undoManager?.setActionName("Add Page")
        changePages { model in try await model.removePage(last.id) }
    }

    private func redoAddPage() {
        undoManager?.registerUndo(withTarget: self) { $0.undoAddPage() }
        undoManager?.setActionName("Add Page")
        changePages { model in try await model.addPage() }
    }

    /// Runs page changes one after another, so a quick undo and redo can't interleave.
    private func changePages(_ change: @escaping @MainActor (EditorModel) async throws -> Void) {
        let previous = pendingPageChange
        pendingPageChange = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            try? await change(self)
        }
    }

    private func removePage(_ id: UUID) async throws {
        await saveNow()
        notebook = try await library.deletePage(id, in: notebook.id)
        let pages = Array(layout.split(drawing).prefix(notebook.pages.count))
        layout = PageLayout(size: notebook.size, pageCount: notebook.pages.count)
        drawing = layout.combine(pages)
        currentPage = min(currentPage, notebook.pages.count - 1)
        revision += 1
    }

    private func addPage() async throws {
        await saveNow()
        notebook = try await library.appendPage(notebook.id)
        let pages = layout.split(drawing)
        layout = PageLayout(size: notebook.size, pageCount: notebook.pages.count)
        drawing = layout.combine(pages)
        revision += 1
    }

    private func refreshNotebook() {
        if let latest = library.notebooks.first(where: { $0.id == notebook.id }) { notebook = latest }
    }
}
