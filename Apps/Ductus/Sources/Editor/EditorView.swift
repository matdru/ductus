import DesignSystem
import NotebookCore
import SwiftUI

/// The page editor (Graphite): breadcrumb header, tool rail, the zoomable canvas and a status bar.
struct EditorView: View {
    @State private var model: EditorModel
    @State private var controller = CanvasController()
    let shelfName: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.theme) private var theme

    init(notebook: Notebook, library: LibraryModel, shelfName: String?) {
        _model = State(initialValue: EditorModel(notebook: notebook, library: library, store: library.store))
        self.shelfName = shelfName
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack(alignment: .topLeading) {
                if model.isLoaded {
                    NotebookCanvasView(
                        model: model, controller: controller, gutterColor: theme.colors.canvas,
                        hairlineColor: theme.colors.hairline)
                }
                EditorToolRail(tool: $model.tool).padding(14)
            }
            statusBar
        }
        .background(theme.colors.canvas)
        #if DEBUG
            .background(TouchRecorderInstaller())
        #endif
        .tint(theme.colors.accent)
        .task { await model.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { Task { await model.saveNow() } }
        }
        .onDisappear { Task { await model.saveNow() } }
    }

    private var header: some View {
        HStack(spacing: 6) {
            iconButton("Back to notebooks", "chevron.left") {
                Task {
                    await model.saveNow()
                    dismiss()
                }
            }
            if let shelfName {
                Text(shelfName).style(theme.typography.body).foregroundStyle(theme.colors.textSecondary)
                Text("/").foregroundStyle(theme.colors.textTertiary)
            }
            Text(model.notebook.title).style(theme.typography.headline).foregroundStyle(theme.colors.textPrimary)
                .lineLimit(1)
            Text("/").foregroundStyle(theme.colors.textTertiary)
            Text("p. \(model.currentPage + 1)").style(theme.typography.mono).foregroundStyle(theme.colors.textPrimary)
            Spacer()
            iconButton("Undo", "arrow.uturn.backward", isEnabled: controller.canUndo) { controller.undo() }
                .keyboardShortcut("z")
            iconButton("Redo", "arrow.uturn.forward", isEnabled: controller.canRedo) { controller.redo() }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            iconButton("Add page", "doc.badge.plus") {
                Task {
                    try? await model.appendPage()
                    controller.scroll(toPage: model.notebook.pages.count - 1)
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 50)
        .background(theme.colors.sidebar)
        .overlay(alignment: .bottom) { Rectangle().fill(theme.colors.hairline).frame(height: 1) }
    }

    private var statusBar: some View {
        HStack(spacing: 18) {
            #if DEBUG
                TouchRecorderButton()
            #endif
            HStack(spacing: 6) {
                Circle().fill(saveColor).frame(width: 6, height: 6)
                Text(saveLabel)
            }
            Text("\(model.notebook.paper.type.displayName) · \(model.notebook.size.rawValue.uppercased())")
            Text("Page \(model.currentPage + 1) of \(model.notebook.pages.count)")
            Spacer()
            Text("\(model.tool.kind.name) · \(model.tool.color.rawValue.capitalized)")
            Text("\(controller.zoomPercent)%")
        }
        .font(theme.typography.mono.font)
        .foregroundStyle(theme.colors.textSecondary)
        .padding(.horizontal, 16)
        .frame(height: 30)
        .background(theme.colors.sidebar)
        .overlay(alignment: .top) { Rectangle().fill(theme.colors.hairline).frame(height: 1) }
    }

    private var saveLabel: String {
        switch model.saveState {
        case .saved: "Saved"
        case .unsaved, .saving: "Saving…"
        case .failed: "Not saved"
        }
    }

    private var saveColor: ThemeColor {
        switch model.saveState {
        case .saved: theme.colors.notebook(.forest)
        case .unsaved, .saving: theme.colors.textTertiary
        case .failed: theme.colors.danger
        }
    }

    private func iconButton(
        _ label: String, _ systemImage: String, isEnabled: Bool = true, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 40, height: 40)
                .foregroundStyle(isEnabled ? theme.colors.textPrimary : theme.colors.textTertiary)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }
}

/// The vertical tool rail: inks, eraser, lasso and ink colours.
struct EditorToolRail: View {
    @Binding var tool: EditorTool
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 2) {
            ForEach(EditorTool.Kind.allCases, id: \.self) { kind in
                Button {
                    tool.kind = kind
                } label: {
                    Image(systemName: kind.systemImage)
                        .font(.system(size: 18))
                        .frame(width: 44, height: 44)
                        .foregroundStyle(tool.kind == kind ? theme.colors.accent : theme.colors.textPrimary)
                        .background(
                            tool.kind == kind ? theme.colors.accentTint : theme.colors.surface,
                            in: .rect(cornerRadius: theme.metrics.radiusSmall)
                        )
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(kind.name)
                if kind == .marker {
                    Rectangle().fill(theme.colors.hairline).frame(width: 28, height: 1).padding(.vertical, 4)
                }
            }
            Rectangle().fill(theme.colors.hairline).frame(width: 28, height: 1).padding(.vertical, 4)
            ForEach(EditorTool.InkColor.allCases, id: \.self) { color in
                Button {
                    tool.color = color
                } label: {
                    Circle().fill(Color(uiColor: color.uiColor)).frame(width: 20, height: 20)
                        .overlay(
                            Circle().stroke(theme.colors.accent, lineWidth: tool.color == color ? 2 : 0).padding(-3)
                        )
                        .frame(width: 44, height: 34)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(color.rawValue.capitalized)
            }
        }
        .padding(5)
        .background(theme.colors.surface, in: .rect(cornerRadius: theme.metrics.radiusMedium))
        .overlay(RoundedRectangle(cornerRadius: theme.metrics.radiusMedium).stroke(theme.colors.hairline))
    }
}
