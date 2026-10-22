import Foundation
import InkCore

/// Causal one-euro filter on sample positions: strong at slow speeds where jitter shows, light when fast.
/// The output never strays more than `maxLag` from its raw sample, and strength 0 is the identity.
public struct StrokeSmoother: Sendable {
    static let maxLag = 0.5
    static let beta = 0.02
    static let derivativeCutoff = 1.0
    static let fallbackInterval = 1.0 / 240

    private struct State {
        var x: Double
        var y: Double
        var dx: Double
        var dy: Double
        var timestamp: Double
    }

    private let strength: Double
    private var previous: State?

    /// `strength` is 0...1: minimum cutoff falls from 30 Hz to 1 Hz.
    public init(strength: Double) {
        self.strength = min(max(strength, 0), 1)
    }

    public mutating func add(_ sample: StrokeSample) -> StrokeSample {
        guard strength > 0 else { return sample }
        guard let last = previous else {
            previous = State(x: sample.x, y: sample.y, dx: 0, dy: 0, timestamp: sample.timestamp)
            return sample
        }
        let elapsed = sample.timestamp - last.timestamp
        let dt = elapsed > 0 ? elapsed : Self.fallbackInterval
        let derivativeAlpha = Self.alpha(cutoff: Self.derivativeCutoff, dt: dt)
        let dx = last.dx + derivativeAlpha * ((sample.x - last.x) / dt - last.dx)
        let dy = last.dy + derivativeAlpha * ((sample.y - last.y) / dt - last.dy)
        let minCutoff = 30 - strength * 29
        let alpha = Self.alpha(cutoff: minCutoff + Self.beta * hypot(dx, dy), dt: dt)
        var x = last.x + alpha * (sample.x - last.x)
        var y = last.y + alpha * (sample.y - last.y)

        let lag = hypot(x - sample.x, y - sample.y)
        if lag > Self.maxLag {
            let keep = Self.maxLag / lag
            x = sample.x + (x - sample.x) * keep
            y = sample.y + (y - sample.y) * keep
        }
        previous = State(x: x, y: y, dx: dx, dy: dy, timestamp: sample.timestamp)

        var smoothed = sample
        smoothed.x = x
        smoothed.y = y
        return smoothed
    }

    private static func alpha(cutoff: Double, dt: Double) -> Double {
        let tau = 1 / (2 * Double.pi * cutoff)
        return 1 / (1 + tau / dt)
    }
}
