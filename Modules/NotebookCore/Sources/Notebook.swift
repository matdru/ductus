import Foundation

/// One page of a notebook. Its ink lives in a separate file per page (see NotebookStore), so the notebook
/// itself stays small and pages load independently.
public struct Page: Sendable, Codable, Hashable, Identifiable {
    public let id: UUID
    /// A different paper from the notebook's, for this page only.
    public var paperOverride: Paper?
    public var createdAt: Date
    public var modifiedAt: Date

    public init(id: UUID = UUID(), paperOverride: Paper? = nil, createdAt: Date = Date()) {
        self.id = id
        self.paperOverride = paperOverride
        self.createdAt = createdAt
        modifiedAt = createdAt
    }
}

/// A notebook: its look (cover, paper, size) and its ordered pages. Always has at least one page.
public struct Notebook: Sendable, Codable, Hashable, Identifiable {
    public let id: UUID
    public var title: String
    public var cover: Cover
    public var paper: Paper
    public var size: PageSize
    public private(set) var pages: [Page]
    public var isPinned: Bool
    /// The shelf this notebook sits on, if any.
    public var shelfID: UUID?
    public var lastViewedPageID: UUID?
    public var createdAt: Date
    public private(set) var modifiedAt: Date

    public init(
        id: UUID = UUID(), title: String, cover: Cover = .default, paper: Paper = .default, size: PageSize = .a5,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.cover = cover
        self.paper = paper
        self.size = size
        pages = [Page(createdAt: createdAt)]
        isPinned = false
        shelfID = nil
        lastViewedPageID = nil
        self.createdAt = createdAt
        modifiedAt = createdAt
    }

    public func paper(for page: Page) -> Paper {
        page.paperOverride ?? paper
    }

    @discardableResult
    public mutating func appendPage(now: Date = Date()) -> Page {
        insertPage(at: pages.count, now: now)
    }

    /// Inserts a blank page; `index` is clamped to the valid range.
    @discardableResult
    public mutating func insertPage(at index: Int, now: Date = Date()) -> Page {
        let page = Page(createdAt: now)
        pages.insert(page, at: min(max(index, 0), pages.count))
        modifiedAt = now
        return page
    }

    /// Moves the page at `source` so it ends up at `destination`. Out-of-range indices are ignored.
    public mutating func movePage(from source: Int, to destination: Int, now: Date = Date()) {
        guard pages.indices.contains(source), pages.indices.contains(destination), source != destination else {
            return
        }
        pages.insert(pages.remove(at: source), at: destination)
        modifiedAt = now
    }

    /// Removes a page. Refuses to remove the last one, so a notebook always has a page to open to.
    @discardableResult
    public mutating func deletePage(id: UUID, now: Date = Date()) -> Bool {
        guard pages.count > 1, let index = pages.firstIndex(where: { $0.id == id }) else { return false }
        pages.remove(at: index)
        if lastViewedPageID == id { lastViewedPageID = nil }
        modifiedAt = now
        return true
    }

    /// Replaces the stored page with the same id (e.g. after changing its paper).
    public mutating func replacePage(_ page: Page, now: Date = Date()) {
        guard let index = pages.firstIndex(where: { $0.id == page.id }) else { return }
        pages[index] = page
        modifiedAt = now
    }

    /// A copy with fresh notebook and page ids, unpinned, titled "… copy". `pageMap` maps each original page id to
    /// its copy's, so the caller can copy the ink files.
    public func duplicated(now: Date = Date()) -> (notebook: Notebook, pageMap: [UUID: UUID]) {
        var copy = Notebook(title: "\(title) copy", cover: cover, paper: paper, size: size, createdAt: now)
        copy.shelfID = shelfID
        copy.pages = pages.map { Page(paperOverride: $0.paperOverride, createdAt: now) }
        let pageMap = Dictionary(uniqueKeysWithValues: zip(pages.map(\.id), copy.pages.map(\.id)))
        return (copy, pageMap)
    }

    /// Records a change to the notebook's own details (title, look, shelf, pin).
    public mutating func touch(_ date: Date = Date()) {
        modifiedAt = date
    }

    /// Records that a page's ink changed.
    public mutating func markPageEdited(_ id: UUID, at date: Date = Date()) {
        guard let index = pages.firstIndex(where: { $0.id == id }) else { return }
        pages[index].modifiedAt = date
        modifiedAt = date
    }
}

extension Notebook {
    private enum CodingKeys: String, CodingKey {
        case id, title, cover, paper, size, pages, isPinned, shelfID, lastViewedPageID, createdAt, modifiedAt
    }

    /// Only `id` is required; anything else missing takes its default, so manifests from older versions load.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            title: try container.decodeIfPresent(String.self, forKey: .title) ?? "Untitled",
            cover: try container.decodeIfPresent(Cover.self, forKey: .cover) ?? .default,
            paper: try container.decodeIfPresent(Paper.self, forKey: .paper) ?? .default,
            size: try container.decodeIfPresent(PageSize.self, forKey: .size) ?? .a5,
            createdAt: createdAt)
        if let pages = try container.decodeIfPresent([Page].self, forKey: .pages), !pages.isEmpty {
            self.pages = pages
        }
        isPinned = try container.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        shelfID = try container.decodeIfPresent(UUID.self, forKey: .shelfID)
        lastViewedPageID = try container.decodeIfPresent(UUID.self, forKey: .lastViewedPageID)
        modifiedAt = try container.decodeIfPresent(Date.self, forKey: .modifiedAt) ?? createdAt
    }
}
