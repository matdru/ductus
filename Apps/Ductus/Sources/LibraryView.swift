import DesignSystem
import NotebookCore
import SwiftUI

/// The library: shelves in a sidebar, notebooks in the detail column (Graphite design, DRU-39).
struct LibraryView: View {
    @Bindable var model: LibraryModel
    @Environment(\.theme) private var theme
    @Environment(SettingsStore.self) private var settings
    @State private var showsNewNotebook = false
    @State private var showsSettings = false
    @State private var showsNewShelf = false
    @State private var newShelfName = ""
    @State private var openNotebook: Notebook?
    @State private var errorMessage: String?

    var body: some View {
        NavigationSplitView {
            LibrarySidebar(model: model, showsNewShelf: $showsNewShelf, showsSettings: $showsSettings)
                // Narrower than the system default, which takes ~40% of an 11" iPad in portrait.
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 300)
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
            }
        }
        .tint(theme.colors.accent)
        .sheet(isPresented: $showsNewNotebook) {
            NewNotebookSheet(
                shelves: model.shelves, initialShelf: currentShelf, paper: settings.settings.newNotebookPaper,
                size: settings.settings.newNotebookSize
            ) { draft in
                showsNewNotebook = false
                perform { openNotebook = try await model.create(draft) }
            }
        }
        .fullScreenCover(item: $openNotebook) { notebook in
            EditorView(
                notebook: notebook, library: model, shelfName: model.shelf(notebook.shelfID)?.name,
                opensAtLastPage: settings.settings.opensAtLastPage)
        }
        .fullScreenCover(isPresented: $showsSettings) {
            SettingsView(library: model)
        }
        .onChange(of: settings.settings.librarySort, initial: true) { model.sort = $1 }
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
                // `-openSettings` opens Settings on launch.
                if ProcessInfo.processInfo.arguments.contains("-openSettings") { showsSettings = true }
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
    @Binding var showsSettings: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SidebarMetrics.spacing) {
                row("All notebooks", section: .all) { symbol("books.vertical") }
                row("Recent", section: .recent) { symbol("clock") }
                row("Pinned", section: .pinned) { symbol("pin") }

                Text("Shelves".uppercased())
                    .font(.system(size: 11.5, weight: .semibold))
                    .tracking(0.6)
                    .foregroundStyle(theme.colors.textSecondary)
                    .padding(.leading, SidebarMetrics.inset)
                    .padding(.top, 22)
                    .padding(.bottom, 6)

                ForEach(model.shelves) { shelf in
                    row(shelf.name, section: .shelf(shelf.id)) {
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(theme.colors.notebook(NotebookColor(rawValue: shelf.colorName) ?? .graphite))
                            .frame(width: 9, height: 9)
                    }
                    .contextMenu {
                        Button("Delete shelf", systemImage: "trash", role: .destructive) {
                            Task { try? await model.deleteShelf(shelf.id) }
                        }
                    }
                }
                Button {
                    showsNewShelf = true
                } label: {
                    SidebarRow(isSelected: false) {
                        symbol("plus").foregroundStyle(theme.colors.textSecondary)
                    } title: {
                        Text("New shelf").style(theme.typography.body).foregroundStyle(theme.colors.textSecondary)
                    } trailing: {
                        EmptyView()
                    }
                }
                .buttonStyle(SidebarButtonStyle())
            }
            .padding(.horizontal, SidebarMetrics.margin)
            // Lines the first row up with the search field beside it.
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Button {
                showsSettings = true
            } label: {
                SidebarRow(isSelected: false) {
                    symbol("gearshape").foregroundStyle(theme.colors.textSecondary)
                } title: {
                    Text("Settings").style(theme.typography.body).foregroundStyle(theme.colors.textPrimary)
                } trailing: {
                    EmptyView()
                }
            }
            .buttonStyle(SidebarButtonStyle())
            .padding(.horizontal, SidebarMetrics.margin)
            .padding(.vertical, 8)
            .background(theme.colors.sidebar)
            .overlay(alignment: .top) { Rectangle().fill(theme.colors.hairline).frame(height: 1) }
        }
        .background(theme.colors.sidebar)
        .navigationTitle("Ductus")
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 15, weight: .regular))
    }

    /// Graphite's quiet selection: a raised row, not an accent fill. The weight never changes, so text doesn't shift.
    private func row<Icon: View>(_ title: String, section: LibrarySection, @ViewBuilder icon: () -> Icon) -> some View {
        let isSelected = model.section == section
        return Button {
            model.section = section
        } label: {
            SidebarRow(isSelected: isSelected) {
                icon().foregroundStyle(isSelected ? theme.colors.accent : theme.colors.textSecondary)
            } title: {
                Text(title).style(theme.typography.body).foregroundStyle(theme.colors.textPrimary).lineLimit(1)
            } trailing: {
                Text("\(model.count(in: section))").style(theme.typography.mono)
                    .foregroundStyle(theme.colors.textSecondary)
            }
        }
        .buttonStyle(SidebarButtonStyle())
    }
}

/// The sidebar's grid, shared with Settings' section list.
enum SidebarMetrics {
    /// Space between the sidebar's edge and a row's background.
    static let margin = 12.0
    /// Space between a row's background and its icon; the shelf header lines up with it.
    static let inset = 10.0
    static let spacing = 2.0
}

/// One sidebar row on a shared grid: every icon sits in the same column, so every title starts at the same x.
struct SidebarRow<Icon: View, Title: View, Trailing: View>: View {
    let isSelected: Bool
    @ViewBuilder let icon: Icon
    @ViewBuilder let title: Title
    @ViewBuilder let trailing: Trailing
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 10) {
            icon.frame(width: 18, height: 18)
            title
            Spacer(minLength: 8)
            trailing
        }
        .padding(.horizontal, SidebarMetrics.inset)
        .frame(height: 34)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: theme.metrics.radiusSmall).fill(theme.colors.elevated)
            }
        }
        .contentShape(.rect(cornerRadius: theme.metrics.radiusSmall))
    }
}

/// Dims a sidebar row while it's pressed.
struct SidebarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.6 : 1)
    }
}
