import Foundation
import NotebookCore
import SwiftUI
import UIKit

/// Every setting Ductus has, kept on this iPad. Only settings with a working feature live here; rows for features
/// still to come show in Settings as "Coming soon" and get a property when the feature lands.
struct AppSettings: Equatable, Codable {
    // Writing & Pages
    var drawsWithFinger = false
    var pencilDoubleTap = PencilDoubleTap.system
    var newNotebookPaper = Paper.default
    var newNotebookSize = PageSize.a5
    var opensAtLastPage = true
    var twoFingerTapUndoes = true
    var threeFingerTapRedoes = true

    // Appearance
    var themeID = "graphite"
    var appearance = Appearance.automatic
    var librarySort = NotebookSort.lastEdited
    var previewsPagesOnCards = true

    enum Appearance: String, CatalogueValue {
        case automatic, light, dark
        static let fallback = Appearance.automatic

        /// `nil` follows the system.
        var colorScheme: ColorScheme? {
            switch self {
            case .automatic: nil
            case .light: .light
            case .dark: .dark
            }
        }

        var interfaceStyle: UIUserInterfaceStyle {
            switch self {
            case .automatic: .unspecified
            case .light: .light
            case .dark: .dark
            }
        }
    }

    /// What a double-tap (or squeeze) on the Pencil does.
    enum PencilDoubleTap: String, CatalogueValue {
        case system, eraser, previous, off
        static let fallback = PencilDoubleTap.system

        /// The action to take, given the iPadOS Settings choice that `system` follows.
        func action(system: PencilTapAction) -> PencilTapAction {
            switch self {
            case .system: system
            case .eraser: .switchEraser
            case .previous: .switchPrevious
            case .off: .ignore
            }
        }
    }

    enum NotebookSort: String, CatalogueValue {
        case lastEdited, created, title
        static let fallback = NotebookSort.lastEdited
    }
}

extension AppSettings {
    private enum CodingKeys: String, CodingKey {
        case drawsWithFinger, pencilDoubleTap, newNotebookPaper, newNotebookSize, opensAtLastPage
        case twoFingerTapUndoes, threeFingerTapRedoes, themeID, appearance, librarySort, previewsPagesOnCards
    }

    /// Every key is optional, so settings from older or newer versions load; anything missing takes its default.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? container.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        drawsWithFinger = value(.drawsWithFinger, defaults.drawsWithFinger)
        pencilDoubleTap = value(.pencilDoubleTap, defaults.pencilDoubleTap)
        newNotebookPaper = value(.newNotebookPaper, defaults.newNotebookPaper)
        newNotebookSize = value(.newNotebookSize, defaults.newNotebookSize)
        opensAtLastPage = value(.opensAtLastPage, defaults.opensAtLastPage)
        twoFingerTapUndoes = value(.twoFingerTapUndoes, defaults.twoFingerTapUndoes)
        threeFingerTapRedoes = value(.threeFingerTapRedoes, defaults.threeFingerTapRedoes)
        themeID = value(.themeID, defaults.themeID)
        appearance = value(.appearance, defaults.appearance)
        librarySort = value(.librarySort, defaults.librarySort)
        previewsPagesOnCards = value(.previewsPagesOnCards, defaults.previewsPagesOnCards)
    }
}

/// Holds the settings and the pen case, and saves every change straight away.
@MainActor @Observable
final class SettingsStore {
    static let key = "settings"
    static let penCaseKey = "penCase"
    /// Where the library's temporary theme picker kept the theme before Settings existed.
    static let legacyThemeKey = "theme"

    var settings: AppSettings {
        didSet {
            guard settings != oldValue, let data = try? JSONEncoder().encode(settings) else { return }
            defaults.set(data, forKey: Self.key)
        }
    }

    /// Your pens and the tool in hand, shared by every notebook.
    var penCase: PenCase {
        didSet {
            guard penCase != oldValue, let data = try? JSONEncoder().encode(penCase) else { return }
            defaults.set(data, forKey: Self.penCaseKey)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        penCase =
            defaults.data(forKey: Self.penCaseKey).flatMap { try? JSONDecoder().decode(PenCase.self, from: $0) }
            ?? .default
        let saved = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(AppSettings.self, from: $0) }
        if let saved {
            settings = saved
        } else {
            var settings = AppSettings()
            if let theme = defaults.string(forKey: Self.legacyThemeKey) { settings.themeID = theme }
            self.settings = settings
        }
    }
}
