import Foundation
import InkCore

/// Hand-steadying, after PencilKit: the ink follows the pen on a short leash (`trail`), keeps a point only every
/// `spacing` points along the way, and draws a uniform cubic B-spline through the kept points. Tremor smaller than
/// the spacing mostly disappears. Causal: new samples reshape only the last two knot spans and the leash.
enum StrokeSteadier {
    /// Curve samples per point of chord, so the drawn polyline stays smooth.
    static let samplesPerPoint = 1.0 / 1.5

    static func points(_ samples: [StrokeSample], spacing: Double, trail: Double) -> [StrokeSample] {
        guard samples.count > 1, spacing > 0 || trail > 0 else { return samples }
        let leashed = leash(samples, trail: max(trail, 0))
        guard spacing > 0 else { return leashed }
        var knots = decimate(leashed, spacing: spacing)
        if let lazy = leashed.last, knots.last != lazy { knots.append(lazy) }
        return curve(through: knots)
    }

    /// The lazy point stays put until the pen is `trail` away, then is dragged along behind it.
    static func leash(_ samples: [StrokeSample], trail: Double) -> [StrokeSample] {
        guard trail > 0, var lazy = samples.first else { return samples }
        var out = [lazy]
        for sample in samples.dropFirst() {
            let distance = hypot(sample.x - lazy.x, sample.y - lazy.y)
            guard distance > trail else { continue }
            let pull = (distance - trail) / distance
            var moved = sample
            moved.x = lazy.x + (sample.x - lazy.x) * pull
            moved.y = lazy.y + (sample.y - lazy.y) * pull
            lazy = moved
            out.append(lazy)
        }
        return out
    }

    /// Keeps the first sample and then each sample at least `spacing` from the last kept one.
    static func decimate(_ samples: [StrokeSample], spacing: Double) -> [StrokeSample] {
        guard var kept = samples.first else { return [] }
        var out = [kept]
        for sample in samples.dropFirst() where hypot(sample.x - kept.x, sample.y - kept.y) >= spacing {
            kept = sample
            out.append(kept)
        }
        return out
    }

    /// Uniform cubic B-spline with tripled end knots, so the curve starts and ends exactly on them.
    static func curve(through knots: [StrokeSample]) -> [StrokeSample] {
        guard let first = knots.first, let last = knots.last, knots.count > 1 else { return knots }
        let control = [first, first] + knots + [last, last]
        var out = [first]
        for index in 0..<(control.count - 3) {
            let p0 = control[index]
            let p1 = control[index + 1]
            let p2 = control[index + 2]
            let p3 = control[index + 3]
            // Span length from its true ends: with repeated end knots, p1 and p2 can coincide.
            let start = point(p0, p1, p2, p3, t: 0)
            let end = point(p0, p1, p2, p3, t: 1)
            let chord = hypot(end.x - start.x, end.y - start.y)
            guard chord > 0 else { continue }
            let steps = max(1, Int((chord * samplesPerPoint).rounded(.up)))
            for step in 1...steps {
                out.append(point(p0, p1, p2, p3, t: Double(step) / Double(steps)))
            }
        }
        return out
    }

    /// Position from the B-spline basis; the other fields interpolate between the span's two inner knots.
    private static func point(
        _ p0: StrokeSample, _ p1: StrokeSample, _ p2: StrokeSample, _ p3: StrokeSample, t: Double
    ) -> StrokeSample {
        let u = 1 - t
        let b0 = u * u * u / 6
        let b1 = (3 * t * t * t - 6 * t * t + 4) / 6
        let b2 = (-3 * t * t * t + 3 * t * t + 3 * t + 1) / 6
        let b3 = t * t * t / 6
        func lerp(_ a: Double, _ b: Double) -> Double { a + (b - a) * t }
        return StrokeSample(
            x: b0 * p0.x + b1 * p1.x + b2 * p2.x + b3 * p3.x,
            y: b0 * p0.y + b1 * p1.y + b2 * p2.y + b3 * p3.y,
            force: lerp(p1.force, p2.force), altitude: lerp(p1.altitude, p2.altitude),
            azimuth: lerp(p1.azimuth, p2.azimuth), timestamp: lerp(p1.timestamp, p2.timestamp))
    }
}
