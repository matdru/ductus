import DesignSystem
import SwiftUI

/// The ink toolbar in the editor's top bar (DRU-36): four inks, the eraser and the lasso, then the size and colour
/// every ink uses. Tap the eraser in hand to switch between erasing whole strokes and pixels.
struct EditorToolbar: View {
    @Binding var toolbox: Toolbox
    @State private var choosingColour = false
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Toolbox.Ink.allCases, id: \.self) { ink in
                tool(.ink(ink), symbol: ink.symbol, label: ink.name)
            }
            tool(.eraser, symbol: "eraser", label: "Eraser")
                // Pixel mode wears a dashed badge: it rubs out part of a stroke, not the whole of it.
                .overlay(alignment: .bottomTrailing) {
                    if toolbox.eraser == .pixel {
                        Image(systemName: "square.dashed")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(
                                toolbox.selection == .eraser ? theme.colors.accent : theme.colors.textSecondary
                            )
                            .padding(4)
                            .allowsHitTesting(false)
                    }
                }
                .accessibilityValue(toolbox.eraser.name)
                .accessibilityHint(toolbox.selection == .eraser ? "Switches between whole strokes and pixels" : "")
            tool(.lasso, symbol: "lasso", label: "Lasso")
            divider
            ForEach(Array(Toolbox.Size.allCases.enumerated()), id: \.element) { index, size in
                sizeButton(size, dot: 4 + Double(index) * 3.5)
            }
            divider
            colourButton
        }
    }

    private var divider: some View {
        Rectangle().fill(theme.colors.hairline).frame(width: 1, height: 22).padding(.horizontal, 6)
    }

    private func tool(_ tool: Toolbox.Tool, symbol: String, label: String) -> some View {
        let isSelected = toolbox.selection == tool
        return Button {
            toolbox.tap(tool)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 17))
                .foregroundStyle(isSelected ? theme.colors.accent : theme.colors.textPrimary)
                .frame(width: 40, height: 36)
                .background(
                    isSelected ? theme.colors.accentTint : theme.colors.sidebar,
                    in: .rect(cornerRadius: theme.metrics.radiusSmall)
                )
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func sizeButton(_ size: Toolbox.Size, dot: Double) -> some View {
        let isSelected = toolbox.size == size
        return Button {
            toolbox.size = size
        } label: {
            Circle()
                .fill(isSelected ? theme.colors.accent : theme.colors.textSecondary)
                .frame(width: dot, height: dot)
                .frame(width: 30, height: 36)
                .background(
                    isSelected ? theme.colors.accentTint : theme.colors.sidebar,
                    in: .rect(cornerRadius: theme.metrics.radiusSmall)
                )
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(size.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// The colour in use; tap for the palette.
    private var colourButton: some View {
        Button {
            choosingColour = true
        } label: {
            Circle().fill(RGBA(hex: toolbox.color).color)
                .frame(width: 22, height: 22)
                .overlay(Circle().stroke(theme.colors.hairline, lineWidth: 1))
                .frame(width: 40, height: 36)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Colour")
        .accessibilityValue(toolbox.colorName)
        .popover(isPresented: $choosingColour, arrowEdge: .top) {
            HStack(spacing: 4) {
                ForEach(Toolbox.Swatch.allCases, id: \.self) { swatch in
                    let isSelected = toolbox.color == swatch.hex
                    Button {
                        toolbox.color = swatch.hex
                        choosingColour = false
                    } label: {
                        Circle().fill(RGBA(hex: swatch.hex).color)
                            .frame(width: 28, height: 28)
                            .overlay(Circle().stroke(theme.colors.hairline, lineWidth: 1))
                            .padding(3)
                            .overlay { if isSelected { Circle().stroke(theme.colors.accent, lineWidth: 2) } }
                            .frame(width: 44, height: 44)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(swatch.name)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(10)
            .presentationBackground(theme.colors.elevated)
            .presentationCompactAdaptation(.popover)
        }
    }
}
