import DesignSystem
import SwiftUI

/// A titled group of settings rows on a card, with hairlines between rows.
struct SettingsSection<Content: View>: View {
    let title: String
    var footer: String?
    @ViewBuilder let content: Content
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11.5, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(theme.colors.textSecondary)
                .padding(.leading, 14)
            SettingsCard {
                Group(subviews: content) { rows in
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        if index > 0 {
                            Rectangle().fill(theme.colors.hairline).frame(height: 1).padding(.leading, 14)
                        }
                        row
                    }
                }
            }
            if let footer {
                Text(footer).style(theme.typography.caption).foregroundStyle(theme.colors.textSecondary)
                    .padding(.horizontal, 14)
            }
        }
    }
}

/// The surface every settings group sits on.
struct SettingsCard<Content: View>: View {
    @ViewBuilder let content: Content
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .background(theme.colors.surface, in: .rect(cornerRadius: theme.metrics.radiusMedium))
            .overlay(RoundedRectangle(cornerRadius: theme.metrics.radiusMedium).stroke(theme.colors.hairline))
    }
}

/// One setting: a title, an optional explanation, and its control on the right. A row whose feature isn't built yet
/// is greyed out and says so instead of showing a control.
struct SettingsRow<Control: View>: View {
    let title: String
    var subtitle: String?
    var isComingSoon = false
    @ViewBuilder let control: Control
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).style(theme.typography.body)
                    .foregroundStyle(isComingSoon ? theme.colors.textTertiary : theme.colors.textPrimary)
                if let subtitle {
                    Text(subtitle).style(theme.typography.caption)
                        .foregroundStyle(isComingSoon ? theme.colors.textTertiary : theme.colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            if isComingSoon {
                ComingSoonBadge()
            } else {
                control
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: 48)
        .accessibilityElement(children: isComingSoon ? .combine : .contain)
    }
}

extension SettingsRow where Control == EmptyView {
    /// A row for a feature that's still to come.
    init(comingSoon title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle, isComingSoon: true) { EmptyView() }
    }
}

extension SettingsRow {
    /// A switch.
    init(_ title: String, subtitle: String? = nil, isOn: Binding<Bool>) where Control == SettingsToggle {
        self.init(title: title, subtitle: subtitle) { SettingsToggle(title: title, isOn: isOn) }
    }
}

/// A themed switch without its own label; the row shows the title.
struct SettingsToggle: View {
    let title: String
    @Binding var isOn: Bool
    @Environment(\.theme) private var theme

    var body: some View {
        Toggle(title, isOn: $isOn).labelsHidden().tint(theme.colors.accent)
    }
}

/// A choice from a short list, shown as the current value with a menu.
struct SettingsMenu<Value: Hashable>: View {
    let title: String
    let options: [Value]
    @Binding var selection: Value
    let label: (Value) -> String
    @Environment(\.theme) private var theme

    var body: some View {
        Menu {
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { Text(label($0)).tag($0) }
            }
        } label: {
            SettingsValueLabel(text: label(selection))
        }
        .accessibilityLabel(title)
        .accessibilityValue(label(selection))
    }
}

/// The current value and a chevron, at the end of a row that opens a menu.
struct SettingsValueLabel: View {
    let text: String
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Text(text).style(theme.typography.body)
            Image(systemName: "chevron.up.chevron.down").font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(theme.colors.textSecondary)
        .contentShape(.rect)
    }
}

/// Marks a setting whose feature is still being built.
struct ComingSoonBadge: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Text("Coming soon")
            .font(.system(size: 11.5, weight: .medium))
            .foregroundStyle(theme.colors.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(theme.colors.canvas, in: .capsule)
            .overlay(Capsule().stroke(theme.colors.hairline))
    }
}
