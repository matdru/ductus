/// In-memory op log with the strokes it produces. The log is the source of truth;
/// `strokes` is derived from it.
public struct InkDocument: Sendable, Equatable {
    public private(set) var ops: [InkOp] = []
    public private(set) var strokes: [Stroke] = []

    public init() {}

    public mutating func apply(_ op: InkOp) {
        ops.append(op)
        strokes = Self.applying(op, to: strokes)
    }

    /// Removes the most recent op and rebuilds `strokes`. No-op when the log is empty.
    public mutating func undo() {
        guard !ops.isEmpty else { return }
        ops.removeLast()
        strokes = ops.reduce(into: []) { result, op in result = Self.applying(op, to: result) }
    }

    private static func applying(_ op: InkOp, to strokes: [Stroke]) -> [Stroke] {
        switch op {
        case .addStroke(let stroke): strokes + [stroke]
        case .removeStroke(let id): strokes.filter { $0.id != id }
        case .clear: []
        }
    }
}
