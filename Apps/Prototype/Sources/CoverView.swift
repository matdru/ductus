import NotebookCore
import SwiftUI

/// A notebook seen from the front: material, spine, elastic band, title label, and the page block behind it.
struct CoverView: View {
    let notebook: Notebook
    /// Tilts the cover slightly in 3D, as if lying on a desk at an angle.
    var isTactile = true

    var body: some View {
        ZStack {
            if isTactile { pageBlock }
            cover
        }
        .aspectRatio(notebook.size.width / notebook.size.height, contentMode: .fit)
        .rotation3DEffect(.degrees(isTactile ? 6 : 0), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.15)
        .shadow(
            color: .black.opacity(isTactile ? 0.28 : 0.12), radius: isTactile ? 10 : 4, x: isTactile ? 6 : 0,
            y: isTactile ? 8 : 2)
    }

    private var base: Color { CoverPalette.color(notebook.cover.colorName) }
    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 3, bottomLeadingRadius: 3, bottomTrailingRadius: 10,
            topTrailingRadius: 10)
    }

    private var pageBlock: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                shape.fill(Color(hex: 0xF7F3EA))
                    .overlay(shape.stroke(Color.black.opacity(0.08), lineWidth: 0.5))
                    .offset(x: Double(3 - index) * 1.6, y: Double(3 - index) * 1.2)
            }
        }
    }

    private var cover: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .leading) {
                shape.fill(base)
                MaterialTexture(material: notebook.cover.material).clipShape(shape)
                spine(width: width)
                if notebook.cover.material == .leather || notebook.cover.material == .cloth {
                    Rectangle().fill(.black.opacity(0.55))
                        .frame(width: width * 0.05)
                        .offset(x: width * 0.84)
                        .shadow(color: .black.opacity(0.3), radius: 1, x: 1)
                }
                label(width: width)
                    .frame(width: width, height: proxy.size.height, alignment: .top)
                    .padding(.top, proxy.size.height * 0.16)
            }
        }
    }

    private func spine(width: Double) -> some View {
        HStack(spacing: 0) {
            LinearGradient(
                colors: [.black.opacity(0.35), .black.opacity(0.1)], startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width * 0.07)
            Rectangle().fill(.white.opacity(0.18)).frame(width: 1)
        }
    }

    private func label(width: Double) -> some View {
        Text(notebook.title)
            .font(.system(size: max(9, width * 0.075), weight: .medium, design: .serif))
            .foregroundStyle(Color(hex: 0x2B2A27))
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, width * 0.05)
            .padding(.vertical, width * 0.035)
            .frame(width: width * 0.56)
            .background(Color(hex: 0xF4EEDF), in: .rect(cornerRadius: 3))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(.black.opacity(0.15), lineWidth: 0.5))
            .offset(x: width * 0.03)
    }
}

/// Surface texture for each cover material.
private struct MaterialTexture: View {
    let material: CoverMaterial

    var body: some View {
        switch material {
        case .cloth:
            Image(uiImage: PaperGrain.tile).resizable(resizingMode: .tile).blendMode(.multiply).opacity(0.9)
        case .leather:
            ZStack {
                Image(uiImage: PaperGrain.tile).resizable(resizingMode: .tile).blendMode(.multiply)
                LinearGradient(
                    colors: [.white.opacity(0.18), .clear, .black.opacity(0.25)], startPoint: .topLeading,
                    endPoint: .bottomTrailing)
            }
        case .kraft:
            Image(uiImage: PaperGrain.tile).resizable(resizingMode: .tile).blendMode(.multiply).opacity(1)
                .overlay(Color.white.opacity(0.06))
        case .linen:
            Canvas { context, size in
                var path = Path()
                for x in stride(from: 0.0, through: size.width, by: 2.2) {
                    path.addLines([CGPoint(x: x, y: 0), CGPoint(x: x, y: size.height)])
                }
                for y in stride(from: 0.0, through: size.height, by: 2.2) {
                    path.addLines([CGPoint(x: 0, y: y), CGPoint(x: size.width, y: y)])
                }
                context.stroke(path, with: .color(.black.opacity(0.07)), lineWidth: 0.6)
            }
        case .plain:
            LinearGradient(colors: [.white.opacity(0.06), .black.opacity(0.06)], startPoint: .top, endPoint: .bottom)
        }
    }
}
