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
    @Environment(SettingsStore.self) private var settings

    init(notebook: Notebook, library: LibraryModel, shelfName: String?, opensAtLastPage: Bool) {
        _model = State(
            initialValue: EditorModel(
                notebook: notebook, library: library, store: library.store, opensAtLastPage: opensAtLastPage))
        self.shelfName = shelfName
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack(alignment: .topLeading) {
                if model.isLoaded {
                    NotebookCanvasView(
                        model: model, controller: controller, gutterColor: theme.colors.canvas,
                        hairlineColor: theme.colors.hairline, settings: settings.settings,
                        penCase: settings.penCase,
                        pencilTapped: { settings.penCase.pencilTapped($0) })
                }
                PenCaseRail(penCase: Bindable(settings).penCase).padding(14)
            }
            statusBar
        }
        .background(theme.colors.canvas)
        #if DEBUG
            .background(TouchRecorderInstaller())
        #endif
        .tint(theme.colors.accent)
        .onChange(of: settings.penCase.selection) { _, tool in TouchRecorder.event("tool", ["tool": "\(tool)"]) }
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
            Text(toolDescription)
            Text("\(controller.zoomPercent)%")
        }
        .font(theme.typography.mono.font)
        .foregroundStyle(theme.colors.textSecondary)
        .padding(.horizontal, 16)
        .frame(height: 30)
        .background(theme.colors.sidebar)
        .overlay(alignment: .top) { Rectangle().fill(theme.colors.hairline).frame(height: 1) }
    }

    private var toolDescription: String {
        let penCase = settings.penCase
        switch penCase.selection {
        case .pen:
            guard let pen = penCase.selectedPen else { return "" }
            return "\(pen.ink.name) · \(String(format: "%.1f", pen.widthInPoints)) pt · \(pen.colorName)"
        case .eraser: return penCase.eraser == .stroke ? "Eraser · Strokes" : "Eraser · Pixels"
        case .lasso: return "Lasso"
        }
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
