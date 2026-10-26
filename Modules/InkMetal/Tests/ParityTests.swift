import CoreGraphics
import Foundation
import InkCore
import Testing

@testable import InkMetal

/// Mirror of InkPencilKit's `StrokeDump` (engine modules can't depend on each other).
private struct ReferencePoint: Decodable {
    var x: Double
    var y: Double
    var timeOffset: Double
    var force: Double
    var azimuth: Double
    var altitude: Double

    var sample: StrokeSample {
        StrokeSample(x: x, y: y, force: force, altitude: altitude, azimuth: azimuth, timestamp: timeOffset)
    }
}

private struct ReferenceStroke: Decodable { var points: [ReferencePoint] }
private struct ReferenceDump: Decodable { var strokes: [ReferenceStroke] }

/// Renders the author's PencilKit fountain-pen strokes through the custom engine and compares rendered
/// widths with PencilKit's measured ones (docs/superpowers/specs/2026-10-22-fountain-pen-design.md).
@MainActor
struct ParityTests {
    static let referenceURL = URL(filePath: #filePath)
        .deletingLastPathComponent().appending(
            path: "../../../docs/phase-0-data/2026-10-22-pencilkit-fountain-pen.json"
        )
        .standardized

    /// Direction bins, in degrees (screen coordinates, y down).
    static func bin(forDegrees degrees: Double) -> String? {
        switch degrees {
        case 0..<20, 340..<360, 160..<200: "→"
        case 25..<65: "↘"
        case 70..<110: "↓"
        case 295..<335: "↗"
        default: nil
        }
    }

    /// Rendered width at each interior sample (more than 5 pt from either end), keyed by direction bin.
    static func measuredWidths(of samples: [StrokeSample]) throws -> [String: [Double]] {
        guard let first = samples.first, let last = samples.last, samples.count >= 3 else { return [:] }
        let stroke = DrawStroke(committed: samples, predicted: [], tool: .fountainPen, parameters: .defaults)
        let image = try #require(CoverageImage([stroke], in: stroke.bounds.insetBy(dx: -15, dy: -15)))
        var widths: [String: [Double]] = [:]
        for index in 1..<(samples.count - 1) {
            let point = samples[index]
            let dx = samples[index + 1].x - samples[index - 1].x
            let dy = samples[index + 1].y - samples[index - 1].y
            let length = hypot(dx, dy)
            let nearEnd = min(hypot(point.x - first.x, point.y - first.y), hypot(point.x - last.x, point.y - last.y))
            let degrees = (atan2(dy, dx) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
            guard nearEnd > 5, length > 1, let bin = bin(forDegrees: degrees) else { continue }
            widths[bin, default: []].append(
                image.width(atX: point.x, y: point.y, normalX: -dy / length, normalY: dx / length))
        }
        return widths
    }

    @Test func fountainDefaultsMatchPencilKitReference() throws {
        let dump = try JSONDecoder().decode(ReferenceDump.self, from: Data(contentsOf: Self.referenceURL))
        var bins: [String: [Double]] = [:]
        // Strokes 0–24 are the deliberate straight lines; the rest are flicks and signatures.
        for stroke in dump.strokes.prefix(25) {
            bins.merge(try Self.measuredWidths(of: stroke.points.map(\.sample))) { $0 + $1 }
        }
        for (bin, expected) in [("→", 1.3), ("↘", 5.2), ("↓", 7.8), ("↗", 2.2)] {
            let widths = try #require(bins[bin], "no samples for \(bin)")
            let mean = widths.reduce(0, +) / Double(widths.count)
            #expect(abs(mean - expected) <= 0.75, "\(bin): mean \(mean) over \(widths.count) points")
        }
    }
}
