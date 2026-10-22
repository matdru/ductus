import Foundation
import PencilKit
import Testing

@testable import InkPencilKit

struct StrokeDumpTests {
    @Test func dumpKeepsEveryControlPointWithItsSizeAndTransform() throws {
        let points = [
            PKStrokePoint(
                location: CGPoint(x: 1, y: 2), timeOffset: 0, size: CGSize(width: 3, height: 4), opacity: 1,
                force: 0.5, azimuth: 0.25, altitude: 1),
            PKStrokePoint(
                location: CGPoint(x: 5, y: 6), timeOffset: 0.01, size: CGSize(width: 7, height: 8), opacity: 0.9,
                force: 2, azimuth: 0.5, altitude: 0.75),
        ]
        var stroke = PKStroke(
            ink: PKInk(.fountainPen, color: .black), path: PKStrokePath(controlPoints: points, creationDate: Date()))
        stroke.transform = CGAffineTransform(translationX: 10, y: 0)

        let dump = StrokeDump(drawing: PKDrawing(strokes: [stroke]))

        let entry = try #require(dump.strokes.first)
        #expect(entry.ink == "fountainPen")
        #expect(entry.points.count == 2)
        let last = try #require(entry.points.last)
        #expect(abs(last.x - 15) < 1e-6)
        #expect(abs(last.width - 7) < 1e-6)
        #expect(abs(last.force - 2) < 1e-6)
        #expect(abs(last.timeOffset - 0.01) < 1e-6)
    }

    @Test func dumpRoundTripsThroughJSON() throws {
        let dump = StrokeDump(drawing: PKDrawing())
        let data = try JSONEncoder().encode(dump)
        #expect(try JSONDecoder().decode(StrokeDump.self, from: data) == dump)
    }
}
