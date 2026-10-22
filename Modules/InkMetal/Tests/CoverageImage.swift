import CoreGraphics
import InkCore

@testable import InkMetal

/// Test helper: renders strokes offscreen and reads ink coverage (1 − luminance on the white page).
@MainActor
struct CoverageImage {
    let rect: CGRect
    let scale: Double
    let width: Int
    let height: Int
    private let pixels: [UInt8]

    init?(_ strokes: [DrawStroke], in rect: CGRect, scale: Double = 4) {
        guard let renderer = InkRenderer(), let image = renderer.image(of: strokes, in: rect, scale: scale) else {
            return nil
        }
        width = image.width
        height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        guard
            let context = CGContext(
                data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        pixels = data
        self.rect = rect
        self.scale = scale
    }

    /// Coverage at a point in canvas points (nearest pixel); 0 outside the image.
    func coverage(atX x: Double, y: Double) -> Double {
        let px = Int(((x - rect.minX) * scale).rounded(.down))
        let py = Int(((y - rect.minY) * scale).rounded(.down))
        guard px >= 0, py >= 0, px < width, py < height else { return 0 }
        let index = (py * width + px) * 4
        let luminance = (Double(pixels[index]) + Double(pixels[index + 1]) + Double(pixels[index + 2])) / (3 * 255)
        return 1 - luminance
    }

    /// Pixel coverages down the column through canvas x.
    func column(atX x: Double) -> [Double] {
        (0..<height).map { coverage(atX: x, y: rect.minY + (Double($0) + 0.5) / scale) }
    }

    /// Ink width in points across the line through (x, y) with unit normal (nx, ny).
    func width(atX x: Double, y: Double, normalX nx: Double, normalY ny: Double, reach: Double = 15) -> Double {
        let step = 0.05
        return stride(from: -reach, through: reach, by: step).reduce(0) {
            $0 + coverage(atX: x + nx * $1, y: y + ny * $1) * step
        }
    }
}

extension PathPoint {
    init(_ x: Double, _ y: Double, _ width: Double) { self.init(x: x, y: y, width: width) }
}
