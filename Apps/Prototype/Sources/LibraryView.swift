import NotebookCore
import SwiftUI

@main
struct PrototypeApp: App {
    @State private var model = PrototypeModel()

    var body: some Scene {
        WindowGroup {
            LibraryView(model: model)
        }
    }
}

/// The shelf. Tactile shows 3D covers on a desk and zooms into the notebook; clean shows flat cards.
struct LibraryView: View {
    @Bindable var model: PrototypeModel
    @State private var path: [UUID] = []
    @State private var showsNewNotebook = false
    @Namespace private var covers

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: model.style == .tactile ? 170 : 220), spacing: 36)],
                    spacing: 56
                ) {
                    newNotebookTile
                    ForEach(model.notebooks) { notebook in
                        NavigationLink(value: notebook.id) { tile(notebook) }
                            .buttonStyle(.plain)
                            .matchedTransitionSource(id: notebook.id, in: covers)
                    }
                }
                .padding(40)
            }
            .background(background.ignoresSafeArea())
            .navigationTitle("Notebooks")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Picker("Style", selection: $model.style) {
                        ForEach(PrototypeStyle.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
            }
            .onChange(of: model.style) { model.applyStyleDefaults() }
            .onAppear {
                // For screenshots: `-openNotebook <index>` opens a sample notebook on launch.
                let arguments = ProcessInfo.processInfo.arguments
                if let flag = arguments.firstIndex(of: "-openNotebook"), flag + 1 < arguments.count,
                    let index = Int(arguments[flag + 1]), model.notebooks.indices.contains(index)
                {
                    path = [model.notebooks[index].id]
                }
            }
            .navigationDestination(for: UUID.self) { id in
                NotebookView(model: model, notebookID: id)
                    .navigationTransition(.zoom(sourceID: id, in: covers))
            }
            .sheet(isPresented: $showsNewNotebook) {
                NewNotebookSheet { notebook in
                    model.add(notebook)
                    showsNewNotebook = false
                    path.append(notebook.id)
                }
            }
        }
    }

    @ViewBuilder
    private var background: some View {
        if model.style == .tactile {
            LinearGradient(colors: [DeskColor.surface, DeskColor.surfaceDark], startPoint: .top, endPoint: .bottom)
        } else {
            Color(.systemGroupedBackground)
        }
    }

    @ViewBuilder
    private func tile(_ notebook: Notebook) -> some View {
        if model.style == .tactile {
            CoverView(notebook: notebook)
        } else {
            CleanCard(notebook: notebook)
        }
    }

    private var newNotebookTile: some View {
        Button {
            showsNewNotebook = true
        } label: {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
                .foregroundStyle(.secondary)
                .overlay {
                    Label("New Notebook", systemImage: "plus").font(.system(.headline, design: .serif))
                }
                .aspectRatio(PageSize.a5.width / PageSize.a5.height, contentMode: .fit)
        }
        .buttonStyle(.plain)
    }
}

/// The clean style: a flat card with a glimpse of the paper, a colour band and the title.
private struct CleanCard: View {
    let notebook: Notebook

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PaperView(paper: notebook.paper, size: notebook.size, showsGrain: false)
                .frame(height: 150, alignment: .top)
                .clipped()
                .overlay(alignment: .top) { CoverPalette.color(notebook.cover.colorName).frame(height: 8) }
            VStack(alignment: .leading, spacing: 2) {
                Text(notebook.title).font(.headline)
                Text("\(notebook.pages.count) pages · \(notebook.paper.type.displayName)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 14))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}
