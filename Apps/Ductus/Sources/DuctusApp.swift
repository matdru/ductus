import DesignSystem
import NotebookStore
import SwiftUI

@main
struct DuctusApp: App {
    /// The app's settings; the whole app re-skins when the theme or appearance changes.
    @State private var settings = SettingsStore(defaults: Launch.defaults)
    @State private var library = LibraryModel(store: NotebookStore(root: Launch.notebooksRoot))

    /// Where data lives. UI tests (`-uiTesting`) start every launch on an empty library and default settings, so
    /// they never depend on, or change, what's on the simulator.
    @MainActor private enum Launch {
        static let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")

        static let notebooksRoot =
            isUITesting
            ? URL.temporaryDirectory.appending(path: "UITesting-\(UUID().uuidString)")
            : URL.applicationSupportDirectory.appending(path: "Notebooks")

        static let defaults: UserDefaults = {
            guard isUITesting, let defaults = UserDefaults(suiteName: "UITesting") else { return .standard }
            defaults.removePersistentDomain(forName: "UITesting")
            return defaults
        }()
    }

    var body: some Scene {
        WindowGroup {
            LibraryView(model: library)
                .environment(settings)
                .environment(\.theme, Theme.named(settings.settings.themeID))
                .preferredColorScheme(settings.settings.appearance.colorScheme)
        }
    }
}
