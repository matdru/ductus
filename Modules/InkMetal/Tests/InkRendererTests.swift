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
        let path = StrokePath.points(committed: samples, predicted: [], tool: .fountainPen, parameters: .defaults)
        let image = try #require(CoverageImage([DrawStroke(path: path, color: .black)], in: page))
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
}
