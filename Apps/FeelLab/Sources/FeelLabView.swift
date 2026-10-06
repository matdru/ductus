import SwiftUI

struct FeelLabView: View {
    @State private var model = FeelLabModel()

    var body: some View {
        NavigationStack {
            SurfaceView(surface: model.activeView)
                .ignoresSafeArea(edges: .bottom)
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
