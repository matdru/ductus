import Foundation
import InkCore
import Testing

@testable import InkMetal

struct StrokeSmootherTests {
    func line(count: Int, speed: Double, noise: Double = 0) -> [StrokeSample] {
        (0..<count).map { i in
            let t = Double(i) / 240
            return StrokeSample(
                x: speed * t, y: i.isMultiple(of: 2) ? noise : -noise, force: 1 + Double(i) / 100,
                altitude: 0.9, azimuth: 0.4, timestamp: 10 + t)
        }
    }

    func smooth(_ samples: [StrokeSample], strength: Double) -> [StrokeSample] {
        var smoother = StrokeSmoother(strength: strength)
        return samples.map { smoother.add($0) }
    }

    @Test func zeroStrengthIsIdentity() {
        let samples = line(count: 50, speed: 300, noise: 0.4)
        #expect(smooth(samples, strength: 0) == samples)
    }

    @Test func lagNeverExceedsHalfAPoint() {
        let samples = line(count: 120, speed: 1000)
        for (raw, out) in zip(samples, smooth(samples, strength: 1)) {
            #expect(hypot(out.x - raw.x, out.y - raw.y) <= 0.5 + 1e-9)
        }
    }

    @Test func reducesSlowJitter() {
        let samples = line(count: 120, speed: 20, noise: 0.4)
        func variance(_ values: [Double]) -> Double {
            let mean = values.reduce(0, +) / Double(values.count)
            return values.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(values.count)
        }
        let out = smooth(samples, strength: 1).dropFirst(10).map(\.y)
        let raw = samples.dropFirst(10).map(\.y)
        #expect(variance(Array(out)) < 0.5 * variance(Array(raw)))
    }

    @Test func passesThroughNonPositionFields() {
        let samples = line(count: 20, speed: 300, noise: 0.2)
        for (raw, out) in zip(samples, smooth(samples, strength: 0.7)) {
            #expect(out.force == raw.force && out.altitude == raw.altitude)
            #expect(out.azimuth == raw.azimuth && out.timestamp == raw.timestamp)
        }
    }

    @Test func isDeterministic() {
        let samples = line(count: 60, speed: 400, noise: 0.3)
        #expect(smooth(samples, strength: 0.6) == smooth(samples, strength: 0.6))
    }
}
