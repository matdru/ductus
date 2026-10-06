/// The thin interface every ink engine implements, so apps and the Feel Lab can swap engines.
@MainActor
public protocol InkSurface: AnyObject {
    /// Pencil-only when false (the default). Turn on in the simulator so the pointer can draw.
    var allowsFingerDrawing: Bool { get set }
    /// Removes all strokes. Not undoable.
    func clear()
    /// Removes the most recent stroke. No-op when empty.
    func undo()
    func setTool(_ tool: InkTool)
    /// Replaces the surface's contents with `strokes`.
    func load(_ strokes: [Stroke])
    func exportStrokes() -> [Stroke]
}
