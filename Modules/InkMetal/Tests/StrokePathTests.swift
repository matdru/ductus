import Foundation
import InkCore
import Testing

@testable import InkMetal

struct StrokePathTests {
    func sample(_ x: Double, _ y: Double, _ i: Int) -> StrokeSample {
        StrokeSample(x: x, y: y, force: 1, altitude: 1, azimuth: .pi, timestamp: Double(i) / 240)
    }

    /// Quarter-turn arc of radius 60, one sample per degree.
    func arc(_ range: Range<Int>) -> [StrokeSample] {
        range.map { i in
            let angle = Double(i) * .pi / 180
            return sample(100 + 60 * cos(angle), 100 + 60 * sin(angle), i)
        }
    }

    func line(from start: (Double, Double), to end: (Double, Double), count: Int) -> [StrokeSample] {
        (0..<count).map { i in
            let t = Double(i) / Double(count - 1)
            return sample(start.0 + (end.0 - start.0) * t, start.1 + (end.1 - start.1) * t, i)
        }
    }

    func points(_ committed: [StrokeSample], _ predicted: [StrokeSample] = [], tool: InkTool = .fountainPen)
        -> [PathPoint]
    {
        StrokePath.points(committed: committed, predicted: predicted, tool: tool, parameters: .defaults)
    }

    @Test func predictionNeverChangesCommittedPrefix() {
        let committed = arc(0..<60)
        let predicted = arc(60..<70)
        let live = points(committed, predicted)
        let final = points(committed)
        #expect(Array(live.prefix(committed.count)) == Array(final.prefix(committed.count)))
    }

    @Test func endsAtLatestRawSample() throws {
        let committed = arc(0..<60)
        let predicted = arc(60..<70)
        let withPrediction = try #require(points(committed, predicted).last)
        #expect(withPrediction.x == predicted.last?.x && withPrediction.y == predicted.last?.y)
        let committedOnly = try #require(points(committed).last)
        #expect(committedOnly.x == committed.last?.x && committedOnly.y == committed.last?.y)
    }

    @Test func penHasConstantToolWidth() {
        #expect(points(arc(0..<60), tool: .defaultPen).allSatisfy { $0.width == 3 })
    }

    @Test func fountainWidthFollowsDirection() {
        let vertical = points(line(from: (50, 0), to: (50, 200), count: 100))
        let horizontal = points(line(from: (0, 50), to: (200, 50), count: 100))
        for point in vertical[20..<80] { #expect(abs(point.width - 7.8) <= 0.75) }
        for point in horizontal[20..<80] { #expect(abs(point.width - 1.3) <= 0.75) }
    }

    @Test func stationaryPenHoldsWidth() {
        let moving = line(from: (50, 0), to: (50, 20), count: 21)
        let held = (21..<51).map { sample(50, 20, $0) }
        let path = points(moving + held)
        let before = path[20].width
        for point in path[21..<(moving.count + held.count)] { #expect(abs(point.width - before) < 1e-9) }
    }

    @Test func singleSampleGivesOnePoint() {
        #expect(points([sample(5, 5, 0)]).count == 1)
    }

    @Test func emptyGivesEmpty() {
        #expect(points([]).isEmpty)
    }
}
