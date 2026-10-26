import CoreGraphics

/// Must match `SegmentIn` in InkRenderer's shader: 8 packed floats = 32 bytes.
public struct SegmentVertex: Sendable, Equatable {
    /// Quad corner, points.
    public var x: Float
    public var y: Float
    /// Segment start and end in nib space; the fragment shader measures distance to the capsule between them.
    public var ax: Float
    public var ay: Float
    public var bx: Float
    public var by: Float
    /// Radii at the start and end, in nib space (the nib scale).
    public var ra: Float
    public var rb: Float
}

/// Path → one quad per segment. Segment ends and radii are stored in the nib's space, where the shader turns
/// each quad into an antialiased "uneven capsule"; on screen that is the nib oval swept along the segment.
public enum StrokeMesh {
    /// Six vertices (two triangles) per segment; a path that never moves becomes a zero-length segment (a disc).
    /// `margin` (points) pads every quad for the antialiasing ramp.
    public static func vertices(for path: [PathPoint], margin: Float, nib: NibShape = .circle) -> [SegmentVertex] {
        guard let last = path.last else { return [] }
        var vertices: [SegmentVertex] = []
        vertices.reserveCapacity(path.count * 6)
        for (a, b) in zip(path, path.dropFirst()) where a.x != b.x || a.y != b.y {
            vertices += quad(a, b, margin: Double(margin), nib: nib)
        }
        // A tap (all points coincident) is still a dot.
        return vertices.isEmpty ? quad(last, last, margin: Double(margin), nib: nib) : vertices
    }

    public static func bounds(of path: [PathPoint], margin: Double, nib: NibShape = .circle) -> CGRect {
        path.map { box(around: $0, margin: margin, nib: nib) }.reduce(CGRect.null) { $0.union($1) }
    }

    private static func box(around point: PathPoint, margin: Double, nib: NibShape) -> CGRect {
        let extents = nib.extents(scale: point.nibScale)
        return CGRect(
            x: point.x - extents.x - margin, y: point.y - extents.y - margin, width: 2 * (extents.x + margin),
            height: 2 * (extents.y + margin))
    }

    private static func quad(_ a: PathPoint, _ b: PathPoint, margin: Double, nib: NibShape) -> [SegmentVertex] {
        let box = box(around: a, margin: margin, nib: nib).union(box(around: b, margin: margin, nib: nib))
        let start = nib.toNibSpace(x: a.x, y: a.y)
        let end = nib.toNibSpace(x: b.x, y: b.y)
        let corners = [
            (box.minX, box.minY), (box.maxX, box.minY), (box.minX, box.maxY),
            (box.maxX, box.minY), (box.maxX, box.maxY), (box.minX, box.maxY),
        ]
        return corners.map {
            SegmentVertex(
                x: Float($0.0), y: Float($0.1), ax: Float(start.x), ay: Float(start.y), bx: Float(end.x),
                by: Float(end.y), ra: Float(a.nibScale), rb: Float(b.nibScale))
        }
    }
}
