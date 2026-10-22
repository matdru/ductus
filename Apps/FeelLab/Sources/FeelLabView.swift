import InkPencilKit
import SwiftUI

struct FeelLabView: View {
    @State private var model = FeelLabModel()
    @State private var exportMessage: String?

    var body: some View {
        NavigationStack {
            SurfaceView(surface: model.activeView)
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .bottom) {
                    Group {
                        switch model.engine {
                        case .pencilKit:
                            ToolStrip(
                                items: PencilKitSurface.tools, selection: $model.pencilKitTool,
                                title: \.displayName, systemImage: \.systemImage)
                        case .custom:
                            ToolStrip(
                                items: CustomTool.allCases, selection: $model.customTool,
                                title: \.displayName, systemImage: \.systemImage)
                        }
                    }
                    .padding(.bottom, 24)
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            ForEach(ComparisonMode.allCases) { mode in
                                Button(mode.isAvailable ? mode.rawValue : "\(mode.rawValue) (coming soon)") {
                                    model.mode = mode
                                }
                                .disabled(!mode.isAvailable)
                            }
                        } label: {
                            Label(model.mode.rawValue, systemImage: "rectangle.split.2x1")
                        }
                    }
                    ToolbarItem(placement: .principal) {
                        Picker("Engine", selection: $model.engine) {
                            ForEach(Engine.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 260)
                    }
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if model.engine == .pencilKit {
                            Button("Export Strokes", systemImage: "square.and.arrow.down") { exportStrokes() }
                        }
                        Button("Undo", systemImage: "arrow.uturn.backward") { model.activeSurface.undo() }
                        Button("Clear", systemImage: "trash") { model.activeSurface.clear() }
                    }
                }
                .alert(
                    exportMessage ?? "",
                    isPresented: .init(get: { exportMessage != nil }, set: { _ in exportMessage = nil })
                ) {}
        }
    }

    private func exportStrokes() {
        do {
            let url = try model.exportPencilKitStrokes()
            let count = model.pencilKitSurface.canvasView.drawing.strokes.count
            exportMessage = "Saved \(count) strokes to \(url.lastPathComponent)"
        } catch {
            exportMessage = "Export failed: \(error.localizedDescription)"
        }
    }
}

/// Always-visible strip of the active engine's tools.
private struct ToolStrip<Item: Hashable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String
    let systemImage: (Item) -> String

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items, id: \.self) { tool in
                Button {
                    selection = tool
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: systemImage(tool)).font(.title3)
                        Text(title(tool)).font(.caption2)
                    }
                    .frame(width: 72, height: 52)
                    .foregroundStyle(selection == tool ? Color.white : Color.primary)
                    .background(selection == tool ? Color.accentColor : .clear, in: .rect(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .glassEffect(in: .rect(cornerRadius: 18))
    }
}
