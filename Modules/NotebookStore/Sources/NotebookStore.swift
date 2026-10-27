import Foundation
import NotebookCore

/// Notebooks on disk, one package per notebook and one file per page:
///
///     <root>/library.json            LibraryManifest (shelves)
///     <root>/<notebook-id>.ductus/
///       manifest.json             NotebookManifest
///       pages/<page-id>.drawing   opaque page ink (the app stores PKDrawing.dataRepresentation())
///       thumbnails/<page-id>.png  page preview for the library
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
    static let libraryName = "library.json"
    static let thumbnailsDirectory = "thumbnails"

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

    /// Copies a page's ink to another page, e.g. when duplicating a notebook. A blank page has nothing to copy.
    public func copyPageData(page: UUID, from source: UUID, to target: UUID, in destination: UUID) throws {
        guard let data = try pageData(page: page, in: source) else { return }
        try savePage(data, page: target, in: destination)
    }

    /// The library's shelves; none until some are saved.
    public func loadShelves() throws -> [Shelf] {
        let url = root.appending(path: Self.libraryName)
        guard files.fileExists(atPath: url.path) else { return [] }
        return try LibraryManifest.decode(Data(contentsOf: url))
    }

    public func saveShelves(_ shelves: [Shelf]) throws {
        try files.createDirectory(at: root, withIntermediateDirectories: true)
        try LibraryManifest.encode(shelves).write(to: root.appending(path: Self.libraryName), options: .atomic)
    }

    public func saveThumbnail(_ data: Data, page: UUID, in notebook: UUID) throws {
        let url = thumbnailURL(page, in: notebook)
        try files.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    public func thumbnailData(page: UUID, in notebook: UUID) throws -> Data? {
        let url = thumbnailURL(page, in: notebook)
        guard files.fileExists(atPath: url.path) else { return nil }
        return try Data(contentsOf: url)
    }

    /// Removes the page's ink and its thumbnail.
    public func deletePageData(page: UUID, in notebook: UUID) throws {
        for url in [pageURL(page, in: notebook), thumbnailURL(page, in: notebook)]
        where files.fileExists(atPath: url.path) {
            try files.removeItem(at: url)
        }
    }

    public func delete(notebook: UUID) throws {
        let url = packageURL(notebook)
        guard files.fileExists(atPath: url.path) else { return }
        try files.removeItem(at: url)
    }

    /// Bytes on disk, by kind, for Settings' storage breakdown.
    public struct StorageUsage: Sendable, Equatable {
        public var ink: Int64 = 0
        public var thumbnails: Int64 = 0
        /// Manifests and the library file.
        public var other: Int64 = 0
        public var total: Int64 { ink + thumbnails + other }
    }

    public func storageUsage() -> StorageUsage {
        var usage = StorageUsage()
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isRegularFileKey]
        guard let walker = files.enumerator(at: root, includingPropertiesForKeys: Array(keys)) else { return usage }
        for case let url as URL in walker {
            guard let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true else { continue }
            // The bytes the file holds, not its allocated blocks, so small files aren't rounded up to 4 KB.
            let size = Int64(values.fileSize ?? 0)
            switch url.deletingLastPathComponent().lastPathComponent {
            case Self.pagesDirectory: usage.ink += size
            case Self.thumbnailsDirectory: usage.thumbnails += size
            default: usage.other += size
            }
        }
        return usage
    }

    private func packageURL(_ notebook: UUID) -> URL {
        root.appending(path: "\(notebook.uuidString).\(Self.packageExtension)")
    }

    private func pagesURL(_ notebook: UUID) -> URL {
        packageURL(notebook).appending(path: Self.pagesDirectory)
    }

    private func thumbnailURL(_ page: UUID, in notebook: UUID) -> URL {
        packageURL(notebook).appending(path: "\(Self.thumbnailsDirectory)/\(page.uuidString).png")
    }

    private func pageURL(_ page: UUID, in notebook: UUID) -> URL {
        pagesURL(notebook).appending(path: "\(page.uuidString).\(Self.pageExtension)")
    }
}
