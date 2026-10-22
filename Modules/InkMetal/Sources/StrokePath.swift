import Foundation
import InkCore

public struct PathPoint: Sendable, Equatable {
    public var x: Double
    public var y: Double
    public var width: Double
}

/// Samples → smoothed, width-annotated path. Everything is causal: a point depends only on samples up to
/// it, so prediction never changes the committed prefix and pen-up never changes the stroke's shape.
public enum StrokePath {
    /// Direction and speed are measured over a chord at least this long, so jitter doesn't swing the nib.
    static let minimumChord = 1.5

    /// Pure function: same inputs → same output. `predicted` extends the path without changing the committed prefix.
    public static func points(
        committed: [StrokeSample], predicted: [StrokeSample], tool: InkTool, parameters: InkParameters
    ) -> [PathPoint] {
        var smoother = StrokeSmoother(strength: parameters.smoothing)
        let smoothedCommitted = committed.map { smoother.add($0) }
        var predictionSmoother = smoother
        let samples = smoothedCommitted + predicted.map { predictionSmoother.add($0) }
        guard let rawLast = predicted.last ?? committed.last, let last = samples.last else { return [] }

        let widths = smoothedWidths(rawWidths(samples, tool: tool, parameters: parameters))
        var path = zip(samples, widths).map { PathPoint(x: $0.x, y: $0.y, width: $1) }
        if rawLast.x != last.x || rawLast.y != last.y {
            path.append(PathPoint(x: rawLast.x, y: rawLast.y, width: widths[widths.count - 1]))
        }
        return path
    }

    private static func rawWidths(_ samples: [StrokeSample], tool: InkTool, parameters: InkParameters) -> [Double] {
        guard tool.kind == .fountainPen else { return Array(repeating: tool.width, count: samples.count) }
        return samples.indices.map { index in
            let sample = samples[index]
            var direction = 0.0
            var speed = 0.0
            if let earlier = samples[..<index].last(where: {
                hypot(sample.x - $0.x, sample.y - $0.y) >= minimumChord
            }) {
                direction = atan2(sample.y - earlier.y, sample.x - earlier.x)
                let elapsed = sample.timestamp - earlier.timestamp
                speed = elapsed > 0 ? hypot(sample.x - earlier.x, sample.y - earlier.y) / elapsed : 0
            }
            return NibModel.width(
                direction: direction, force: sample.force, speed: speed, azimuth: sample.azimuth,
                parameters: parameters)
        }
    }

    /// Causal 3-point average: current and up to two previous widths.
    private static func smoothedWidths(_ widths: [Double]) -> [Double] {
        widths.indices.map { index in
            let window = widths[max(0, index - 2)...index]
            return window.reduce(0, +) / Double(window.count)
        }
    }
}
