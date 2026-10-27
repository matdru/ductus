extension Theme {
    /// Dark-first and precise: graphite surfaces, hairlines, one soft indigo accent. Graphite Light is its light mode.
    public static let graphite = Theme(
        id: "graphite", name: "Graphite",
        colors: ThemeColors(
            canvas: ThemeColor(light: 0xF7F7F8, dark: 0x0E0F11),
            surface: ThemeColor(light: 0xFFFFFF, dark: 0x17181B),
            elevated: ThemeColor(light: 0xFFFFFF, dark: 0x1D1F23),
            sidebar: ThemeColor(light: 0xF1F1F3, dark: 0x121316),
            hairline: ThemeColor(light: 0xE4E5E8, dark: 0x26282C),
            textPrimary: ThemeColor(light: 0x16171A, dark: 0xEDEDEF),
            textSecondary: ThemeColor(light: 0x5C5E65, dark: 0x8B8D93),
            textTertiary: ThemeColor(light: 0x9A9CA2, dark: 0x6E7076),
            accent: ThemeColor(light: 0x4B55D6, dark: 0x9AA6FF),
            onAccent: ThemeColor(light: 0xFFFFFF, dark: 0x0E0F11),
            accentTint: ThemeColor(light: 0xECEEFE, dark: 0x252836),
            danger: ThemeColor(light: 0xC4332B, dark: 0xFF7A70),
            notebook: [
                .ink: ThemeColor(light: 0x4B55D6, dark: 0x9AA6FF),
                .navy: ThemeColor(light: 0x1F2E4D, dark: 0x7C93C4),
                .teal: ThemeColor(light: 0x2A6563, dark: 0x5FB3AE),
                .forest: ThemeColor(light: 0x2F8A52, dark: 0x6CC08B),
                .mustard: ThemeColor(light: 0xC08A1F, dark: 0xE3B35A),
                .clay: ThemeColor(light: 0xC8632E, dark: 0xE8935E),
                .red: ThemeColor(light: 0xB3261E, dark: 0xF07A70),
                .plum: ThemeColor(light: 0xA2588F, dark: 0xC47BB0),
                .graphite: ThemeColor(light: 0x6C6E75, dark: 0x8B8D93),
                .sand: ThemeColor(light: 0xB49B6C, dark: 0xCDB892),
            ]),
        typography: Typography(
            largeTitle: .init(size: 26, weight: .semibold, tracking: -0.5),
            title: .init(size: 20, weight: .semibold, tracking: -0.3),
            headline: .init(size: 15, weight: .semibold),
            body: .init(size: 15, weight: .regular),
            caption: .init(size: 13, weight: .regular),
            mono: .init(size: 12.5, weight: .regular, design: .monospaced)),
        metrics: Metrics(radiusSmall: 7, radiusMedium: 10, radiusLarge: 14, spacing: 8))

    /// The earlier clean neutral look; kept as a second theme so swapping stays honest.
    public static let studio = Theme(
        id: "studio", name: "Studio",
        colors: ThemeColors(
            canvas: ThemeColor(light: 0xF4F5F7, dark: 0x15171B),
            surface: ThemeColor(light: 0xFFFFFF, dark: 0x1E2126),
            elevated: ThemeColor(light: 0xFFFFFF, dark: 0x2A2E35),
            sidebar: ThemeColor(light: 0xECEEF1, dark: 0x191B20),
            hairline: ThemeColor(light: 0xE1E4E8, dark: 0x2A2E35),
            textPrimary: ThemeColor(light: 0x1C1F25, dark: 0xECEEF2),
            textSecondary: ThemeColor(light: 0x5F646E, dark: 0x9AA0AA),
            textTertiary: ThemeColor(light: 0x9AA0AA, dark: 0x6B7079),
            accent: ThemeColor(light: 0x2457C5, dark: 0x7AA2FF),
            onAccent: ThemeColor(light: 0xFFFFFF, dark: 0x0D1530),
            accentTint: ThemeColor(light: 0xE8EEFB, dark: 0x22304F),
            danger: ThemeColor(light: 0xB3261E, dark: 0xFF8A80),
            notebook: [
                .ink: ThemeColor(light: 0x2457C5, dark: 0x7AA2FF),
                .navy: ThemeColor(light: 0x1F2E4D, dark: 0x7C93C4),
                .teal: ThemeColor(light: 0x2A6563, dark: 0x5FB3AE),
                .forest: ThemeColor(light: 0x2E6B3F, dark: 0x5FB07A),
                .mustard: ThemeColor(light: 0xC9962E, dark: 0xE0B04F),
                .clay: ThemeColor(light: 0xD9733A, dark: 0xE8935E),
                .red: ThemeColor(light: 0xB3261E, dark: 0xF07A70),
                .plum: ThemeColor(light: 0x8C3F77, dark: 0xC47BB0),
                .graphite: ThemeColor(light: 0x6B7079, dark: 0x9AA0AA),
                .sand: ThemeColor(light: 0xCDB892, dark: 0xCDB892),
            ]),
        typography: Typography(
            largeTitle: .init(size: 30, weight: .bold, tracking: -0.6),
            title: .init(size: 20, weight: .semibold),
            headline: .init(size: 16, weight: .semibold),
            body: .init(size: 15, weight: .regular),
            caption: .init(size: 13, weight: .regular),
            mono: .init(size: 13, weight: .regular, design: .monospaced)),
        metrics: Metrics(radiusSmall: 10, radiusMedium: 14, radiusLarge: 16, spacing: 8))
}
