import SwiftUI

/// The shelf of notebooks. Empty until notebooks and storage land (DRU-16, DRU-17, DRU-39).
struct LibraryView: View {
    @State private var showsScratchPage = false

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label("Your shelf is empty", systemImage: "books.vertical")
            } description: {
                Text("Notebooks you create will live here.")
            }
            .navigationTitle("Notebooks")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // Temporary way to write in Ductus until the page editor exists (DRU-35).
                    Button("Scratch Page", systemImage: "scribble") { showsScratchPage = true }
                }
            }
            .fullScreenCover(isPresented: $showsScratchPage) {
                ScratchPageView()
            }
        }
    }
}

/// A single unsaved PencilKit page.
private struct ScratchPageView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CanvasView()
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Scratch Page")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}
