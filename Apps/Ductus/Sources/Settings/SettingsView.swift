import DesignSystem
import NotebookCore
import NotebookStore
import SwiftUI

/// Settings, reached from the bottom of the library sidebar (DRU-45): sections on the left, their settings on the
/// right. Every change takes effect and is saved straight away. Rows for features still being built show
/// "Coming soon".
struct SettingsView: View {
    let library: LibraryModel
    @State private var category = Self.initialCategory
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    enum Category: String, CaseIterable {
        case writing, appearance, storage, about

        var title: String {
            switch self {
            case .writing: "Writing & Pages"
            case .appearance: "Appearance & Sound"
            case .storage: "Storage & Pro"
            case .about: "About"
            }
        }

        var symbol: String {
            switch self {
            case .writing: "pencil.tip"
            case .appearance: "circle.lefthalf.filled"
            case .storage: "externaldrive"
            case .about: "info.circle"
            }
        }
    }

    /// Screenshots: `-settingsCategory storage` opens that section.
    private static var initialCategory: Category {
        #if DEBUG
            UserDefaults.standard.string(forKey: "settingsCategory").flatMap(Category.init(rawValue:)) ?? .writing
        #else
            .writing
        #endif
    }

    var body: some View {
        HStack(spacing: 0) {
            sections
                .frame(width: 260)
                .background(theme.colors.sidebar)
                .overlay(alignment: .trailing) { Rectangle().fill(theme.colors.hairline).frame(width: 1) }
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    Text(category.title).style(theme.typography.largeTitle).foregroundStyle(theme.colors.textPrimary)
                    switch category {
                    case .writing: WritingSettings()
                    case .appearance: AppearanceSettings()
                    case .storage: StorageSettings(library: library)
                    case .about: AboutSettings()
                    }
                }
                .frame(maxWidth: 640, alignment: .leading)
                .padding(.horizontal, 32)
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(theme.colors.canvas)
        }
        .tint(theme.colors.accent)
    }

    private var sections: some View {
        VStack(alignment: .leading, spacing: SidebarMetrics.spacing) {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.system(size: 15, weight: .semibold))
                    Text("Notebooks").style(theme.typography.body)
                }
                .foregroundStyle(theme.colors.accent)
                .frame(height: 44)
                .contentShape(.rect)
            }
            .buttonStyle(SidebarButtonStyle())
            .padding(.leading, SidebarMetrics.inset - 4)
            Text("Settings").style(theme.typography.largeTitle).foregroundStyle(theme.colors.textPrimary)
                .padding(.leading, SidebarMetrics.inset)
                .padding(.top, 4)
                .padding(.bottom, 14)
            ForEach(Category.allCases, id: \.self) { item in
                Button {
                    category = item
                } label: {
                    SidebarRow(isSelected: category == item) {
                        Image(systemName: item.symbol).font(.system(size: 15))
                            .foregroundStyle(category == item ? theme.colors.accent : theme.colors.textSecondary)
                    } title: {
                        Text(item.title).style(theme.typography.body).foregroundStyle(theme.colors.textPrimary)
                            .lineLimit(1)
                    } trailing: {
                        EmptyView()
                    }
                }
                .buttonStyle(SidebarButtonStyle())
            }
            Spacer()
            Text("Settings are kept on this iPad.").style(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)
                .padding(.horizontal, SidebarMetrics.inset)
        }
        .padding(.horizontal, SidebarMetrics.margin)
        .padding(.vertical, 12)
    }
}

// MARK: Writing & Pages

private struct WritingSettings: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        @Bindable var store = store
        SettingsSection(title: "Pencil") {
            SettingsRow(
                "Draw with finger", subtitle: "Off: only Apple Pencil draws. Fingers scroll and zoom.",
                isOn: $store.settings.drawsWithFinger)
            SettingsRow(title: "Double-tap on Pencil") {
                SettingsMenu(
                    title: "Double-tap on Pencil", options: AppSettings.PencilDoubleTap.allCases,
                    selection: $store.settings.pencilDoubleTap, label: \.title)
            }
            SettingsRow(comingSoon: "Squeeze on Pencil Pro")
            SettingsRow(comingSoon: "Show nib while hovering")
            SettingsRow(comingSoon: "Focus mode", subtitle: "Hide the header while you write.")
        }
        SettingsSection(title: "Pages") {
            SettingsRow(comingSoon: "Move between pages", subtitle: "Scroll, or turn pages like a book.")
            SettingsRow(title: "Paper for new notebooks") {
                Menu {
                    Picker("Paper", selection: $store.settings.newNotebookPaper.type) {
                        ForEach(PaperType.allCases, id: \.self) { Text($0.displayName).tag($0) }
                    }
                    Picker("Colour", selection: $store.settings.newNotebookPaper.color) {
                        ForEach(PaperColor.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                    }
                } label: {
                    let paper = store.settings.newNotebookPaper
                    SettingsValueLabel(text: "\(paper.type.displayName) · \(paper.color.rawValue.capitalized)")
                }
                .accessibilityLabel("Paper for new notebooks")
            }
            SettingsRow(title: "Page size for new notebooks") {
                SettingsMenu(
                    title: "Page size for new notebooks", options: PageSize.allCases,
                    selection: $store.settings.newNotebookSize, label: { $0.rawValue.uppercased() })
            }
            SettingsRow(comingSoon: "Show page numbers")
            SettingsRow("Open notebooks at the last page viewed", isOn: $store.settings.opensAtLastPage)
        }
        SettingsSection(title: "Gestures") {
            SettingsRow("Two-finger tap to undo", isOn: $store.settings.twoFingerTapUndoes)
            SettingsRow("Three-finger tap to redo", isOn: $store.settings.threeFingerTapRedoes)
        }
    }
}

extension AppSettings.PencilDoubleTap {
    var title: String {
        switch self {
        case .system: "Use system setting"
        case .eraser: "Switch to eraser"
        case .previous: "Switch to last tool"
        case .off: "Do nothing"
        }
    }
}

// MARK: Appearance & Sound

private struct AppearanceSettings: View {
    @Environment(SettingsStore.self) private var store

    var body: some View {
        @Bindable var store = store
        SettingsSection(title: "Theme") {
            HStack(spacing: 24) {
                ForEach(AppSettings.Appearance.allCases, id: \.self) { appearance in
                    AppearanceOption(appearance: appearance, selection: $store.settings.appearance)
                }
            }
            .padding(16)
            SettingsRow(title: "Style") {
                SettingsMenu(
                    title: "Style", options: Theme.all.map(\.id), selection: $store.settings.themeID,
                    label: { Theme.named($0).name })
            }
        }
        SettingsSection(
            title: "Paper in dark mode", footer: "Paper stays bright in dark mode for now, so ink colours stay true."
        ) {
            SettingsRow(comingSoon: "Dimmed paper", subtitle: "Softer paper that keeps ink colours true.")
            SettingsRow(comingSoon: "Night paper", subtitle: "Dark paper, light rules. Black ink shows as white.")
        }
        SettingsSection(title: "Sound & haptics") {
            SettingsRow(comingSoon: "Page sounds")
            SettingsRow(comingSoon: "Haptic feedback")
        }
        SettingsSection(title: "Library") {
            SettingsRow(title: "Sort notebooks by") {
                SettingsMenu(
                    title: "Sort notebooks by", options: AppSettings.NotebookSort.allCases,
                    selection: $store.settings.librarySort, label: \.title)
            }
            SettingsRow(
                "Preview pages on cards", subtitle: "Show your latest writing on recent notebooks.",
                isOn: $store.settings.previewsPagesOnCards)
        }
    }
}

extension AppSettings.NotebookSort {
    var title: String {
        switch self {
        case .lastEdited: "Last edited"
        case .created: "Date created"
        case .title: "Title"
        }
    }
}

/// A small picture of the library in light, dark or both, to choose the appearance by.
private struct AppearanceOption: View {
    let appearance: AppSettings.Appearance
    @Binding var selection: AppSettings.Appearance
    @Environment(\.theme) private var theme

    var body: some View {
        let isSelected = selection == appearance
        Button {
            selection = appearance
        } label: {
            VStack(spacing: 8) {
                preview
                    .frame(width: 112, height: 76)
                    .clipShape(.rect(cornerRadius: theme.metrics.radiusSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: theme.metrics.radiusSmall)
                            .stroke(
                                isSelected ? theme.colors.accent : theme.colors.hairline,
                                lineWidth: isSelected ? 2.5 : 1))
                Text(title).style(isSelected ? theme.typography.headline : theme.typography.body)
                    .foregroundStyle(isSelected ? theme.colors.accent : theme.colors.textPrimary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(SidebarButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var title: String {
        switch appearance {
        case .automatic: "Automatic"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    @ViewBuilder private var preview: some View {
        switch appearance {
        case .automatic:
            HStack(spacing: 0) {
                mode(\.light).frame(width: 56).clipped()
                mode(\.dark).frame(width: 56, alignment: .trailing).clipped()
            }
        case .light: mode(\.light)
        case .dark: mode(\.dark)
        }
    }

    /// The theme's canvas and sidebar in one mode, with a sheet of paper on the desk.
    private func mode(_ shade: KeyPath<ThemeColor, RGBA>) -> some View {
        HStack(spacing: 0) {
            theme.colors.sidebar[keyPath: shade].color.frame(width: 26)
            ZStack(alignment: .topLeading) {
                theme.colors.canvas[keyPath: shade].color
                PaperColor.ivory.swatch
                    .frame(width: 38, height: 52)
                    .clipShape(.rect(cornerRadius: 2))
                    // Ivory on a light desk needs an edge to read as a sheet.
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(theme.colors.hairline[keyPath: shade].color))
                    .padding(.leading, 14)
                    .padding(.top, 12)
            }
        }
        .frame(width: 112, height: 76)
    }
}
