import Foundation
import InkCore

public struct PathPoint: Sendable, Equatable {
    public var x: Double
    public var y: Double
    /// Ink width across the direction of travel, in points.
    public var width: Double
    /// Scale of the stroke's `NibShape` here (the oval's long half-axis, in points).
    public var nibScale: Double

    public init(x: Double, y: Double, width: Double, nibScale: Double? = nil) {
        self.x = x
        self.y = y
        self.width = width
        self.nibScale = nibScale ?? width / 2
    }
}

/// Samples → smoothed, steadied, width-annotated path. Everything is causal: a point depends only on samples up to
/// it, so prediction only reshapes the steadied tail and pen-up never changes the stroke's shape.
public enum StrokePath {
    /// Direction and speed are measured over a chord at least this long, so jitter doesn't swing the nib.
    static let minimumChord = 1.5

    /// Pure function: same inputs → same output. `predicted` extends the path; with steadying on it may also
    /// reshape the last two knot spans, which are provisional anyway.
    public static func points(
        committed: [StrokeSample], predicted: [StrokeSample], tool: InkTool, parameters: InkParameters
    ) -> [PathPoint] {
        var smoother = StrokeSmoother(strength: parameters.smoothing)
        let smoothedCommitted = committed.map { smoother.add($0) }
        var predictionSmoother = smoother
        let samples = StrokeSteadier.points(
            smoothedCommitted + predicted.map { predictionSmoother.add($0) },
            spacing: parameters.steadiness, trail: parameters.trail)
        guard let rawLast = predicted.last ?? committed.last, let last = samples.last else { return [] }

        guard tool.kind == .fountainPen else {
            var path = samples.map { PathPoint(x: $0.x, y: $0.y, width: tool.width) }
            if rawLast.x != last.x || rawLast.y != last.y {
                path.append(PathPoint(x: rawLast.x, y: rawLast.y, width: tool.width))
            }
            return path
        }

        let motion = fountainMotion(samples, parameters: parameters)
        let widths = smoothedWidths(motion.map(\.width))
        let nib = NibModel.shape(for: tool, parameters: parameters)
        // Scale the oval so its swept width across this point's direction equals the modelled width.
        var path = samples.indices.map { index in
            PathPoint(
                x: samples[index].x, y: samples[index].y, width: widths[index],
                nibScale: widths[index] / nib.width(acrossDirection: motion[index].direction))
        }
        if rawLast.x != last.x || rawLast.y != last.y, var tail = path.last {
            tail.x = rawLast.x
            tail.y = rawLast.y
            path.append(tail)
        }
        return path
    }

    /// Per sample: direction of travel and the nib model's width for it.
    private static func fountainMotion(_ samples: [StrokeSample], parameters: InkParameters)
        -> [(direction: Double, width: Double)]
    {
        samples.indices.map { index in
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
            let width = NibModel.width(
                direction: direction, force: sample.force, speed: speed, azimuth: sample.azimuth,
                parameters: parameters)
            return (direction, width)
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
