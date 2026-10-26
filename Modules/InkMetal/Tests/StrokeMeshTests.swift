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

    /// A tap gives touchesBegan + touchesEnded at one location: the dot must not vanish at pen-up.
    @Test func allCoincidentPointsBecomeDisc() {
        let vertices = StrokeMesh.vertices(for: [point(5, 5), point(5, 5), point(5, 5)], margin: 1)
        #expect(vertices.count == 6)
        #expect(vertices.allSatisfy { $0.ax == 5 && $0.bx == 5 && $0.ay == 5 && $0.by == 5 })
    }

    @Test func ovalNibStoresSegmentsInNibSpaceAndBoundsTheOval() {
        let nib = NibShape(angle: 0, roundness: 0.5)
        // nibScale 4: oval is 8 pt wide along x, 4 pt tall.
        let path = [PathPoint(x: 0, y: 10, width: 4, nibScale: 4)]
        let vertices = StrokeMesh.vertices(for: path, margin: 1, nib: nib)
        #expect(vertices.allSatisfy { $0.ax == 0 && $0.ay == 20 && $0.ra == 4 })
        #expect(vertices.map(\.x).min() == -5 && vertices.map(\.x).max() == 5)
        #expect(vertices.map(\.y).min() == 7 && vertices.map(\.y).max() == 13)
        #expect(StrokeMesh.bounds(of: path, margin: 1, nib: nib) == CGRect(x: -5, y: 7, width: 10, height: 6))
    }
}
