import DesignSystem
import NotebookCore
import SwiftUI

/// The library: shelves in a sidebar, notebooks in the detail column (Graphite design, DRU-39).
struct LibraryView: View {
    @Bindable var model: LibraryModel
    @Binding var themeID: String
    @Environment(\.theme) private var theme
    @State private var showsNewNotebook = false
    @State private var showsNewShelf = false
    @State private var newShelfName = ""
    @State private var openNotebook: Notebook?
    @State private var errorMessage: String?

    var body: some View {
        NavigationSplitView {
            LibrarySidebar(model: model, showsNewShelf: $showsNewShelf)
        } detail: {
            NavigationStack {
                Group {
                    if model.isLoaded && model.notebooks.isEmpty {
                        FirstLaunchView { draft in perform { openNotebook = try await model.create(draft) } }
                    } else {
                        LibraryContent(model: model, showsNewNotebook: $showsNewNotebook, open: open, perform: perform)
                    }
                }
                .background(theme.colors.canvas)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        // Temporary until the Settings page (DRU-45).
                        Picker("Theme", systemImage: "paintpalette", selection: $themeID) {
                            ForEach(Theme.all) { Text($0.name).tag($0.id) }
                        }
                        .pickerStyle(.menu)
                    }
                }
            }
        }
        .tint(theme.colors.accent)
        .sheet(isPresented: $showsNewNotebook) {
            NewNotebookSheet(shelves: model.shelves, initialShelf: currentShelf) { draft in
                showsNewNotebook = false
                perform { openNotebook = try await model.create(draft) }
            }
        }
        .fullScreenCover(item: $openNotebook) { notebook in
            EditorView(notebook: notebook, library: model, shelfName: model.shelf(notebook.shelfID)?.name)
        }
        .alert("New shelf", isPresented: $showsNewShelf) {
            TextField("Name", text: $newShelfName)
            Button("Create") {
                let name = newShelfName
                newShelfName = ""
                perform { try await model.createShelf(name: name, colorName: nextShelfColor) }
            }
            Button("Cancel", role: .cancel) { newShelfName = "" }
        }
        .alert(
            "Something went wrong", isPresented: .init(get: { errorMessage != nil }, set: { _ in errorMessage = nil })
        ) {
        } message: {
            Text(errorMessage ?? "")
        }
        .task {
            await model.load()
            #if DEBUG
                // Screenshots: `-openFirstNotebook` opens the most recent notebook on launch.
                if ProcessInfo.processInfo.arguments.contains("-openFirstNotebook") {
                    openNotebook = model.notebooks(in: .all).first
                }
            #endif
        }
    }

    private var currentShelf: UUID? {
        if case .shelf(let id) = model.section { id } else { nil }
    }

    /// Cycles through the palette so new shelves are told apart at a glance.
    private var nextShelfColor: String {
        let palette = NotebookColor.allCases
        return palette[model.shelves.count % palette.count].rawValue
    }

    private func open(_ notebook: Notebook) {
        openNotebook = notebook
    }

    /// Runs a library change and reports a failure instead of losing it silently.
    private func perform(_ action: @escaping @MainActor () async throws -> Void) {
        Task {
            do { try await action() } catch { errorMessage = error.localizedDescription }
        }
    }
}

/// All notebooks, Recent, Pinned and the shelves, with counts.
private struct LibrarySidebar: View {
    @Bindable var model: LibraryModel
    @Binding var showsNewShelf: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        List {
            Section {
                row("All notebooks", section: .all) { Image(systemName: "books.vertical") }
                row("Recent", section: .recent) { Image(systemName: "clock") }
                row("Pinned", section: .pinned) { Image(systemName: "pin") }
            }
            Section("Shelves") {
                ForEach(model.shelves) { shelf in
                    row(shelf.name, section: .shelf(shelf.id)) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.colors.notebook(NotebookColor(rawValue: shelf.colorName) ?? .graphite))
                            .frame(width: 10, height: 10)
                    }
                    .contextMenu {
                        Button("Delete shelf", systemImage: "trash", role: .destructive) {
                            Task { try? await model.deleteShelf(shelf.id) }
                        }
                    }
                }
                Button("New shelf", systemImage: "plus") { showsNewShelf = true }
                    .foregroundStyle(theme.colors.textSecondary)
                    .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(theme.colors.sidebar)
        .navigationTitle("Ductus")
    }

    /// Graphite's quiet selection: a raised row, not an accent fill.
    private func row<Icon: View>(_ title: String, section: LibrarySection, @ViewBuilder icon: () -> Icon) -> some View {
        let isSelected = model.section == section
        return Button {
            model.section = section
        } label: {
            Label {
                HStack {
                    Text(title).foregroundStyle(theme.colors.textPrimary)
                    Spacer()
                    Text("\(model.count(in: section))").style(theme.typography.mono)
                        .foregroundStyle(theme.colors.textSecondary)
                }
            } icon: {
                icon().foregroundStyle(isSelected ? theme.colors.accent : theme.colors.textSecondary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .fontWeight(isSelected ? .semibold : .regular)
        .listRowBackground(
            RoundedRectangle(cornerRadius: theme.metrics.radiusSmall)
                .fill(isSelected ? theme.colors.elevated : theme.colors.sidebar)
                .padding(.horizontal, 10))
    }
}
