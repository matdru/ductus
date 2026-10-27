import DesignSystem
import SwiftUI

@main
struct DuctusApp: App {
    /// The chosen theme's id; the whole app re-skins when it changes.
    @AppStorage("theme") private var themeID = Theme.graphite.id

    var body: some Scene {
        WindowGroup {
            LibraryView(themeID: $themeID)
                .environment(\.theme, Theme.named(themeID))
        }
    }
}
