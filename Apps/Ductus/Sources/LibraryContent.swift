import DesignSystem
import NotebookCore
import SwiftUI

/// The detail column: search, recent cards and the notebook list, with every per-notebook action.
struct LibraryContent: View {
    @Bindable var model: LibraryModel
    @Binding var showsNewNotebook: Bool
    /// Brings the sidebar back; `nil` while it's showing.
    let showSidebar: (() -> Void)?
    let open: (Notebook) -> Void
    let perform: (@escaping @MainActor () async throws -> Void) -> Void
    @Environment(\.theme) private var theme
    @FocusState private var searchFocused: Bool
    @State private var renaming: Notebook?
    @State private var newTitle = ""
    @State private var deleting: Notebook?

    var body: some View {
        VStack(spacing: 0) {
            // Stays put while the list scrolls, level with the sidebar's title.
            header
                .padding(.horizontal, 28)
                .padding(.top, 6)
                .padding(.bottom, 10)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(title).style(theme.typography.largeTitle).foregroundStyle(theme.colors.textPrimary)
                        Text(stats).style(theme.typography.mono).foregroundStyle(theme.colors.textSecondary)
                    }
                    let notebooks = model.visibleNotebooks
                    if notebooks.isEmpty {
                        emptySection
                    } else {
                        if model.section == .all && model.searchText.isEmpty {
                            // Cards are where you left off, whatever order the list below is in.
                            recentCards(Array(model.notebooks(in: .recent).prefix(3)))
                        }
                        NotebookTable(notebooks: notebooks, model: model, open: open) { menu(for: $0) }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
        }
        .alert("Rename notebook", isPresented: .init(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Title", text: $newTitle)
            Button("Rename") {
                if let id = renaming?.id {
                    let title = newTitle
                    perform { try await model.rename(id, to: title) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete “\(deleting?.title ?? "")”?",
            isPresented: .init(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete notebook", role: .destructive) {
                if let id = deleting?.id { perform { try await model.delete(id) } }
            }
        } message: {
            Text("Its pages are deleted from this iPad. This can't be undone yet.")
        }
    }

    private var title: String {
        switch model.section {
        case .all: "All notebooks"
        case .recent: "Recent"
        case .pinned: "Pinned"
        case .shelf(let id): model.shelf(id)?.name ?? "Shelf"
        }
    }

    private var stats: String {
        let notebooks = model.notebooks(in: model.section)
        let pages = notebooks.reduce(0) { $0 + $1.pages.count }
        return "\(notebooks.count) notebooks · \(pages) pages"
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let showSidebar {
                Button(action: showSidebar) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(theme.colors.textSecondary)
                        .frame(width: 40, height: 40)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show sidebar")
            }
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(theme.colors.textSecondary)
                TextField("Search notebooks", text: $model.searchText)
                    .focused($searchFocused)
                    .foregroundStyle(theme.colors.textPrimary)
                Text("⌘K").style(theme.typography.mono).foregroundStyle(theme.colors.textTertiary)
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(theme.colors.surface, in: .rect(cornerRadius: theme.metrics.radiusSmall))
            .overlay(RoundedRectangle(cornerRadius: theme.metrics.radiusSmall).stroke(theme.colors.hairline))
            Button {
                showsNewNotebook = true
            } label: {
                Text("New notebook").style(theme.typography.headline)
                    .padding(.horizontal, 14)
                    .frame(height: 40)
                    .foregroundStyle(theme.colors.onAccent)
                    .background(theme.colors.accent, in: .rect(cornerRadius: theme.metrics.radiusSmall))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n")
        }
        // ⌘K focuses search; the button itself stays out of the layout.
        .background {
            Button("Focus search") { searchFocused = true }.keyboardShortcut("k").hidden()
        }
    }

    private func recentCards(_ notebooks: [Notebook]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 14) {
            ForEach(notebooks) { notebook in
                Button {
                    open(notebook)
                } label: {
                    NotebookCard(notebook: notebook, library: model)
                }
                .buttonStyle(.plain)
                .contextMenu { menu(for: notebook) }
            }
        }
    }

    private var emptySection: some View {
        ContentUnavailableView {
            Label(model.searchText.isEmpty ? "Nothing here yet" : "No matches", systemImage: "tray")
                .foregroundStyle(theme.colors.textPrimary)
        } description: {
            Text(
                model.searchText.isEmpty
                    ? "Notebooks you pin or put on this shelf show up here." : "No notebook title matches your search."
            )
            .foregroundStyle(theme.colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    @ViewBuilder
    private func menu(for notebook: Notebook) -> some View {
        Button("Rename", systemImage: "pencil") {
            newTitle = notebook.title
            renaming = notebook
        }
        Button(notebook.isPinned ? "Unpin" : "Pin", systemImage: notebook.isPinned ? "pin.slash" : "pin") {
            perform { try await model.togglePin(notebook.id) }
        }
        Menu("Colour", systemImage: "paintpalette") {
            ForEach(NotebookColor.allCases, id: \.self) { color in
                Button(color.rawValue.capitalized) {
                    perform { try await model.setColor(notebook.id, to: color.rawValue) }
                }
            }
        }
        Menu("Paper", systemImage: "doc.plaintext") {
            ForEach(PaperType.allCases, id: \.self) { type in
                Button(type.displayName) {
                    perform {
                        try await model.setPaper(notebook.id, to: Paper(type: type, color: notebook.paper.color))
                    }
                }
            }
        }
        Menu("Move to shelf", systemImage: "folder") {
            Button("No shelf") { perform { try await model.move(notebook.id, to: nil) } }
            ForEach(model.shelves) { shelf in
                Button(shelf.name) { perform { try await model.move(notebook.id, to: shelf.id) } }
            }
        }
        Button("Duplicate", systemImage: "plus.square.on.square") {
            perform { try await model.duplicate(notebook.id) }
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) { deleting = notebook }
    }
}
