import NotebookCore
import PencilKit
import SwiftUI

/// Thumbnails of every page. Tap to jump; long-press to add or delete.
struct PageOverview: View {
    let model: PrototypeModel
    let notebook: Notebook
    let onSelect: (Int) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 20)], spacing: 24) {
                    ForEach(Array(notebook.pages.enumerated()), id: \.element.id) { index, page in
                        Button {
                            onSelect(index)
                        } label: {
                            VStack(spacing: 6) {
                                thumbnail(page)
                                Text("\(index + 1)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Insert page after", systemImage: "plus") {
                                model.update(notebook.id) { $0.insertPage(at: index + 1) }
                            }
                            Button("Delete page", systemImage: "trash", role: .destructive) {
                                model.update(notebook.id) { $0.deletePage(id: page.id) }
                            }
                            .disabled(notebook.pages.count == 1)
                        }
                    }
                }
                .padding(24)
            }
            .background(DeskColor.surface)
            .navigationTitle("Pages")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func thumbnail(_ page: Page) -> some View {
        ZStack {
            PaperView(paper: notebook.paper(for: page), size: notebook.size, showsGrain: false)
            if let drawing = model.drawings[page.id] {
                let size = PageGeometry.canvasSize(notebook.size)
                Image(uiImage: drawing.image(from: CGRect(origin: .zero, size: size), scale: 0.4))
                    .resizable()
            }
        }
        .aspectRatio(notebook.size.width / notebook.size.height, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 2))
        .shadow(color: .black.opacity(0.15), radius: 3, y: 2)
    }
}
