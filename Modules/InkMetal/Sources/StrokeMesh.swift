import CoreGraphics

/// Must match `SegmentIn` in InkRenderer's shader: 8 packed floats = 32 bytes.
public struct SegmentVertex: Sendable, Equatable {
    /// Quad corner, points.
    public var x: Float
    public var y: Float
    /// Segment start and end; the fragment shader measures distance to the capsule between them.
    public var ax: Float
    public var ay: Float
    public var bx: Float
    public var by: Float
    /// Radii at the start and end (width / 2).
    public var ra: Float
    public var rb: Float
}

/// Path → one quad per segment. The shader turns each quad into an antialiased "uneven capsule",
/// so joins and caps are round and sharp turns never leave gaps.
public enum StrokeMesh {
    /// Six vertices (two triangles) per segment; a lone point becomes a zero-length segment (a disc).
    /// `margin` (points) pads every quad for the antialiasing ramp.
    public static func vertices(for path: [PathPoint], margin: Float) -> [SegmentVertex] {
        if path.count == 1 { return quad(path[0], path[0], margin: margin) }
        var vertices: [SegmentVertex] = []
        vertices.reserveCapacity(path.count * 6)
        for (a, b) in zip(path, path.dropFirst()) where a.x != b.x || a.y != b.y {
            vertices += quad(a, b, margin: margin)
        }
        return vertices
    }

    public static func bounds(of path: [PathPoint], margin: Double) -> CGRect {
        guard !path.isEmpty else { return .null }
        let minX = path.map { $0.x - $0.width / 2 }.min()! - margin
        let maxX = path.map { $0.x + $0.width / 2 }.max()! + margin
        let minY = path.map { $0.y - $0.width / 2 }.min()! - margin
        let maxY = path.map { $0.y + $0.width / 2 }.max()! + margin
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    private static func quad(_ a: PathPoint, _ b: PathPoint, margin: Float) -> [SegmentVertex] {
        let ax = Float(a.x)
        let ay = Float(a.y)
        let bx = Float(b.x)
        let by = Float(b.y)
        let ra = Float(a.width / 2)
        let rb = Float(b.width / 2)
        let minX = min(ax - ra, bx - rb) - margin
        let maxX = max(ax + ra, bx + rb) + margin
        let minY = min(ay - ra, by - rb) - margin
        let maxY = max(ay + ra, by + rb) + margin
        let corners = [(minX, minY), (maxX, minY), (minX, maxY), (maxX, minY), (maxX, maxY), (minX, maxY)]
        return corners.map { SegmentVertex(x: $0.0, y: $0.1, ax: ax, ay: ay, bx: bx, by: by, ra: ra, rb: rb) }
    }
}
