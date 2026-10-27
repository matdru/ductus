import PencilKit

/// Where ink changed between two drawings, so undo and redo can show what they changed.
enum DrawingChange {
    /// The bounds (canvas units) of strokes in one drawing but not the other, or `nil` if they hold the same ink.
    /// Strokes are matched by creation date and bounds, so a moved stroke counts at both its old and new place.
    static func bounds(from before: PKDrawing, to after: PKDrawing) -> CGRect? {
        var counts: [Key: Int] = [:]
        var rects: [Key: CGRect] = [:]
        for stroke in before.strokes {
            let key = Key(stroke)
            counts[key, default: 0] += 1
            rects[key] = stroke.renderBounds
        }
        for stroke in after.strokes {
            let key = Key(stroke)
            counts[key, default: 0] -= 1
            rects[key] = stroke.renderBounds
        }
        return counts.filter { $0.value != 0 }.keys.compactMap { rects[$0] }.reduce(nil) { $0?.union($1) ?? $1 }
    }

    private struct Key: Hashable {
        let created: Date
        let x, y, width, height: Double

        init(_ stroke: PKStroke) {
            created = stroke.path.creationDate
            let bounds = stroke.renderBounds
            x = bounds.minX
            y = bounds.minY
            width = bounds.width
            height = bounds.height
        }
    }
}
