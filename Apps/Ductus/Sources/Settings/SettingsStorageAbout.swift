import DesignSystem
import NotebookStore
import SwiftUI

// MARK: Storage & Pro

struct StorageSettings: View {
    let library: LibraryModel
    @State private var usage: NotebookStore.StorageUsage?
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsSection(title: "On this iPad") {
                usageSummary.padding(16)
            }
            SettingsCard {
                SettingsRow(comingSoon: "Keep deleted notebooks")
                divider
                SettingsRow(comingSoon: "Export all notebooks as PDF")
                divider
                SettingsRow(comingSoon: "Rebuild search index")
            }
        }
        .task { usage = await library.store.storageUsage() }
        VStack(alignment: .leading, spacing: 14) {
            SettingsSection(title: "Ductus Pro") {
                proCard.padding(18)
            }
            SettingsCard {
                SettingsRow(comingSoon: "iCloud sync")
                divider
                SettingsRow(comingSoon: "Restore purchases")
            }
        }
    }

    private var divider: some View {
        Rectangle().fill(theme.colors.hairline).frame(height: 1).padding(.leading, 14)
    }

    private var usageSummary: some View {
        let notebooks = library.notebooks
        let pages = notebooks.reduce(0) { $0 + $1.pages.count }
        let total = max(usage?.total ?? 0, 1)
        let parts = [
            UsagePart(name: "Ink", bytes: usage?.ink ?? 0, color: theme.colors.accent),
            UsagePart(name: "Thumbnails", bytes: usage?.thumbnails ?? 0, color: theme.colors.notebook(.clay)),
            UsagePart(name: "Notebook details", bytes: usage?.other ?? 0, color: theme.colors.notebook(.forest)),
        ]
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(usage.map { Self.bytes($0.total) } ?? "…").style(theme.typography.title)
                    .foregroundStyle(theme.colors.textPrimary)
                Text("used by \(notebooks.count) notebooks · \(pages) pages").style(theme.typography.caption)
                    .foregroundStyle(theme.colors.textSecondary)
            }
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    ForEach(parts, id: \.name) { part in
                        Rectangle().fill(part.color)
                            .frame(width: proxy.size.width * Double(part.bytes) / Double(total))
                    }
                    Spacer(minLength: 0)
                }
            }
            .frame(height: 10)
            .background(theme.colors.canvas)
            .clipShape(.capsule)
            HStack(spacing: 18) {
                ForEach(parts, id: \.name) { part in
                    HStack(spacing: 6) {
                        Circle().fill(part.color).frame(width: 8, height: 8)
                        Text("\(part.name) · \(Self.bytes(part.bytes))").style(theme.typography.caption)
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                }
            }
        }
    }

    private var proCard: some View {
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: "icloud.and.arrow.up")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(theme.colors.onAccent)
                .frame(width: 56, height: 56)
                .background(theme.colors.accent, in: .rect(cornerRadius: theme.metrics.radiusMedium))
            VStack(alignment: .leading, spacing: 8) {
                Text("Sync and back up with iCloud").style(theme.typography.headline)
                    .foregroundStyle(theme.colors.textPrimary)
                ForEach(
                    [
                        "Your notebooks on every iPad",
                        "Backed up to your own iCloud: we never see your notes",
                        "Cancel any time; nothing on this iPad is ever locked",
                    ], id: \.self
                ) { line in
                    Label {
                        Text(line).style(theme.typography.body).foregroundStyle(theme.colors.textPrimary)
                    } icon: {
                        Image(systemName: "checkmark").font(.system(size: 13, weight: .bold))
                            .foregroundStyle(theme.colors.accent)
                    }
                }
            }
            Spacer(minLength: 0)
            ComingSoonBadge()
        }
    }

    /// One kind of file in the breakdown.
    private struct UsagePart {
        let name: String
        let bytes: Int64
        let color: ThemeColor
    }

    static func bytes(_ count: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        // "0 KB", not "Zero KB".
        formatter.allowsNonnumericFormatting = false
        return formatter.string(fromByteCount: count)
    }
}

// MARK: About

struct AboutSettings: View {
    @Environment(\.theme) private var theme

    var body: some View {
        SettingsSection(title: "Ductus") {
            SettingsRow(title: "Version") {
                Text(version).style(theme.typography.mono).foregroundStyle(theme.colors.textSecondary)
            }
            SettingsRow(comingSoon: "Send feedback")
            SettingsRow(comingSoon: "Privacy policy")
        }
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "–"
        let build = info?["CFBundleVersion"] as? String ?? "–"
        return "\(short) (\(build))"
    }
}
