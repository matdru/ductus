import InkPencilKit
import SwiftUI

struct FeelLabView: View {
    @State private var model = FeelLabModel()

    var body: some View {
        NavigationStack {
            SurfaceView(surface: model.activeView)
                .ignoresSafeArea(edges: .bottom)
                .overlay(alignment: .bottom) {
                    if model.engine == .pencilKit {
                        PencilKitToolBar(selection: $model.pencilKitTool)
                            .padding(.bottom, 24)
                    }
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
                        Button("Undo", systemImage: "arrow.uturn.backward") { model.activeSurface.undo() }
                        Button("Clear", systemImage: "trash") { model.activeSurface.clear() }
                    }
                }
        }
    }
}

/// Always-visible strip of PencilKit inks and erasers, shown only on the PencilKit engine.
private struct PencilKitToolBar: View {
    @Binding var selection: PencilKitTool

    var body: some View {
        HStack(spacing: 4) {
            ForEach(PencilKitSurface.tools, id: \.self) { tool in
                Button {
                    selection = tool
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tool.systemImage).font(.title3)
                        Text(tool.displayName).font(.caption2)
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
