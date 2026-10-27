import DesignSystem
import NotebookStore
import SwiftUI

@main
struct DuctusApp: App {
    /// The chosen theme's id; the whole app re-skins when it changes.
    @AppStorage("theme") private var themeID = Theme.graphite.id
    @State private var library = LibraryModel(
        store: NotebookStore(root: URL.applicationSupportDirectory.appending(path: "Notebooks")))

    var body: some Scene {
        WindowGroup {
            LibraryView(model: library, themeID: $themeID)
                .environment(\.theme, Theme.named(themeID))
        }
    }
}
