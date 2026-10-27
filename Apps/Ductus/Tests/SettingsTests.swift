import Foundation
import NotebookCore
import Testing
import UIKit

@testable import Ductus

struct AppSettingsTests {
    func decode(_ json: String) throws -> AppSettings {
        try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
    }

    @Test func defaultsMatchTheDesign() {
        let settings = AppSettings()
        #expect(!settings.drawsWithFinger)
        #expect(settings.pencilDoubleTap == .system)
        #expect(settings.newNotebookPaper == .default)
        #expect(settings.newNotebookSize == .a5)
        #expect(settings.opensAtLastPage)
        #expect(settings.twoFingerTapUndoes && settings.threeFingerTapRedoes)
        #expect(settings.themeID == "graphite")
        #expect(settings.appearance == .automatic)
        #expect(settings.librarySort == .lastEdited)
        #expect(settings.previewsPagesOnCards)
    }

    @Test func roundTrips() throws {
        var settings = AppSettings()
        settings.drawsWithFinger = true
        settings.pencilDoubleTap = .previous
        settings.newNotebookPaper = Paper(type: .squared, color: .cream)
        settings.newNotebookSize = .a4
        settings.opensAtLastPage = false
        settings.threeFingerTapRedoes = false
        settings.themeID = "studio"
        settings.appearance = .dark
        settings.librarySort = .title
        settings.previewsPagesOnCards = false
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(AppSettings.self, from: data) == settings)
    }

    /// Settings saved by an older version (missing keys) or a newer one (unknown values) still load.
    @Test func decodingIsTolerant() throws {
        let settings = try decode(#"{"drawsWithFinger": true, "appearance": "sepia", "librarySort": "colour"}"#)
        #expect(settings.drawsWithFinger)
        #expect(settings.appearance == .automatic)
        #expect(settings.librarySort == .lastEdited)
        #expect(settings.opensAtLastPage)
        #expect(try decode("{}") == AppSettings())
    }

    @Test func appearanceMapsToAnInterfaceStyle() {
        #expect(AppSettings.Appearance.automatic.interfaceStyle == .unspecified)
        #expect(AppSettings.Appearance.light.interfaceStyle == .light)
        #expect(AppSettings.Appearance.dark.interfaceStyle == .dark)
    }

    @Test func doubleTapFollowsTheSystemOnlyWhenAsked() {
        #expect(AppSettings.PencilDoubleTap.system.action(system: .switchPrevious) == .switchPrevious)
        #expect(AppSettings.PencilDoubleTap.eraser.action(system: .switchPrevious) == .switchEraser)
        #expect(AppSettings.PencilDoubleTap.previous.action(system: .switchEraser) == .switchPrevious)
        #expect(AppSettings.PencilDoubleTap.off.action(system: .switchEraser) == .ignore)
    }
}

@MainActor
struct SettingsStoreTests {
    let defaults: UserDefaults

    init() throws {
        defaults = try #require(UserDefaults(suiteName: "SettingsStoreTests-\(UUID().uuidString)"))
    }

    @Test func changesSurviveRelaunch() {
        let store = SettingsStore(defaults: defaults)
        store.settings.drawsWithFinger = true
        store.settings.librarySort = .created
        let relaunched = SettingsStore(defaults: defaults)
        #expect(relaunched.settings.drawsWithFinger)
        #expect(relaunched.settings.librarySort == .created)
    }

    /// The library's temporary theme picker saved the theme under its own key; it carries over.
    @Test func keepsTheThemeChosenBeforeSettingsExisted() {
        defaults.set("studio", forKey: "theme")
        #expect(SettingsStore(defaults: defaults).settings.themeID == "studio")
    }

    @Test func unreadableSettingsFallBackToDefaults() {
        defaults.set(Data("not json".utf8), forKey: SettingsStore.key)
        #expect(SettingsStore(defaults: defaults).settings == AppSettings())
    }
}
