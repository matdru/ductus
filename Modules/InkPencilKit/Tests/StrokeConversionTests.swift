import InkCore
import PencilKit
import Testing

@testable import InkPencilKit

struct StrokeConversionTests {
    let tool = InkTool(kind: .pen, color: InkColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1), width: 5)

    func sample(_ x: Double, t: Double) -> StrokeSample {
        StrokeSample(x: x, y: x * 2, force: 1.2, altitude: 0.9, azimuth: 1.1, timestamp: t)
    }

    @Test func roundTripPreservesSamplesWithinTolerance() throws {
        let original = Stroke(tool: tool, samples: [sample(10, t: 50), sample(20, t: 50.01), sample(30, t: 50.02)])
        let pk = try #require(StrokeConversion.pkStroke(from: original))
        let back = StrokeConversion.stroke(from: pk, id: original.id)

        #expect(back.id == original.id)
        #expect(back.samples.count == 3)
        for (a, b) in zip(original.samples, back.samples) {
            #expect(abs(a.x - b.x) < 1e-3 && abs(a.y - b.y) < 1e-3)
            #expect(abs(a.force - b.force) < 1e-3)
            #expect(abs(a.altitude - b.altitude) < 1e-3)
            #expect(abs(a.azimuth - b.azimuth) < 1e-3)
        }
        // Timestamps come back as offsets from the first sample.
        #expect(abs(back.samples[0].timestamp) < 1e-6)
        #expect(abs(back.samples[2].timestamp - 0.02) < 1e-3)
        #expect(abs(back.tool.width - 5) < 1e-3)
        #expect(back.tool.kind == .pen)
        #expect(abs(back.tool.color.blue - 0.6) < 1e-2)
    }

    @Test func highlighterMapsToMarker() throws {
        var marker = tool
        marker.kind = .highlighter
        let pk = try #require(StrokeConversion.pkStroke(from: Stroke(tool: marker, samples: [sample(1, t: 0)])))
        #expect(pk.ink.inkType == .marker)
        #expect(StrokeConversion.stroke(from: pk).tool.kind == .highlighter)
    }

    @Test func emptyStrokeConvertsToNil() {
        #expect(StrokeConversion.pkStroke(from: Stroke(tool: tool, samples: [])) == nil)
    }

    @Test func singleSampleStrokeConverts() throws {
        let pk = try #require(StrokeConversion.pkStroke(from: Stroke(tool: tool, samples: [sample(5, t: 0)])))
        #expect(StrokeConversion.stroke(from: pk).samples.count == 1)
    }

    @Test func fountainPenMapsToPencilKitFountainPen() throws {
        let pk = try #require(
            StrokeConversion.pkStroke(from: Stroke(tool: .fountainPen, samples: [sample(1, t: 0), sample(2, t: 0.01)])))
        #expect(pk.ink.inkType == .fountainPen)
        #expect(StrokeConversion.stroke(from: pk).tool.kind == .fountainPen)
    }
}
