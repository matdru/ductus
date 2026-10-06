import InkCore

/// Must match `VertexIn` in InkRenderer's shader (packed_float2 + packed_float4 = 24 bytes).
public struct InkVertex: Sendable, Equatable {
    public var x: Float
    public var y: Float
    public var r: Float
    public var g: Float
    public var b: Float
    public var a: Float
}

/// Baseline tessellation: one constant-width quad per segment, a square dot for taps.
/// Pressure, tilt, joins and caps are Phase 0 tuning work.
public enum StrokeGeometry {
    public static func triangles(for samples: [StrokeSample], tool: InkTool) -> [InkVertex] {
        guard let first = samples.first else { return [] }
        let halfWidth = tool.width / 2
        var vertices: [InkVertex] = []
        for (p0, p1) in zip(samples, samples.dropFirst()) {
            let dx = p1.x - p0.x
            let dy = p1.y - p0.y
            let length = (dx * dx + dy * dy).squareRoot()
            guard length > 0 else { continue }
            let nx = -dy / length * halfWidth
            let ny = dx / length * halfWidth
            appendQuad(
                [(p0.x + nx, p0.y + ny), (p0.x - nx, p0.y - ny), (p1.x + nx, p1.y + ny), (p1.x - nx, p1.y - ny)],
                color: tool.color, to: &vertices)
        }
        if vertices.isEmpty {
            appendQuad(
                [
                    (first.x - halfWidth, first.y - halfWidth), (first.x - halfWidth, first.y + halfWidth),
                    (first.x + halfWidth, first.y - halfWidth), (first.x + halfWidth, first.y + halfWidth),
                ],
                color: tool.color, to: &vertices)
        }
        return vertices
    }

    /// Corners [a, b, c, d], where a-b is the start edge and c-d the end edge.
    /// Emits two triangles: (a, b, c) and (b, d, c).
    private static func appendQuad(_ corners: [(Double, Double)], color: InkColor, to vertices: inout [InkVertex]) {
        for index in [0, 1, 2, 1, 3, 2] {
            let point = corners[index]
            vertices.append(
                InkVertex(
                    x: Float(point.0), y: Float(point.1),
                    r: Float(color.red), g: Float(color.green), b: Float(color.blue), a: Float(color.alpha)))
        }
    }
}
