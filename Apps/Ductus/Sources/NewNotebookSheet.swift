import DesignSystem
import NotebookCore
import SwiftUI

/// Title, colour, paper, size and shelf, with a live preview (DRU-40).
struct NewNotebookSheet: View {
    let shelves: [Shelf]
    let onCreate: (NotebookDraft) -> Void
    @State private var draft: NotebookDraft
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    init(shelves: [Shelf], initialShelf: UUID?, onCreate: @escaping (NotebookDraft) -> Void) {
        self.shelves = shelves
        self.onCreate = onCreate
        _draft = State(initialValue: NotebookDraft(shelfID: initialShelf))
    }

    var body: some View {
        NavigationStack {
            HStack(alignment: .top, spacing: 24) {
                preview
                Form {
                    TextField("Title", text: $draft.title)
                    Section("Colour") { colorSwatches }
                    Section("Paper") {
                        Picker("Type", selection: $draft.paper.type) {
                            ForEach(PaperType.allCases, id: \.self) { Text($0.displayName).tag($0) }
                        }
                        Picker("Colour", selection: $draft.paper.color) {
                            ForEach(PaperColor.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                        }
                        Picker("Size", selection: $draft.size) {
                            ForEach(PageSize.allCases, id: \.self) { Text($0.rawValue.uppercased()).tag($0) }
                        }
                        .pickerStyle(.segmented)
                    }
                    Section("Shelf") {
                        Picker("Shelf", selection: $draft.shelfID) {
                            Text("No shelf").tag(UUID?.none)
                            ForEach(shelves) { Text($0.name).tag(UUID?.some($0.id)) }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .padding(20)
            .background(theme.colors.canvas)
            .navigationTitle("New notebook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Create") { onCreate(draft) } }
            }
        }
        .tint(theme.colors.accent)
    }

    private var preview: some View {
        let tint = theme.colors.notebook(NotebookColor(rawValue: draft.colorName) ?? .ink)
        return VStack(spacing: 12) {
            PaperGlimpse(paper: draft.paper)
                .aspectRatio(draft.size.width / draft.size.height, contentMode: .fit)
                .overlay(alignment: .top) { Rectangle().fill(tint).frame(height: 5) }
                .clipShape(.rect(cornerRadius: 3))
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(theme.colors.hairline))
            Text(draft.title.isEmpty ? "Untitled" : draft.title).style(theme.typography.headline)
                .foregroundStyle(theme.colors.textPrimary)
            Text("\(draft.paper.type.displayName) · \(draft.size.rawValue.uppercased())").style(theme.typography.mono)
                .foregroundStyle(theme.colors.textSecondary)
        }
        .frame(width: 210)
        .padding(.top, 12)
    }

    private var colorSwatches: some View {
        HStack(spacing: 10) {
            ForEach(NotebookColor.allCases, id: \.self) { color in
                Button {
                    draft.colorName = color.rawValue
                } label: {
                    Circle().fill(theme.colors.notebook(color)).frame(width: 28, height: 28)
                        .overlay(
                            Circle().stroke(
                                theme.colors.textPrimary, lineWidth: draft.colorName == color.rawValue ? 2 : 0)
                        )
                        .padding(3)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(color.rawValue.capitalized)
            }
        }
    }
}

/// First launch: pick a paper and start writing in one tap.
struct FirstLaunchView: View {
    let onStart: (NotebookDraft) -> Void
    @State private var paper = PaperType.dotGrid
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 26) {
            VStack(spacing: 8) {
                Text("Start your first notebook").style(theme.typography.largeTitle).foregroundStyle(
                    theme.colors.textPrimary)
                Text("Pick a paper. You can change everything later.").style(theme.typography.body)
                    .foregroundStyle(theme.colors.textSecondary)
            }
            HStack(spacing: 14) {
                ForEach([PaperType.fineLined, .dotGrid, .squared, .blank], id: \.self) { type in
                    Button {
                        paper = type
                    } label: {
                        VStack(spacing: 10) {
                            PaperGlimpse(paper: Paper(type: type, color: .ivory))
                                .frame(width: 96, height: 134)
                                .clipShape(.rect(cornerRadius: 3))
                            Text(type.displayName).style(theme.typography.caption).foregroundStyle(
                                theme.colors.textPrimary)
                        }
                        .padding(12)
                        .background(theme.colors.surface, in: .rect(cornerRadius: theme.metrics.radiusLarge))
                        .overlay(
                            RoundedRectangle(cornerRadius: theme.metrics.radiusLarge)
                                .stroke(
                                    paper == type ? theme.colors.accent : theme.colors.hairline,
                                    lineWidth: paper == type ? 2 : 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            Button {
                onStart(NotebookDraft(title: "My notebook", paper: Paper(type: paper, color: .ivory)))
            } label: {
                Text("Start writing").style(theme.typography.headline)
                    .padding(.horizontal, 26)
                    .frame(height: 46)
                    .foregroundStyle(theme.colors.onAccent)
                    .background(theme.colors.accent, in: .rect(cornerRadius: theme.metrics.radiusMedium))
            }
            .buttonStyle(.plain)
            Text("Notes stay on this iPad. iCloud sync comes with Ductus Pro.").style(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
