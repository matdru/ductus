import NotebookCore
import SwiftUI

/// Pick a cover, paper and size with a live preview, like choosing a notebook off a stationery shelf.
struct NewNotebookSheet: View {
    let onCreate: (Notebook) -> Void
    @State private var title = ""
    @State private var material = CoverMaterial.cloth
    @State private var colorName = "navy"
    @State private var paperType = PaperType.fineLined
    @State private var paperColor = PaperColor.ivory
    @State private var size = PageSize.a5
    @Environment(\.dismiss) private var dismiss

    private var draft: Notebook {
        Notebook(
            title: title.isEmpty ? "Untitled" : title, cover: Cover(material: material, colorName: colorName),
            paper: Paper(type: paperType, color: paperColor), size: size)
    }

    var body: some View {
        NavigationStack {
            HStack(alignment: .top, spacing: 28) {
                VStack(spacing: 24) {
                    CoverView(notebook: draft).frame(height: 260)
                    PaperView(paper: draft.paper, size: size).frame(height: 260)
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                }
                .frame(width: 220)
                .padding(.top, 12)
                Form {
                    TextField("Title", text: $title)
                    Section("Cover") {
                        Picker("Material", selection: $material) {
                            ForEach(CoverMaterial.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        swatches(CoverPalette.names, selection: $colorName) { CoverPalette.color($0) }
                    }
                    Section("Paper") {
                        Picker("Type", selection: $paperType) {
                            ForEach(PaperType.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        swatches(PaperColor.allCases, selection: $paperColor) { $0.color }
                        Picker("Size", selection: $size) {
                            ForEach(PageSize.allCases, id: \.self) { Text($0.rawValue.uppercased()).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .padding(24)
            .background(DeskColor.surface)
            .navigationTitle("New Notebook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Create") { onCreate(draft) } }
            }
        }
    }

    private func swatches<Value: Hashable>(
        _ values: [Value], selection: Binding<Value>, color: @escaping (Value) -> Color
    ) -> some View {
        HStack(spacing: 10) {
            ForEach(values, id: \.self) { value in
                Circle().fill(color(value)).frame(width: 26, height: 26)
                    .overlay(Circle().stroke(Color.accentColor, lineWidth: selection.wrappedValue == value ? 3 : 0))
                    .overlay(Circle().stroke(.black.opacity(0.12), lineWidth: 0.5))
                    .onTapGesture { selection.wrappedValue = value }
            }
        }
        .padding(.vertical, 4)
    }
}
