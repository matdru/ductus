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
        VStack(spacing: 2) {
            ForEach(penCase.pens) { pen in
                toolButton(.pen(pen.id), label: pen.ink.name + ", " + pen.colorName) {
                    PenNib(pen: pen)
                }
                .popover(isPresented: isEditing(.pen(pen.id)), arrowEdge: .leading) {
                    PenSettings(penCase: $penCase, penID: pen.id) { editing = nil }
                }
            }
            separator
            toolButton(.eraser, label: "Eraser") { symbol("eraser") }
                .popover(isPresented: isEditing(.eraser), arrowEdge: .leading) {
                    EraserSettings(eraser: $penCase.eraser)
                }
            toolButton(.lasso, label: "Lasso") { symbol("lasso") }
            if penCase.canAddPen {
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
        .padding(5)
        .background(theme.colors.surface, in: .rect(cornerRadius: theme.metrics.radiusMedium))
        .overlay(RoundedRectangle(cornerRadius: theme.metrics.radiusMedium).stroke(theme.colors.hairline))
    }

    private var separator: some View {
        Rectangle().fill(theme.colors.hairline).frame(width: 28, height: 1).padding(.vertical, 4)
    }

    private func symbol(_ name: String) -> some View {
        Image(systemName: name).font(.system(size: 18))
    }

    private func isEditing(_ tool: PenCase.Tool) -> Binding<Bool> {
        Binding(get: { editing == tool }, set: { if !$0 { editing = nil } })
    }

    /// Picks the tool up, or opens its settings if it's already in hand. The lasso has none.
    private func toolButton<Label: View>(
        _ tool: PenCase.Tool, label: String, @ViewBuilder content: () -> Label
    ) -> some View {
        let isSelected = penCase.selection == tool
        return Button {
            if isSelected {
                if tool != .lasso { editing = tool }
            } else {
                penCase.select(tool)
            }
        } label: {
            content()
                .foregroundStyle(isSelected ? theme.colors.accent : theme.colors.textPrimary)
                .frame(width: 44, height: 46)
                .background(
                    isSelected ? theme.colors.accentTint : theme.colors.surface,
                    in: .rect(cornerRadius: theme.metrics.radiusSmall)
                )
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected && tool != .lasso ? "Opens its settings" : "")
    }
}

/// A pen's tip in its colour, shaped by its ink and as thick as its width.
struct PenNib: View {
    let pen: Pen

    var body: some View {
        let color = RGBA(hex: pen.color).color
        let range = pen.ink.widthRange
        let fraction = (pen.clampedWidth - range.lowerBound) / (range.upperBound - range.lowerBound)
        let width = 3 + fraction * 7
        Group {
            switch pen.ink {
            case .fountainPen:
                NibShape().fill(color).frame(width: width + 4, height: 24)
            case .marker, .watercolor, .crayon:
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: width + 4, height: 24)
            default:
                Capsule().fill(color).frame(width: width, height: 24)
            }
        }
        // On a scrap of paper, so black ink shows on a dark rail and yellow ink on a light one.
        .frame(width: 26, height: 32)
        .background(PaperColor.ivory.swatch, in: .rect(cornerRadius: 5))
    }
}

/// A fountain pen nib: a point, shoulders, and a straight base.
private struct NibShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.3))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.7, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.3, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.3))
            path.closeSubpath()
        }
    }
}

/// A pen's ink, width and colour, with a sample stroke; duplicate or remove it.
private struct PenSettings: View {
    @Binding var penCase: PenCase
    let penID: UUID
    let dismiss: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        if let pen {
            VStack(alignment: .leading, spacing: 16) {
                header(pen)
                StrokePreview(pen: pen)
                    .frame(height: 64)
                    .clipShape(.rect(cornerRadius: theme.metrics.radiusSmall))
                width(pen)
                colours(pen)
                actions
            }
            .padding(16)
            .frame(width: 300)
            .background(theme.colors.elevated)
            .presentationCompactAdaptation(.popover)
        }
    }

    private var pen: Pen? { penCase.pens.first { $0.id == penID } }

    private func update(_ change: (inout Pen) -> Void) {
        guard var edited = pen else { return }
        change(&edited)
        penCase.update(edited)
    }

    private func header(_ pen: Pen) -> some View {
        HStack {
            Text(pen.ink.name).style(theme.typography.headline).foregroundStyle(theme.colors.textPrimary)
            Spacer()
            Menu {
                Picker("Ink", selection: Binding(get: { pen.ink }, set: { ink in update { $0.change(ink: ink) } })) {
                    ForEach(Pen.Ink.allCases, id: \.self) { Text($0.name).tag($0) }
                }
            } label: {
                Text("Change ink").style(theme.typography.body).foregroundStyle(theme.colors.accent)
            }
        }
    }

    private func width(_ pen: Pen) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                label("Width")
                Spacer()
                Text(String(format: "%.1f pt", pen.widthInPoints)).style(theme.typography.mono)
                    .foregroundStyle(theme.colors.textSecondary)
            }
            HStack(spacing: 10) {
                Circle().fill(RGBA(hex: pen.color).color).frame(width: 5, height: 5)
                Slider(
                    value: Binding(get: { pen.clampedWidth }, set: { width in update { $0.width = width } }),
                    in: pen.ink.widthRange
                )
                .accessibilityLabel("Width")
                Circle().fill(RGBA(hex: pen.color).color).frame(width: 16, height: 16)
            }
        }
    }

    private func colours(_ pen: Pen) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            label("Colour")
            HStack(spacing: 10) {
                ForEach(Pen.Swatch.allCases, id: \.self) { swatch in
                    Button {
                        update { $0.color = swatch.hex }
                    } label: {
                        Circle().fill(RGBA(hex: swatch.hex).color).frame(width: 28, height: 28)
                            .overlay(Circle().stroke(theme.colors.hairline))
                            .overlay(
                                Circle().stroke(theme.colors.accent, lineWidth: pen.color == swatch.hex ? 2 : 0)
                                    .padding(-4)
                            )
                            .frame(width: 34, height: 34)
                            .contentShape(.circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(swatch.name)
                    .accessibilityAddTraits(pen.color == swatch.hex ? .isSelected : [])
                }
                ColorPicker(
                    "Custom colour",
                    selection: Binding(
                        get: { RGBA(hex: pen.color).color },
                        set: { color in update { $0.color = Pen.hex(of: UIColor(color)) } }),
                    supportsOpacity: false
                )
                .labelsHidden()
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button {
                if let copy = penCase.duplicate(penID) { penCase.select(.pen(copy.id)) }
                dismiss()
            } label: {
                Text("Duplicate pen").style(theme.typography.body).foregroundStyle(theme.colors.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background(theme.colors.canvas, in: .rect(cornerRadius: theme.metrics.radiusSmall))
            }
            .buttonStyle(.plain)
            .disabled(!penCase.canAddPen)
            .opacity(penCase.canAddPen ? 1 : 0.5)
            Button {
                dismiss()
                penCase.remove(penID)
            } label: {
                Text("Remove").style(theme.typography.body).foregroundStyle(theme.colors.danger)
                    .frame(maxWidth: .infinity, minHeight: 38)
            }
            .buttonStyle(.plain)
            .disabled(!penCase.canRemovePen)
            .opacity(penCase.canRemovePen ? 1 : 0.5)
        }
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased()).font(.system(size: 11.5, weight: .semibold)).tracking(0.6)
            .foregroundStyle(theme.colors.textSecondary)
    }
}

/// A sample stroke drawn by PencilKit itself, so it looks exactly like writing with the pen.
private struct StrokePreview: View {
    let pen: Pen

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                PaperColor.ivory.swatch
                Image(uiImage: Self.image(pen: pen, size: proxy.size))
            }
        }
    }

    static func image(pen: Pen, size: CGSize) -> UIImage {
        guard size.width > 20, size.height > 20 else { return UIImage() }
        let inset = 14.0
        let points = (0...40).map { i in
            let t = Double(i) / 40
            let x = inset + t * (size.width - 2 * inset)
            let y = size.height / 2 + sin(t * .pi * 3) * (size.height / 2 - inset)
            return PKStrokePoint(
                location: CGPoint(x: x, y: y), timeOffset: t,
                size: CGSize(width: pen.clampedWidth, height: pen.clampedWidth),
                opacity: 1, force: 1, azimuth: 0, altitude: .pi / 2)
        }
        let stroke = PKStroke(
            ink: PKInk(pen.ink.inkType, color: pen.uiColor),
            path: PKStrokePath(controlPoints: points, creationDate: Date()))
        var image = UIImage()
        // Ink is content: render it as on paper, never inverted for dark mode.
        UITraitCollection(userInterfaceStyle: .light).performAsCurrent {
            image = PKDrawing(strokes: [stroke]).image(from: CGRect(origin: .zero, size: size), scale: 2)
        }
        return image
    }
}

/// Stroke or pixel erasing.
private struct EraserSettings: View {
    @Binding var eraser: PenCase.Eraser
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Eraser").style(theme.typography.headline).foregroundStyle(theme.colors.textPrimary)
            Picker("Eraser", selection: $eraser) {
                Text("Whole strokes").tag(PenCase.Eraser.stroke)
                Text("Pixels").tag(PenCase.Eraser.pixel)
            }
            .pickerStyle(.segmented)
            Text(
                eraser == .stroke
                    ? "Removes every stroke it touches." : "Rubs out only the part of a stroke it touches."
            )
            .style(theme.typography.caption).foregroundStyle(theme.colors.textSecondary)
        }
        .padding(16)
        .frame(width: 280)
        .background(theme.colors.elevated)
        .presentationCompactAdaptation(.popover)
    }
}
