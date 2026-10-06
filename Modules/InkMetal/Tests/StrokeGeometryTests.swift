import InkCore
import Testing

@testable import InkMetal

struct StrokeGeometryTests {
    let tool = InkTool(kind: .pen, color: InkColor(red: 1, green: 0.5, blue: 0, alpha: 1), width: 4)

    func sample(_ x: Double, _ y: Double, force: Double = 1) -> StrokeSample {
        StrokeSample(x: x, y: y, force: force, altitude: 1, azimuth: 0, timestamp: 0)
    }

    @Test func vertexLayoutMatchesMetalPackedStruct() {
        // packed_float2 + packed_float4 in the shader = 24 bytes.
        #expect(MemoryLayout<InkVertex>.stride == 24)
    }

    @Test func noSamplesProduceNoVertices() {
        #expect(StrokeGeometry.triangles(for: [], tool: tool).isEmpty)
    }

    @Test func singleSampleProducesCenteredDot() {
        let vertices = StrokeGeometry.triangles(for: [sample(10, 10)], tool: tool)
        #expect(vertices.count == 6)
        #expect(Set(vertices.map(\.x)) == [8, 12])
        #expect(Set(vertices.map(\.y)) == [8, 12])
    }

    @Test func horizontalSegmentIsExtrudedByHalfWidth() {
        let vertices = StrokeGeometry.triangles(for: [sample(0, 0), sample(10, 0)], tool: tool)
        #expect(vertices.count == 6)
        #expect(Set(vertices.map(\.x)) == [0, 10])
        #expect(Set(vertices.map(\.y)) == [-2, 2])
    }

    @Test func repeatedIdenticalSamplesFallBackToDot() {
        let vertices = StrokeGeometry.triangles(for: [sample(3, 3), sample(3, 3), sample(3, 3)], tool: tool)
        #expect(vertices.count == 6)
    }

    @Test func zeroLengthSegmentsAreSkipped() {
        let vertices = StrokeGeometry.triangles(
            for: [sample(0, 0), sample(0, 0), sample(10, 0)], tool: tool)
        #expect(vertices.count == 6)
    }

    @Test func zeroForceStillHasFullWidth() {
        let vertices = StrokeGeometry.triangles(for: [sample(0, 0, force: 0), sample(10, 0, force: 0)], tool: tool)
        #expect(Set(vertices.map(\.y)) == [-2, 2])
    }

    @Test func verticesCarryToolColor() throws {
        let vertex = try #require(StrokeGeometry.triangles(for: [sample(0, 0)], tool: tool).first)
        #expect(vertex.r == 1 && vertex.g == 0.5 && vertex.b == 0 && vertex.a == 1)
    }
}
