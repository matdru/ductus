import InkCore
import Testing

@testable import InkMetal

struct StrokeBuilderTests {
    func sample(_ x: Double) -> StrokeSample {
        StrokeSample(x: x, y: 0, force: 1, altitude: 1, azimuth: 0, timestamp: x)
    }

    @Test func committedSamplesAccumulate() {
        var builder = StrokeBuilder(tool: .defaultPen)
        builder.append(committed: [sample(1), sample(2)], predicted: [])
        builder.append(committed: [sample(3)], predicted: [])
        #expect(builder.committed.map(\.x) == [1, 2, 3])
    }

    @Test func predictedSamplesAreReplacedNotAccumulated() {
        var builder = StrokeBuilder(tool: .defaultPen)
        builder.append(committed: [sample(1)], predicted: [sample(2), sample(3)])
        builder.append(committed: [sample(2)], predicted: [sample(4)])
        #expect(builder.predicted.map(\.x) == [4])
        #expect(builder.displaySamples.map(\.x) == [1, 2, 4])
    }

    @Test func finishExcludesPredictedSamples() throws {
        var builder = StrokeBuilder(tool: .defaultPen)
        builder.append(committed: [sample(1), sample(2)], predicted: [sample(9)])
        let stroke = try #require(builder.finish())
        #expect(stroke.samples.map(\.x) == [1, 2])
        #expect(stroke.id == builder.id)
        #expect(stroke.tool == .defaultPen)
    }

    @Test func finishWithNoSamplesReturnsNil() {
        #expect(StrokeBuilder(tool: .defaultPen).finish() == nil)
    }

    @Test func singleTapProducesOneSampleStroke() throws {
        var builder = StrokeBuilder(tool: .defaultPen)
        builder.append(committed: [sample(5)], predicted: [])
        #expect(try #require(builder.finish()).samples.count == 1)
    }
}
