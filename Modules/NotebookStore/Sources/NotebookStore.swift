import Foundation
import NotebookCore

/// Notebooks on disk, one package per notebook and one file per page:
///
///     <root>/<notebook-id>.ductus/
///       manifest.json             NotebookManifest
///       pages/<page-id>.drawing   opaque page ink (the app stores PKDrawing.dataRepresentation())
///
/// Every write is atomic (temporary file, then rename), so a crash or kill mid-save leaves the previous
/// version intact, never a half-written file. Page ink is opaque `Data`, which keeps this module free of
/// PencilKit and lets a damaged page file affect only that page.
public actor NotebookStore {
    public struct Library: Sendable {
        /// Most recently modified first.
        public var notebooks: [Notebook]
        /// Packages whose manifest couldn't be read (damaged, or written by a newer app). Left untouched on disk.
        public var unreadable: [URL]
    }

    static let packageExtension = "ductus"
    static let manifestName = "manifest.json"
    static let pagesDirectory = "pages"
    static let pageExtension = "drawing"

    private let root: URL
    private let files = FileManager.default

    public init(root: URL) {
        self.root = root
    }

    /// Reads every manifest. Page ink is not touched, so this stays fast for large libraries.
    public func loadLibrary() -> Library {
        let entries = (try? files.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
        var notebooks: [Notebook] = []
        var unreadable: [URL] = []
        for package in entries where package.pathExtension == Self.packageExtension {
            do {
                let data = try Data(contentsOf: package.appending(path: Self.manifestName))
                notebooks.append(try NotebookManifest.decode(data))
            } catch {
                unreadable.append(package)
            }
        }
        notebooks.sort { $0.modifiedAt > $1.modifiedAt }
        return Library(notebooks: notebooks, unreadable: unreadable)
    }

    /// Creates the package if needed and writes the manifest.
    public func save(_ notebook: Notebook) throws {
        try files.createDirectory(at: pagesURL(notebook.id), withIntermediateDirectories: true)
        try NotebookManifest.encode(notebook).write(
            to: packageURL(notebook.id).appending(path: Self.manifestName), options: .atomic)
    }

    public func savePage(_ data: Data, page: UUID, in notebook: UUID) throws {
        try files.createDirectory(at: pagesURL(notebook), withIntermediateDirectories: true)
        try data.write(to: pageURL(page, in: notebook), options: .atomic)
    }

    /// The page's stored ink, or nil for a page that has never been written (a blank page).
    public func pageData(page: UUID, in notebook: UUID) throws -> Data? {
        let url = pageURL(page, in: notebook)
        guard files.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    public func deletePageData(page: UUID, in notebook: UUID) throws {
        let url = pageURL(page, in: notebook)
        guard files.fileExists(atPath: url.path) else { return }
        try files.removeItem(at: url)
    }

    public func delete(notebook: UUID) throws {
        let url = packageURL(notebook)
        guard files.fileExists(atPath: url.path) else { return }
        try files.removeItem(at: url)
    }

    private func packageURL(_ notebook: UUID) -> URL {
        root.appending(path: "\(notebook.uuidString).\(Self.packageExtension)")
    }

    private func pagesURL(_ notebook: UUID) -> URL {
        packageURL(notebook).appending(path: Self.pagesDirectory)
    }

    private func pageURL(_ page: UUID, in notebook: UUID) -> URL {
        pagesURL(notebook).appending(path: "\(page.uuidString).\(Self.pageExtension)")
    }
}
