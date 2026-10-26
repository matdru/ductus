import Foundation
import InkCore
import Testing

@testable import InkMetal

struct StrokeSteadierTests {
    func sample(_ x: Double, _ y: Double, _ i: Int) -> StrokeSample {
        StrokeSample(x: x, y: y, force: 1, altitude: 1, azimuth: .pi, timestamp: Double(i) / 240)
    }

    /// Slow horizontal line along y = 50 with a 10 Hz, ±1 pt hand tremor.
    func shakyLine(count: Int = 480) -> [StrokeSample] {
        (0..<count).map { i in
            let t = Double(i) / 240
            return sample(20 + 80 * t, 50 + sin(2 * .pi * 10 * t), i)
        }
    }

    /// Small "o": a circle of radius 8 around (100, 100), one sample per 2°.
    func smallO() -> [StrokeSample] {
        (0..<180).map { i in
            let angle = Double(i) * 2 * .pi / 180
            return sample(100 + 8 * cos(angle), 100 + 8 * sin(angle), i)
        }
    }

    func steady(_ samples: [StrokeSample], spacing: Double = 6, trail: Double = 2.5) -> [StrokeSample] {
        StrokeSteadier.points(samples, spacing: spacing, trail: trail)
    }

    @Test func offIsIdentity() {
        let samples = shakyLine(count: 60)
        #expect(steady(samples, spacing: 0, trail: 0) == samples)
    }

    @Test func emptyAndSingleSamplePassThrough() {
        #expect(steady([]).isEmpty)
        #expect(steady([sample(5, 5, 0)]) == [sample(5, 5, 0)])
    }

    @Test func startsAtFirstSample() throws {
        let first = try #require(steady(shakyLine()).first)
        #expect(abs(first.x - 20) < 1e-9 && abs(first.y - 50) < 1e-9)
    }

    @Test func tremorIsSmoothedAway() {
        let out = steady(shakyLine()).filter { $0.x > 40 && $0.x < 90 }
        #expect(!out.isEmpty)
        let worst = out.map { abs($0.y - 50) }.max() ?? .infinity
        #expect(worst < 0.35)
    }

    @Test func endsATrailBehindThePen() throws {
        let samples = shakyLine()
        let last = try #require(steady(samples).last)
        let pen = try #require(samples.last)
        let gap = hypot(pen.x - last.x, pen.y - last.y)
        #expect(gap <= 2.5 + 1e-9)
        #expect(gap > 1.5)
    }

    @Test func smallLettersKeepTheirShape() {
        let out = steady(smallO()).dropFirst(10).dropLast(10)
        for point in out {
            #expect(abs(hypot(point.x - 100, point.y - 100) - 8) < 1.5)
        }
    }

    @Test func curveHasNoGaps() {
        let out = steady(shakyLine())
        for (a, b) in zip(out, out.dropFirst()) {
            #expect(hypot(b.x - a.x, b.y - a.y) <= 2)
        }
    }

    @Test func extraSamplesOnlyChangeTheTail() {
        let samples = shakyLine()
        let shorter = steady(Array(samples.prefix(400)))
        let longer = steady(samples)
        let end = shorter.last ?? samples[0]
        // Two knot spacings plus the trail, with margin.
        let settled = shorter.prefix { hypot($0.x - end.x, $0.y - end.y) > 20 }
        #expect(settled.count > 50)
        #expect(Array(longer.prefix(settled.count)) == Array(settled))
    }
}
