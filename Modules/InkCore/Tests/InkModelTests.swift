import Foundation
import Testing

@testable import InkCore

struct InkModelTests {
    let sample = StrokeSample(x: 10, y: 20, force: 1.2, altitude: 0.9, azimuth: 1.1, timestamp: 100)

    @Test func strokeRoundTripsThroughJSON() throws {
        let stroke = Stroke(tool: .defaultPen, samples: [sample, sample])
        let data = try JSONEncoder().encode(stroke)
        let decoded = try JSONDecoder().decode(Stroke.self, from: data)
        #expect(decoded == stroke)
    }

    @Test func opsRoundTripThroughJSON() throws {
        let ops: [InkOp] = [.addStroke(Stroke(tool: .defaultPen, samples: [sample])), .removeStroke(UUID()), .clear]
        let data = try JSONEncoder().encode(ops)
        #expect(try JSONDecoder().decode([InkOp].self, from: data) == ops)
    }

    @Test func defaultPenIsOpaqueBlack() {
        #expect(InkTool.defaultPen.kind == .pen)
        #expect(InkTool.defaultPen.color == .black)
        #expect(InkTool.defaultPen.width > 0)
    }

    @Test func fountainPenToolRoundTripsThroughCodable() throws {
        let data = try JSONEncoder().encode(InkTool.fountainPen)
        let decoded = try JSONDecoder().decode(InkTool.self, from: data)
        #expect(decoded == .fountainPen)
        #expect(decoded.kind == .fountainPen)
    }
}
