import Testing

@testable import DesignSystem

struct ThemeTests {
    @Test func hexParsesChannels() {
        let color = RGBA(hex: 0x4B55D6)
        #expect(abs(color.red - 75.0 / 255) < 1e-9)
        #expect(abs(color.green - 85.0 / 255) < 1e-9)
        #expect(abs(color.blue - 214.0 / 255) < 1e-9)
        #expect(color.alpha == 1)
    }

    @Test func contrastRatioMatchesWCAG() {
        #expect(abs(RGBA(hex: 0x000000).contrastRatio(with: RGBA(hex: 0xFFFFFF)) - 21) < 0.01)
        #expect(abs(RGBA(hex: 0x777777).contrastRatio(with: RGBA(hex: 0xFFFFFF)) - 4.48) < 0.01)
        #expect(RGBA(hex: 0x123456).contrastRatio(with: RGBA(hex: 0x123456)) == 1)
    }

    /// Every text/background pairing the app uses must stay readable in every theme, light and dark (WCAG AA).
    @Test(arguments: Theme.all)
    func textIsReadable(theme: Theme) {
        let c = theme.colors
        let pairs: [ContrastPair] = [
            ContrastPair("textPrimary on canvas", c.textPrimary, on: c.canvas),
            ContrastPair("textPrimary on surface", c.textPrimary, on: c.surface),
            ContrastPair("textPrimary on sidebar", c.textPrimary, on: c.sidebar),
            ContrastPair("textSecondary on canvas", c.textSecondary, on: c.canvas),
            ContrastPair("textSecondary on surface", c.textSecondary, on: c.surface),
            ContrastPair("textSecondary on sidebar", c.textSecondary, on: c.sidebar),
            ContrastPair("onAccent on accent", c.onAccent, on: c.accent),
            ContrastPair("accent on surface", c.accent, on: c.surface),
            ContrastPair("danger on surface", c.danger, on: c.surface),
        ]
        for pair in pairs {
            for mode in ThemeColor.Mode.allCases {
                let ratio = pair.text[mode].contrastRatio(with: pair.background[mode])
                #expect(ratio >= 4.5, "\(theme.id) \(mode): \(pair.name) is \(ratio)")
            }
        }
    }

    @Test(arguments: Theme.all)
    func everyThemeDefinesTheWholeNotebookPalette(theme: Theme) {
        for name in NotebookColor.allCases {
            #expect(theme.colors.notebook[name] != nil, "\(theme.id) is missing \(name)")
        }
    }

    @Test func themesHaveUniqueIDsAndLookUpByID() {
        let ids = Theme.all.map(\.id)
        #expect(Set(ids).count == ids.count)
        #expect(Theme.named("studio").id == "studio")
        #expect(Theme.named("graphite").id == "graphite")
    }

    @Test func unknownThemeFallsBackToGraphite() {
        #expect(Theme.named("no-such-theme").id == Theme.graphite.id)
        #expect(Theme.graphite.id == "graphite")
    }
}

struct ContrastPair {
    let name: String
    let text: ThemeColor
    let background: ThemeColor

    init(_ name: String, _ text: ThemeColor, on background: ThemeColor) {
        self.name = name
        self.text = text
        self.background = background
    }
}
