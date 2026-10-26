import CoreGraphics
import InkCore
import Testing

@testable import InkMetal

@MainActor
struct InkRendererTests {
    let page = CGRect(x: 0, y: 0, width: 200, height: 100)

    func penStroke(_ path: [PathPoint], color: InkColor = .black) -> DrawStroke {
        DrawStroke(path: path, color: color)
    }

    @Test func horizontalPenStrokeIsThreePointsWide() throws {
        let image = try #require(
            CoverageImage([penStroke([PathPoint(20, 50.1, 3), PathPoint(180, 50.1, 3)])], in: page))
        let width = image.column(atX: 100).reduce(0, +) / image.scale
        #expect(abs(width - 3) <= 0.3)
    }

    @Test func edgesAreAntialiased() throws {
        let image = try #require(
            CoverageImage([penStroke([PathPoint(20, 50.1, 3), PathPoint(180, 50.1, 3)])], in: page))
        #expect(image.column(atX: 100).contains { $0 > 0.1 && $0 < 0.9 })
    }

    @Test func selfOverlapDoesNotDarken() throws {
        let translucent = InkColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        let crossing = [PathPoint(20, 10, 6), PathPoint(80, 70, 6), PathPoint(80, 10, 6), PathPoint(20, 70, 6)]
        let image = try #require(CoverageImage([penStroke(crossing, color: translucent)], in: page))
        let atCrossing = image.coverage(atX: 50, y: 40)
        let plain = image.coverage(atX: 80, y: 40)
        #expect(plain > 0.4)
        #expect(atCrossing <= plain + 0.02)
    }

    @Test func fastFlickWithThreeSamplesIsContinuous() throws {
        let samples = [(20.0, 50.0), (40.0, 53.0), (60.0, 50.0)].enumerated().map { i, p in
            StrokeSample(x: p.0, y: p.1, force: 0.5, altitude: 1, azimuth: .pi, timestamp: Double(i) / 240)
        }
        let stroke = DrawStroke(committed: samples, predicted: [], tool: .fountainPen, parameters: .defaults)
        let image = try #require(CoverageImage([stroke], in: page))
        for x in stride(from: 21.0, through: 59.0, by: 0.5) {
            #expect(image.column(atX: x).contains { $0 > 0.5 }, "gap at x = \(x)")
        }
    }

    @Test func roundCapsExtendPastEndpoints() throws {
        let image = try #require(
            CoverageImage([penStroke([PathPoint(20, 50.1, 3), PathPoint(180, 50.1, 3)])], in: page))
        #expect(image.coverage(atX: 181, y: 50.1) > 0.5)
        #expect(image.coverage(atX: 182, y: 50.1) < 0.1)
    }

    @Test func twoSampleTapRendersADot() throws {
        let tap = (0..<2).map {
            StrokeSample(x: 50, y: 50, force: 1, altitude: 1, azimuth: 0, timestamp: Double($0) / 240)
        }
        let path = StrokePath.points(committed: tap, predicted: [], tool: .defaultPen, parameters: .defaults)
        let image = try #require(CoverageImage([DrawStroke(path: path, color: .black)], in: page))
        #expect(image.coverage(atX: 50, y: 50) > 0.9)
    }

    /// Tight turnarounds (the bottom of a "u") must not leave a round blob: a nib is an oval, not a disc.
    @Test func fountainTurnaroundDoesNotBlob() throws {
        let down = stride(from: 20.0, through: 50, by: 1).map { $0 }
        let ys = down + down.reversed().dropFirst()
        let samples = ys.enumerated().map { i, y in
            StrokeSample(x: 50, y: y, force: 1, altitude: 1, azimuth: .pi, timestamp: Double(i) / 240)
        }
        let stroke = DrawStroke(committed: samples, predicted: [], tool: .fountainPen, parameters: .defaults)
        let image = try #require(CoverageImage([stroke], in: page))
        #expect(image.coverage(atX: 50, y: 40) > 0.9, "downstroke body is inked")
        #expect(image.coverage(atX: 50, y: 52.5) < 0.1, "ink spills 2.5 pt below the turn")
    }

    func stroke(at x: Double, color: InkColor = .black, nib: NibShape = .circle) -> DrawStroke {
        DrawStroke(path: [PathPoint(x, 50, 3), PathPoint(x + 10, 50, 3)], color: color, nib: nib)
    }

    /// Cache rebuilds (every tuning-slider tick) must not cost two full-screen passes per stroke.
    @Test func consecutiveOpaqueStrokesShareABatch() {
        let red = InkColor(red: 1, green: 0, blue: 0)
        let translucent = InkColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        let oval = NibShape(angle: 0, roundness: 0.25)
        let strokes = [
            stroke(at: 0), stroke(at: 20), stroke(at: 40),  // one batch
            stroke(at: 60, color: red),  // colour change
            stroke(at: 80, color: red, nib: oval),  // nib change
            stroke(at: 100, color: translucent), stroke(at: 120, color: translucent),  // never batched
        ]
        #expect(InkRenderer.batches(strokes).map(\.count) == [3, 1, 1, 1, 1])
    }

    @Test func batchedStrokesAllRender() throws {
        let image = try #require(CoverageImage([stroke(at: 20), stroke(at: 100), stroke(at: 160)], in: page))
        for x in [25.0, 105, 165] { #expect(image.coverage(atX: x, y: 50) > 0.9) }
    }
}
