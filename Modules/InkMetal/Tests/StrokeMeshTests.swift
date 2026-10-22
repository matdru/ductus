import CoreGraphics
import Testing

@testable import InkMetal

struct StrokeMeshTests {
    func point(_ x: Double, _ y: Double, width: Double = 4) -> PathPoint { PathPoint(x: x, y: y, width: width) }

    @Test func vertexStrideMatchesShader() {
        #expect(MemoryLayout<SegmentVertex>.stride == 32)
    }

    @Test func quadCoversBothDiscsPlusMargin() {
        let vertices = StrokeMesh.vertices(for: [point(0, 0, width: 4), point(10, 0, width: 8)], margin: 1)
        #expect(vertices.count == 6)
        #expect(vertices.map(\.x).min() == -3 && vertices.map(\.x).max() == 15)
        #expect(vertices.map(\.y).min() == -5 && vertices.map(\.y).max() == 5)
        #expect(vertices.allSatisfy { $0.ax == 0 && $0.bx == 10 && $0.ra == 2 && $0.rb == 4 })
    }

    @Test func singlePointBecomesDisc() {
        let vertices = StrokeMesh.vertices(for: [point(5, 5)], margin: 1)
        #expect(vertices.count == 6)
        #expect(vertices.allSatisfy { $0.ax == $0.bx && $0.ay == $0.by })
    }

    @Test func coincidentPointsAreSkipped() {
        #expect(StrokeMesh.vertices(for: [point(0, 0), point(0, 0), point(10, 0)], margin: 1).count == 6)
    }

    @Test func emptyPathHasNoVertices() {
        #expect(StrokeMesh.vertices(for: [], margin: 1).isEmpty)
    }

    @Test func boundsUnionAllSegments() {
        let bounds = StrokeMesh.bounds(of: [point(0, 0, width: 2), point(10, 20, width: 6), point(-5, 3)], margin: 1)
        #expect(bounds == CGRect(x: -8, y: -2, width: 22, height: 26))
    }
}
