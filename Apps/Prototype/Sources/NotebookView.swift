import NotebookCore
import SwiftUI

/// An open notebook: pages (turned or scrolled) on a desk surface, a slim top bar and the ink strip.
struct NotebookView: View {
    let model: PrototypeModel
    let notebookID: UUID
    @State private var currentIndex = 0
    @State private var scrolledPageID: UUID?
    @State private var showsOverview = false
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        if let notebook = model.notebook(notebookID) {
            content(notebook)
                .background(DeskColor.surface.ignoresSafeArea())
                .overlay(alignment: .bottom) { ToolStrip(model: model).padding(.bottom, 20) }
                .navigationTitle(notebook.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar(notebook) }
                .sheet(isPresented: $showsOverview) {
                    PageOverview(model: model, notebook: notebook) { index in
                        jump(to: index, in: notebook)
                        showsOverview = false
                    }
                }
                .onChange(of: scrolledPageID) {
                    if let id = scrolledPageID, let index = notebook.pages.firstIndex(where: { $0.id == id }) {
                        currentIndex = index
                    }
                }
        }
    }

    @ViewBuilder
    private func content(_ notebook: Notebook) -> some View {
        switch model.navigation {
        case .turn:
            PageCurlView(model: model, notebookID: notebookID, currentIndex: $currentIndex)
                .ignoresSafeArea(edges: .bottom)
        case .scroll:
            ScrollView {
                LazyVStack(spacing: 28) {
                    ForEach(notebook.pages) { page in
                        PageView(model: model, notebook: notebook, page: page).id(page.id)
                    }
                    Button {
                        model.update(notebookID) { $0.appendPage() }
                    } label: {
                        Label("Add page", systemImage: "plus").font(.system(.body, design: .serif))
                            .padding(.vertical, 18).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .scrollTargetLayout()
                .padding(.horizontal, 36)
                .padding(.top, 20)
                .padding(.bottom, 140)
            }
            .scrollPosition(id: $scrolledPageID, anchor: .top)
        }
    }

    @ToolbarContentBuilder
    private func toolbar(_ notebook: Notebook) -> some ToolbarContent {
        ToolbarItem(placement: .principal) {
            VStack(spacing: 0) {
                Text(notebook.title).font(.system(.headline, design: .serif))
                Text("Page \(min(currentIndex, notebook.pages.count - 1) + 1) of \(notebook.pages.count)")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button("Undo", systemImage: "arrow.uturn.backward") { undoManager?.undo() }
            Button("Redo", systemImage: "arrow.uturn.forward") { undoManager?.redo() }
            Picker("Navigation", selection: Bindable(model).navigation) {
                ForEach(PageNavigation.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)
            Button("Pages", systemImage: "square.grid.2x2") { showsOverview = true }
        }
    }

    private func jump(to index: Int, in notebook: Notebook) {
        currentIndex = index
        if notebook.pages.indices.contains(index) {
            scrolledPageID = notebook.pages[index].id
        }
    }
}

/// The always-visible ink strip: PencilKit inks, eraser, lasso and a few colours.
struct ToolStrip: View {
    @Bindable var model: PrototypeModel
    let colors: [Color] = [.black, Color(hex: 0x1F3A7A), Color(hex: 0xB3261E), Color(hex: 0x2E6B3F)]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(PrototypeTool.all, id: \.self) { tool in
                Button {
                    model.tool = tool
                } label: {
                    Image(systemName: tool.systemImage)
                        .font(.title3)
                        .frame(width: 44, height: 40)
                        .foregroundStyle(model.tool == tool ? Color.white : Color.primary)
                        .background(model.tool == tool ? Color.accentColor : .clear, in: .rect(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tool.name)
            }
            Divider().frame(height: 28)
            ForEach(colors, id: \.self) { color in
                Button {
                    model.inkColor = color
                } label: {
                    Circle().fill(color).frame(width: 24, height: 24)
                        .overlay(Circle().stroke(.white, lineWidth: model.inkColor == color ? 3 : 0))
                        .shadow(radius: 1)
                        .frame(width: 34, height: 40)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}

extension PrototypeTool {
    var name: String {
        switch self {
        case .ink(let type): String(describing: type)
        case .eraser: "Eraser"
        case .lasso: "Lasso"
        }
    }

    var systemImage: String {
        switch self {
        case .ink(.fountainPen): "pencil.tip"
        case .ink(.pen): "pencil"
        case .ink(.pencil): "pencil.and.scribble"
        case .ink(.marker): "highlighter"
        case .ink: "pencil.line"
        case .eraser: "eraser"
        case .lasso: "lasso"
        }
    }
}
