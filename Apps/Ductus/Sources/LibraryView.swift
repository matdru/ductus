import DesignSystem
import SwiftUI

/// The shelf of notebooks. Empty until notebooks and storage land (DRU-16, DRU-17, DRU-39).
struct LibraryView: View {
    @Binding var themeID: String
    @State private var showsScratchPage = false
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            ContentUnavailableView {
                Label {
                    Text("Your shelf is empty").style(theme.typography.title)
                        .foregroundStyle(theme.colors.textPrimary)
                } icon: {
                    Image(systemName: "books.vertical").foregroundStyle(theme.colors.textSecondary)
                }
            } description: {
                Text("Notebooks you create will live here.").style(theme.typography.body)
                    .foregroundStyle(theme.colors.textSecondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.colors.canvas)
            .navigationTitle("Notebooks")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // Temporary until the Settings page (DRU-45).
                    Picker("Theme", systemImage: "paintpalette", selection: $themeID) {
                        ForEach(Theme.all) { Text($0.name).tag($0.id) }
                    }
                    .pickerStyle(.menu)
                    // Temporary way to write in Ductus until the page editor exists (DRU-35).
                    Button("Scratch Page", systemImage: "scribble") { showsScratchPage = true }
                }
            }
            .fullScreenCover(isPresented: $showsScratchPage) {
                ScratchPageView()
            }
        }
        .tint(theme.colors.accent)
    }
}

/// A single unsaved PencilKit page.
private struct ScratchPageView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.theme) private var theme

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
        .tint(theme.colors.accent)
    }
}
