import DesignSystem
import NotebookCore
import PencilKit
import SwiftUI

/// The tool rail: your pens, then the eraser, the lasso and a button to add a pen. Tap a tool to pick it up; tap the
/// one in hand to change it (DRU-36).
struct PenCaseRail: View {
    @Binding var penCase: PenCase
    @State private var editing: PenCase.Tool?
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 4) {
            ForEach(penCase.pens) { pen in
                toolButton(.pen(pen.id), label: "\(pen.ink.name), \(pen.colorName)") { isSelected in
                    PenSwatch(pen: pen, isSelected: isSelected)
                }
                .popover(isPresented: isEditing(.pen(pen.id)), arrowEdge: .leading) {
                    PenSettings(penCase: $penCase, penID: pen.id) { editing = nil }
                }
            }
            separator
            toolButton(.eraser, label: "Eraser") { _ in symbol("eraser") }
                .popover(isPresented: isEditing(.eraser), arrowEdge: .leading) {
                    EraserSettings(eraser: $penCase.eraser)
                }
            toolButton(.lasso, label: "Lasso") { _ in symbol("lasso") }
            if penCase.canAddPen {
                separator
                Button {
                    let pen = penCase.addPen()
                    editing = .pen(pen.id)
                } label: {
                    symbol("plus").foregroundStyle(theme.colors.textSecondary)
                        .frame(width: 44, height: 40)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add a pen")
            }
        }
        .padding(6)
        .background(theme.colors.surface, in: .rect(cornerRadius: theme.metrics.radiusLarge))
        .overlay(RoundedRectangle(cornerRadius: theme.metrics.radiusLarge).stroke(theme.colors.hairline))
        #if DEBUG
            // Screenshots: `-editTool pen` or `-editTool eraser` opens that tool's settings on launch.
            .task {
                switch UserDefaults.standard.string(forKey: "editTool") {
                case "pen": editing = penCase.selection
                case "eraser": editing = .eraser
                default: break
                }
            }
        #endif
    }

    private var separator: some View {
        Rectangle().fill(theme.colors.hairline).frame(width: 24, height: 1).padding(.vertical, 3)
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 17, weight: .regular))
    }

    private func isEditing(_ tool: PenCase.Tool) -> Binding<Bool> {
        Binding(get: { editing == tool }, set: { if !$0 { editing = nil } })
    }

    /// Picks the tool up, or opens its settings if it's already in hand. The lasso has none.
    private func toolButton<Label: View>(
        _ tool: PenCase.Tool, label: String, @ViewBuilder content: (Bool) -> Label
    ) -> some View {
        let isSelected = penCase.selection == tool
        let isPen = if case .pen = tool { true } else { false }
        return Button {
            if isSelected {
                if tool != .lasso { editing = tool }
            } else {
                penCase.select(tool)
            }
        } label: {
            content(isSelected)
                .foregroundStyle(isSelected ? theme.colors.accent : theme.colors.textPrimary)
                .frame(width: 44, height: 44)
                .background {
                    // Pens show selection with a ring of their own; tools with a tinted tile.
                    if isSelected && !isPen {
                        RoundedRectangle(cornerRadius: theme.metrics.radiusSmall).fill(theme.colors.accentTint)
                    }
                }
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected && tool != .lasso ? "Opens its settings" : "")
    }
}

extension Pen.Ink {
    var symbol: String {
        switch self {
        case .fountainPen: "pencil.tip"
        case .pen: "pencil"
        case .pencil: "pencil.line"
        case .marker: "highlighter"
        case .monoline: "scribble"
        case .watercolor: "paintbrush"
        case .crayon: "paintbrush.pointed"
        case .reed: "signature"
        }
    }
}

/// A pen in the rail: a well of its colour with its ink's icon on it, ringed in the accent when in hand.
struct PenSwatch: View {
    let pen: Pen
    var isSelected = false
    var size = 30.0
    @Environment(\.theme) private var theme

    var body: some View {
        let ink = RGBA(hex: pen.color)
        Circle().fill(ink.color)
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: pen.ink.symbol)
                    .font(.system(size: size * 0.45, weight: .semibold))
                    // Dark icon on light inks, light icon on dark ones.
                    .foregroundStyle(ink.luminance > 0.4 ? RGBA(hex: 0x141414).color : RGBA(hex: 0xFFFFFF).color)
            }
            // An edge, so black ink still reads on a dark rail.
            .overlay(Circle().stroke(theme.colors.hairline, lineWidth: 1))
            .padding(3)
            .overlay {
                if isSelected { Circle().stroke(theme.colors.accent, lineWidth: 2) }
            }
    }
}

/// A pen's ink, size and colour, all from presets; duplicate or remove it.
private struct PenSettings: View {
    @Binding var penCase: PenCase
    let penID: UUID
    let dismiss: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        if let pen {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 14) {
                    inkMenu(pen)
                    sizes(pen)
                    colours(pen)
                }
                .padding(16)
                Rectangle().fill(theme.colors.hairline).frame(height: 1)
                actions
            }
            .frame(width: 320)
            .presentationBackground(theme.colors.elevated)
            .presentationCompactAdaptation(.popover)
        }
    }

    private var pen: Pen? { penCase.pens.first { $0.id == penID } }

    private func update(_ change: (inout Pen) -> Void) {
        guard var edited = pen else { return }
        change(&edited)
        penCase.update(edited)
    }

    /// The pen's ink is its title; tap it to change ink.
    private func inkMenu(_ pen: Pen) -> some View {
        Menu {
            Picker("Ink", selection: Binding(get: { pen.ink }, set: { ink in update { $0.change(ink: ink) } })) {
                ForEach(Pen.Ink.allCases, id: \.self) { Label($0.name, systemImage: $0.symbol).tag($0) }
            }
        } label: {
            HStack(spacing: 8) {
                Text(pen.ink.name).style(theme.typography.title).foregroundStyle(theme.colors.textPrimary)
                Image(systemName: "chevron.down").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.colors.textSecondary)
            }
            .contentShape(.rect)
        }
        .accessibilityLabel("Ink: \(pen.ink.name)")
    }

    private func sizes(_ pen: Pen) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            row("Size", value: String(format: "%.1f pt", pen.widthInPoints))
            HStack(spacing: 6) {
                ForEach(Array(Pen.Size.allCases.enumerated()), id: \.element) { index, size in
                    let isSelected = pen.size == size
                    Button {
                        update { $0.size = size }
                    } label: {
                        VStack(spacing: 6) {
                            let dot = 4 + Double(index) * 4
                            Circle().frame(width: dot, height: dot).frame(height: 14)
                            Text(size.name).style(theme.typography.caption)
                        }
                        .foregroundStyle(isSelected ? theme.colors.accent : theme.colors.textPrimary)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(
                            isSelected ? theme.colors.accentTint : theme.colors.canvas,
                            in: .rect(cornerRadius: theme.metrics.radiusSmall)
                        )
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(size.name)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private func colours(_ pen: Pen) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            row("Colour", value: pen.colorName)
            HStack(spacing: 0) {
                ForEach(Pen.Swatch.allCases, id: \.self) { swatch in
                    Button {
                        update { $0.color = swatch.hex }
                    } label: {
                        Circle().fill(RGBA(hex: swatch.hex).color)
                            .frame(width: 26, height: 26)
                            .overlay(Circle().stroke(theme.colors.hairline, lineWidth: 1))
                            .padding(3)
                            .overlay {
                                if pen.color == swatch.hex { Circle().stroke(theme.colors.accent, lineWidth: 2) }
                            }
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(swatch.name)
                    .accessibilityAddTraits(pen.color == swatch.hex ? .isSelected : [])
                }
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 0) {
            Button {
                if let copy = penCase.duplicate(penID) { penCase.select(.pen(copy.id)) }
                dismiss()
            } label: {
                Label("Duplicate", systemImage: "plus.square.on.square")
                    .foregroundStyle(theme.colors.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .contentShape(.rect)
            }
            .disabled(!penCase.canAddPen)
            Rectangle().fill(theme.colors.hairline).frame(width: 1, height: 22)
            Button(role: .destructive) {
                dismiss()
                penCase.remove(penID)
            } label: {
                Label("Remove", systemImage: "trash")
                    .foregroundStyle(theme.colors.danger)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .contentShape(.rect)
            }
            .disabled(!penCase.canRemovePen)
        }
        .font(theme.typography.body.font)
        .buttonStyle(SidebarButtonStyle())
    }

    private func row(_ title: String, value: String) -> some View {
        HStack {
            Text(title).style(theme.typography.caption).foregroundStyle(theme.colors.textSecondary)
            Spacer()
            Text(value).style(theme.typography.mono).foregroundStyle(theme.colors.textSecondary)
        }
    }
}

/// Whole-stroke or pixel erasing.
private struct EraserSettings: View {
    @Binding var eraser: PenCase.Eraser
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Eraser").style(theme.typography.title).foregroundStyle(theme.colors.textPrimary)
                .padding(16)
            option(.stroke, title: "Whole strokes", detail: "Removes every stroke it touches.")
            Rectangle().fill(theme.colors.hairline).frame(height: 1).padding(.leading, 16)
            option(.pixel, title: "Pixels", detail: "Rubs out only what it touches.")
        }
        .padding(.bottom, 6)
        .frame(width: 280)
        .presentationBackground(theme.colors.elevated)
        .presentationCompactAdaptation(.popover)
    }

    private func option(_ value: PenCase.Eraser, title: String, detail: String) -> some View {
        Button {
            eraser = value
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).style(theme.typography.body).foregroundStyle(theme.colors.textPrimary)
                    Text(detail).style(theme.typography.caption).foregroundStyle(theme.colors.textSecondary)
                }
                Spacer()
                Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.colors.accent)
                    .opacity(eraser == value ? 1 : 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(.rect)
        }
        .buttonStyle(SidebarButtonStyle())
        .accessibilityLabel(title)
        .accessibilityHint(detail)
        .accessibilityAddTraits(eraser == value ? .isSelected : [])
    }
}
