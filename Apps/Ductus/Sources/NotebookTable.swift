import DesignSystem
import NotebookCore
import SwiftUI

/// The dense notebook list: name, shelf, pages, last edited (Graphite's table).
struct NotebookTable<Menu: View>: View {
    let notebooks: [Notebook]
    let model: LibraryModel
    let open: (Notebook) -> Void
    @ViewBuilder let menu: (Notebook) -> Menu
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            row(name: Text("Name"), shelf: Text("Shelf"), pages: Text("Pages"), edited: Text("Edited"))
                .textCase(.uppercase)
                .font(theme.typography.caption.font)
                .foregroundStyle(theme.colors.textSecondary)
                .frame(height: 34)
            ForEach(notebooks) { notebook in
                Rectangle().fill(theme.colors.hairline).frame(height: 1)
                Button {
                    open(notebook)
                } label: {
                    notebookRow(notebook)
                }
                .buttonStyle(.plain)
                .contextMenu { menu(notebook) }
            }
        }
        .background(theme.colors.surface)
        .clipShape(.rect(cornerRadius: theme.metrics.radiusMedium))
        .overlay(RoundedRectangle(cornerRadius: theme.metrics.radiusMedium).stroke(theme.colors.hairline))
    }

    private func notebookRow(_ notebook: Notebook) -> some View {
        row(
            name: Text(notebook.title).style(theme.typography.body).foregroundStyle(theme.colors.textPrimary),
            shelf: Text(model.shelf(notebook.shelfID)?.name ?? "—").style(theme.typography.body)
                .foregroundStyle(theme.colors.textSecondary),
            pages: Text("\(notebook.pages.count)").style(theme.typography.mono).foregroundStyle(
                theme.colors.textSecondary),
            edited: Text(notebook.modifiedAt, format: .relative(presentation: .named)).style(theme.typography.mono)
                .foregroundStyle(theme.colors.textSecondary),
            tint: notebook.tint(in: theme), pinned: notebook.isPinned
        )
        .frame(minHeight: 46)
        .contentShape(.rect)
    }

    private func row(
        name: Text, shelf: Text, pages: Text, edited: Text, tint: ThemeColor? = nil, pinned: Bool = false
    ) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 10) {
                if let tint { RoundedRectangle(cornerRadius: 2).fill(tint).frame(width: 8, height: 8) }
                name.lineLimit(1)
                if pinned { Image(systemName: "pin.fill").font(.caption2).foregroundStyle(theme.colors.textTertiary) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            shelf.lineLimit(1).frame(width: 150, alignment: .leading)
            pages.frame(width: 70, alignment: .leading)
            edited.lineLimit(1).frame(width: 130, alignment: .leading)
        }
        .padding(.horizontal, 14)
    }
}
