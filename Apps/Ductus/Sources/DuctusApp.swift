import DesignSystem
import NotebookStore
import SwiftUI

@main
struct DuctusApp: App {
    /// The app's settings; the whole app re-skins when the theme or appearance changes.
    @State private var settings = SettingsStore()
    @State private var library = LibraryModel(
        store: NotebookStore(root: URL.applicationSupportDirectory.appending(path: "Notebooks")))

    var body: some Scene {
        WindowGroup {
            LibraryView(model: library)
                .environment(settings)
                .environment(\.theme, Theme.named(settings.settings.themeID))
                .preferredColorScheme(settings.settings.appearance.colorScheme)
        }
    }
}
